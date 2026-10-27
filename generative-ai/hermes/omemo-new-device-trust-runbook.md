# Hermes XMPP: Verifying and Trusting a New OMEMO Device

Companion: [OMEMO fingerprints and trust guide](omemo-fingerprints-and-trust-guide.md).
All JIDs below are examples; replace `alice@example.org` with the contact's
actual bare JID (without a resource).

## Scope and Security Preconditions

This procedure changes trust for a contact's device. It does not register a new
Hermes identity or add a contact to the gateway's user allow-list.

**The plugin revision documented in this repository is not manual-trust-only.**
At revision `d01087a7ab4f26d6624622582dc83b2124ba400d`, `_btbv_enabled` returns
`True`: Blind Trust Before Verification (BTBV) is enabled. The manual-trust hook
marks identities requiring a decision as `DISTRUSTED`, but that does not disable
automatic blind trust for other identities.

That upstream revision also accepts ordinary non-OMEMO inbound messages and
has outbound plaintext fallbacks when encryption fails or produces no result.
It does not implement `XMPP_REQUIRE_OMEMO_INBOUND` or a `REFUSING plaintext`
guard. TLS protects transport to the server, not message content from the server.

If your policy requires verification **before any communication with a new
device**, first ensure that the installed adapter disables BTBV and enforces
your inbound/outbound OMEMO policy. Such local modifications are not represented
by the deployment files here. Do not send sensitive test content on the
assumption that upstream enforces this policy.

The remaining procedure assumes the installed dependencies use the flat store
layout described in the companion guide, including URL-safe Base64 Ed25519
identity keys and textual trust grades. Verify that assumption against the
installed versions. Use `TRUSTED` for explicit trust; do not use
`BLINDLY_TRUSTED` as a substitute for fingerprint verification.

## Execution Environment

Run the Docker commands **on the host**, from the directory containing this
stack's `compose.yaml`. The service name is `hermes`.

- Default store inside the container: `/opt/data/xmpp_omemo.json`.
- Installed adapter: `/opt/data/plugins/hermes-xmpp-plugin/adapter.py`.
- Gateway log: `/opt/data/logs/gateway.log`.
- The store lives in the persistent volume. Confirm the actual storage path if
  `XMPP_OMEMO_STORAGE_PATH` or adapter configuration overrides the default.
- Stop all other processes or containers that write this same store, including
  one-shot senders. Stopping the gateway alone does not stop external writers.

## 1. Discover the Device Identity

Have the contact send a non-sensitive test message from the new device. The
adapter may discover and record its identity during OMEMO processing. With a
verified manual-trust configuration, the message may be refused until trust is
granted; with upstream BTBV it may already be accepted.

Do not assume that a refused message necessarily created a store entry. Inspect
the store and logs. If the identity is missing, investigate device publication,
the allow-list, and OMEMO initialization instead of inventing a trust entry.

Legacy Axolotl bundles publish X25519 identity keys. The conversion from an
Ed25519 public key loses a sign bit, so the original Ed25519 encoding cannot be
uniquely recovered from that X25519 value alone. This is not a claim that a
private key is required to construct possible Edwards counterparts. Use the
identity encoding actually recorded by the adapter.

## 2. Stop Writers and List Candidates

The documented upstream adapter keeps the store in memory and rewrites the
JSON file non-atomically on each storage update, not necessarily once per
message. A live edit can be overwritten, and a concurrent read can encounter
incomplete JSON. Stop the container before inspecting or modifying the store:

```bash
docker compose stop hermes
docker compose ps --all hermes
```

Confirm that the container is stopped and that no other writer uses its store.
Then use a temporary maintenance container with the same persistent volume:

```bash
docker compose run --rm --no-deps -T --user 10000 --entrypoint python3 hermes - <<'PY'
import base64
import json

JID = "alice@example.org"
P = 2**255 - 19


def fingerprint(key):
    ed = base64.b64decode(key + "=" * (-len(key) % 4),
                         altchars=b"-_", validate=True)
    if len(ed) != 32:
        raise ValueError("Expected a 32-byte Ed25519 public key")
    y = int.from_bytes(ed, "little") & ((1 << 255) - 1)
    if y >= P or y == 1:
        raise ValueError("Non-canonical or non-convertible Ed25519 key")
    u = (1 + y) * pow(1 - y, P - 2, P) % P
    value = u.to_bytes(32, "little").hex().upper()
    return " ".join(value[i:i + 8] for i in range(0, 64, 8))


with open("/opt/data/xmpp_omemo.json", encoding="utf-8") as file:
    store = json.load(file)

prefix = f"/devices/{JID}/"
for path, key in sorted(store.items()):
    if path.startswith(prefix) and path.endswith("/identity_key"):
        device_id = path[len(prefix):-len("/identity_key")]
        trust = store.get(f"/trust/{JID}/{key}", "MISSING")
        print(device_id, trust, key, fingerprint(key))
PY
```

As in the companion guide, the formula assumes valid curve points from the
local store; it is not full validation of untrusted Ed25519 keys.

Compare with the currently published server device list using an independent
XMPP client. A local identity absent from the list is not automatically a
harmless "ghost": investigate stale publication, removal, replacement, or
compromise. Do not trust the server list as proof of device ownership.

## 3. Verify the Fingerprint

Ask the contact to read the new device's **own** fingerprint in its client.
Compare it through an independent authenticated channel, such as an in-person
comparison or a previously verified device. A fingerprint asserted only by the
unverified new device is not sufficient.

After ignoring presentation-only spaces and letter case, all 64 hexadecimal
characters must match the candidate's derived fingerprint. Also confirm the
intended JID and device ID. If anything differs, do not grant trust.

## 4. Back Up and Update the Existing Entry

Keep the main container stopped. Replace both example placeholders below with
the verified candidate's values. The script refuses missing device or trust
entries, backs up the complete store, and preserves file ownership and mode.
The maintenance user must match the store owner; UID 10000 is the documented
agent user. If the checks fail, investigate ownership rather than relaxing
permissions or blindly running the command as root.

```bash
docker compose run --rm --no-deps -T --user 10000 --entrypoint python3 hermes - <<'PY'
import json
import os
from pathlib import Path
import shutil
import stat
import tempfile

p = Path("/opt/data/xmpp_omemo.json")
JID = "alice@example.org"
KEY = "<verified_identity_key_b64>"
DEVICE_ID = "<verified_device_id>"
GRADE = "TRUSTED"

info = p.stat()
if info.st_uid != os.geteuid():
    raise RuntimeError("Run as the store owner")
with p.open(encoding="utf-8") as file:
    store = json.load(file)

path = f"/trust/{JID}/{KEY}"
device_path = f"/devices/{JID}/{DEVICE_ID}/identity_key"
if path not in store or store.get(device_path) != KEY:
    raise ValueError("Candidate does not match an existing device and trust entry")
if GRADE not in {"TRUSTED", "DISTRUSTED"}:
    raise ValueError("Unsupported grade for this procedure")

# mkstemp creates unique, private files in the same directory as the store.
fd, backup = tempfile.mkstemp(prefix=p.name + ".backup-", dir=p.parent)
os.close(fd)
shutil.copy2(p, backup)
print("Backup:", backup)

store[path] = GRADE
fd, temporary = tempfile.mkstemp(prefix=p.name + ".tmp-", dir=p.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as file:
        os.fchown(file.fileno(), info.st_uid, info.st_gid)
        os.fchmod(file.fileno(), stat.S_IMODE(info.st_mode))
        json.dump(store, file, indent=2)
        file.write("\n")
        file.flush()
        os.fsync(file.fileno())
    os.replace(temporary, p)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
print("Updated:", path, "->", GRADE)
PY
```

The replacement is atomic on the same filesystem, avoiding a partially written
JSON file. It is not a complete power-loss durability guarantee and does not
preserve custom ACLs or extended attributes. If your store uses those, use a
maintenance method that preserves them. Protect backups: they contain the
entire OMEMO store, including secret material. Retain them only as needed.

## 5. Restart and Verify Both Directions

Only after the update succeeds:

```bash
docker compose up -d hermes
docker compose exec hermes tail -n 100 -f /opt/data/logs/gateway.log
```

Have the contact send another non-sensitive OMEMO message from the new device,
then check the reply on that device. Verify that both messages were actually
OMEMO-encrypted and decrypted, not merely delivered via plaintext fallback.
Check new logs for trust/decryption failures and encryption fallbacks. Existing
historical warnings or warnings about other devices do not by themselves mean
that this update failed.

If a strict manual-trust policy is required, also test separately that an
unverified device and ordinary plaintext messages are handled according to
that policy. Absence of a log warning is not proof of encryption enforcement.

## Rollback and Lockout

To revoke this trust decision, stop all writers again and repeat step 4 with
`GRADE = "DISTRUSTED"`, then restart. Previously delivered or queued messages
cannot be recalled. Verify the installed adapter's behavior for subsequent
messages; revocation is not an instantaneous undo of earlier encryption.

For lockout, use authenticated host/container administration to repair the
verified trust entry. Do not rely on `XMPP_REQUIRE_OMEMO_INBOUND=0`: it is not
implemented by the documented upstream revision, and relaxing a plaintext
filter would not repair failed decryption of distrusted encrypted messages.

## Implementation Reference

[Documented plugin adapter revision](https://github.com/fastfinge/hermes-xmpp-plugin/blob/d01087a7ab4f26d6624622582dc83b2124ba400d/adapter.py).
The deployed persistent-volume plugin and dependency versions may differ.
This runbook was reviewed against repository configuration and upstream source;
it has not been executed against the live Hermes deployment.
