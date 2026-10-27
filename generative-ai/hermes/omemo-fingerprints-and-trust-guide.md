# XMPP OMEMO: Computing X25519 Fingerprints from a Trust Store

## Scope

Gajim displays legacy OMEMO device fingerprints as 64 uppercase hexadecimal
characters in groups of eight. These are the public-key bytes, not a hash.

This guide covers the legacy `eu.siacs.conversations.axolotl` format. Do not
assume that its serialization or conversion rules apply to every OMEMO version
or client.

For a trust store that represents the corresponding device identity as a
URL-safe Base64 **Ed25519 public key**, the **X25519 public key** can be computed
locally. The store layout below is adapter-specific, not an OMEMO standard.
Check your adapter's implementation before applying this procedure. If the
store already contains X25519 keys, do not apply the Ed25519 conversion.

The conversion loses the sign of the Edwards x-coordinate. It is therefore
**not uniquely reversible from the X25519 public key alone**. Nor do arbitrary,
independently generated Ed25519 and X25519 keys describe the same identity.

## The Mathematics

For a valid, suitable Ed25519 public key (32 bytes, little-endian, with the
highest bit encoding the sign of x):

```text
y = int(pk, little_endian) with the sign bit cleared
u = (1 + y) / (1 - y) mod p, where p = 2^255 - 19
fingerprint = uppercase hex of u encoded as 32 little-endian bytes
```

Division means multiplication by the modular inverse:
`1/z = z^(p-2) mod p`, for nonzero `z`.

Legacy Signal serialization prefixes the X25519 key with a key-type byte:
`0x05 || u`. Gajim's fingerprint extraction removes that prefix. This does not
mean that all OMEMO clients internally start with an Ed25519 key.

## Reading an Adapter Store

The following example assumes a flat JSON key-value store with these paths:

```text
/trust/<jid>/<identity_key_b64>          -> "TRUSTED" | "DISTRUSTED" | "UNDECIDED"
/devices/<jid>/<device_id>/identity_key  -> URL-safe Base64 Ed25519 public key
/own_device_id                           -> local device ID
```

```python
#!/usr/bin/env python3
import base64
import json

P = 2**255 - 19


def fingerprint(pub_b64: str) -> str:
    padded = pub_b64 + "=" * (-len(pub_b64) % 4)
    ed = base64.b64decode(padded, altchars=b"-_", validate=True)
    if len(ed) != 32:
        raise ValueError("Expected a 32-byte Ed25519 public key")
    y = int.from_bytes(ed, "little") & ((1 << 255) - 1)
    if y >= P or y == 1:
        raise ValueError("Non-canonical or non-convertible Ed25519 key")
    u = (1 + y) * pow(1 - y, P - 2, P) % P
    h = u.to_bytes(32, "little").hex().upper()
    return " ".join(h[i:i + 8] for i in range(0, 64, 8))


with open("/opt/data/xmpp_omemo.json", encoding="utf-8") as file:
    store = json.load(file)

for key, value in sorted(store.items()):
    if key.startswith("/devices/") and key.endswith("/identity_key"):
        _, _, jid, device_id, _ = key.split("/")
        trust = store.get(f"/trust/{jid}/{value}", "UNKNOWN")
        print(f"{jid:28} dev {device_id:>10}  {trust:10}  {fingerprint(value)}")
```

This script assumes valid Ed25519 curve points from a trusted local store. The
length and encoding checks are **not full curve-point or subgroup validation**.
For untrusted keys, use a vetted conversion API such as libsodium's
`crypto_sign_ed25519_pk_to_curve25519` rather than this formula-only script.
Computing a fingerprint does not verify or grant trust to a key.

For a reproducible example, the public Ed25519 base point is encoded as:

```text
WGZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmY
```

It maps to the X25519 base point, `u = 9`. An illustrative output line is:

```text
alice@example.org            dev       1001  UNDECIDED   09000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
```

These are public mathematical test values, not a real device identity. Never
use them as operational identity keys or mark a device trusted based on them.

## Comparing with Published Server Bundles

To check what the server currently publishes for an example device, request
its legacy OMEMO PEP node:

```xml
<iq type='get' to='alice@example.org' id='example-check'>
  <pubsub xmlns='http://jabber.org/protocol/pubsub'>
    <items node='eu.siacs.conversations.axolotl.bundles:1001'/>
  </pubsub>
</iq>
```

The bundle's `<identityKey>` uses standard Base64. In this legacy format,
decoding yields 33 bytes: `0x05 || u`. Check both length and prefix, then compare
`decoded[1:].hex().upper()` with the ungrouped computed fingerprint.

Use Gajim's XML console or another XMPP client with raw XML access. The console's
menu location can vary by Gajim version.

**Server bundles are publication state, not authenticated ground truth.** A
compromised server or account can advertise an attacker's device. Verify device
fingerprints through an independent authenticated channel, such as an in-person
comparison or an already authenticated conversation.

## Reading Gajim's SQLite Store

Current Gajim source constructs the database path as
`MY_DATA / f"omemo_{own_jid}.db"`. The usual Linux default is:

```text
~/.local/share/gajim/omemo_<your-jid>.db
```

XDG configuration, profiles, custom paths, and sandbox packaging may change it.
Relevant columns in the current schema include:

```text
identities: recipient_id, registration_id, public_key, timestamp, trust
secret:     device_id, public_key, private_key
```

This is a column overview, not the full schema. In particular,
**`identities.registration_id` is not a reliable device ID**: current Gajim does
not populate it when saving an identity. Gajim associates devices using session
data and the remote identity key. Do not label that column as a device ID in a
SQL export.

The `secret` table stores this local Gajim instance's identity, not all devices
belonging to the account. Do not export its private key.

For the current serialization, `public_key` is 33 bytes: `0x05` followed by the
32-byte X25519 key. SQLite indexes bytes from 1, so `substr(public_key, 2)`
removes the prefix:

```bash
DB="$HOME/.local/share/gajim/omemo_alice@example.org.db"

# Peer identities: JID, internal trust value, fingerprint in eight-character groups.
sqlite3 "file:$DB?mode=ro" \
  "SELECT recipient_id, trust,
          printf('%s %s %s %s %s %s %s %s',
                 hex(substr(public_key, 2, 4)), hex(substr(public_key, 6, 4)),
                 hex(substr(public_key, 10, 4)), hex(substr(public_key, 14, 4)),
                 hex(substr(public_key, 18, 4)), hex(substr(public_key, 22, 4)),
                 hex(substr(public_key, 26, 4)), hex(substr(public_key, 30, 4)))
   FROM identities
   WHERE length(public_key) = 33 AND hex(substr(public_key, 1, 1)) = '05';"

# This local instance: device ID and fingerprint in eight-character groups.
sqlite3 "file:$DB?mode=ro" \
  "SELECT device_id,
          printf('%s %s %s %s %s %s %s %s',
                 hex(substr(public_key, 2, 4)), hex(substr(public_key, 6, 4)),
                 hex(substr(public_key, 10, 4)), hex(substr(public_key, 14, 4)),
                 hex(substr(public_key, 18, 4)), hex(substr(public_key, 22, 4)),
                 hex(substr(public_key, 26, 4)), hex(substr(public_key, 30, 4)))
   FROM secret
   WHERE length(public_key) = 33 AND hex(substr(public_key, 1, 1)) = '05';"
```

Notes:

- `mode=ro` prevents database writes. Reading a live WAL database normally works,
  but requires suitable permissions and access to its WAL/shared-memory files.
- SQLite's `hex()` already returns uppercase. Each four-byte slice produces an
  eight-character block; `printf()` joins the blocks without changing other fields.
- `trust` uses the OMEMO backend enum described below, not the adapter's textual
  trust value or Gajim's generic UI enum.
- A local/server mismatch may indicate a removed device, stale publication, an
  identity replacement, or compromise. Investigate rather than assuming a harmless
  stale device.
- Inspect the actual schema and key lengths before adapting these queries to
  another client version. A 32-byte value is not by itself proof that it is an
  unprefixed X25519 key.

## Gajim Database Trust Values

For the `identities.trust` column queried above, all currently defined values of
the backend's `OMEMOTrust` enum are:

| Value | Backend Name | UI Label    | Meaning                              |
|-------|--------------|-------------|--------------------------------------|
| `0`   | `UNTRUSTED`  | Untrusted   | Explicitly not trusted.              |
| `1`   | `VERIFIED`   | Verified    | Marked as independently verified.    |
| `2`   | `UNDECIDED`  | Not Decided | No trust decision yet.               |
| `3`   | `BLIND`      | Blind Trust | Trusted without verification.        |

Thus, in this SQL output, **`1` means Verified and `3` means Blind Trust**.
Both count as trusted for encryption. Untrusted identities are excluded from
trusted recipient keys; active undecided identities block sending until a
decision is made. Blind Trust can be assigned automatically
by Gajim's blind-trust policy or selected manually. Verified can also be set
manually: the stored flag does not prove that someone actually checked the
fingerprint through an independent authenticated channel.

Do not confuse these database values with Gajim's generic UI `Trust` enum,
which uses a different numeric order: `UNTRUSTED = 0`, `UNDECIDED = 1`,
`BLIND = 2`, and `VERIFIED = 3`. Gajim converts between the enums by **name**,
not by integer value. Values outside `0` through `3` are not defined in the
checked backend enum; investigate the installed version rather than guessing.

The mapping was checked against the upstream
[OMEMO backend enum](https://gitlab.com/api/v4/projects/86419156/repository/files/src%2Fomemo_dr%2Fconst.py/raw?ref=0af1b8b6cb2653a044d9b5ed3794343291290361),
[Gajim database implementation](https://gitlab.com/api/v4/projects/86419190/repository/files/src%2Fgajim%2Fcommon%2Fstorage%2Fomemo.py/raw?ref=8c1cead7ffe9927cf82c9f04b790a286849c6111),
and [UI trust labels](https://gitlab.com/api/v4/projects/86419190/repository/files/src%2Fgajim%2Fgtk%2Fcrypto_trust_manager.py/raw?ref=8c1cead7ffe9927cf82c9f04b790a286849c6111).

## Common Pitfalls

1. **Base64 alphabet:** Use the correct decoder. A permissive standard-Base64
   decoder may discard URL-safe characters; a strict one rejects them. Handle
   omitted padding explicitly.
2. **Flat paths versus nested objects:** In the assumed adapter format, each
   path is a top-level JSON key. There is no `store["devices"]` object.
3. **Byte order:** Encode `u` as 32 **little-endian** bytes before hex encoding.
4. **Trust versus representation:** Matching fingerprints confirms matching
   public keys, not who owns them or whether they should be trusted.

## Sources

- [Legacy OMEMO specification, XEP-0384 v0.3.0](https://xmpp.org/extensions/attic/xep-0384-0.3.0.html)
- [RFC 7748: Curve25519 and Edwards/Montgomery maps](https://www.rfc-editor.org/rfc/rfc7748.html#section-4.1)
- [libsodium: Ed25519 to Curve25519 conversion](https://libsodium.gitbook.io/doc/advanced/ed25519-curve25519)
- [Gajim OMEMO integration and database path](https://dev.gajim.org/gajim/gajim/-/blob/master/gajim/common/modules/omemo.py)
- [Gajim OMEMO database schema and storage](https://dev.gajim.org/gajim/gajim/-/blob/master/gajim/common/storage/omemo.py)
- [Gajim's identity-key fingerprint extraction](https://dev.gajim.org/gajim/omemo-dr/-/blob/master/src/omemo_dr/identitykey.py)
- [SQLite core functions](https://www.sqlite.org/lang_corefunc.html#hex)

Gajim implementation details were checked against current upstream source, not
every released version. The adapter-specific store layout and compatibility
with an installed client have not been independently verified here.
