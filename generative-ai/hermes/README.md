# Hermes stack — LLM (gufo) + WebUI + agent-side STT + XMPP (OMEMO)

A self-hosted, local-first setup that runs the **Hermes agent** with a **local
`gufo` LLM**, a **ChatGPT-style Web UI**, **offline speech-to-text (STT)**, and an
**XMPP/Jabber bot** — all pinned by version and fully local (no cloud TTS/STT).

This README is a **fresh-install guide**: it assumes Docker + `docker compose` are
already installed on a brand-new machine. It documents every deliberate, manual
adaptation made during bring-up so the stack can be reproduced (and understood).

---

## 1. Architecture

Three pinned containers (compose project name `hermes`, ports are loopback-only):

| Service | Image (pinned by version) | Purpose | Loopback ports |
|---|---|---|---|
| `hermes` | `nousresearch/hermes-agent:v0.22.5` | Gateway: agent runtime, dashboard, OpenAI-compatible `api_server` | `9119` dashboard, `8642` gateway API |
| `hermes-webui` | `ghcr.io/nesquena/hermes-webui:0.52.492` | Community ChatGPT-like Web UI (gateway-backend mode) | `8787` browser chat |
| `speaches` | `ghcr.io/speaches-ai/speaches:0.8.3-cpu` | OpenAI-compatible `/v1/audio/transcriptions` (faster-whisper) STT sidecar | `8000` STT API |

Data lives in a named volume **`hermes_hermes-data`** (mounted at `/opt/data` in the
agent — holds `config.yaml`, `.env`, plugins, OMEMO store, sessions, logs). Whisper
models stay on the host at **`/srv/llama/models/whisper`** and are mounted **read-only**
into Speaches.

```
Browser ──► hermes-webui:8787 ──(gateway runs API)──► hermes:8642 ──LLM──► gufo (host :8080)
XMPP peer ─► jabbers.one ─► hermes (xmpp plugin, OMEMO) ──LLM──► gufo
Voice note ─► hermes-agent ──(stt.provider=openai)──► speaches:8000 ──► faster-whisper
```

### Key design decisions (why it looks like this)
- **gufo is LLM/vision only** — it cannot "hear". STT therefore runs **inside
  hermes-agent** as an OpenAI-API client to the **Speaches** sidecar (agent → Speaches),
  *not* in the WebUI.
- **WebUI runs in gateway-backend mode** (`HERMES_WEBUI_CHAT_BACKEND=gateway`): chat,
  tools, vision, memory all execute on the agent. The WebUI does **not** mount the agent
  source (editable-installing the agent into the WebUI venv hits an unsolvable Pillow pin).
- **STT = Speaches**, chosen because it exposes a true OpenAI `/v1/audio/transcriptions`;
  whisper.cpp only exposes `/inference`, and Hermes' `api_server` rejects audio content
  parts. Speaches runs **offline** from a pre-placed, read-only model cache.
- **XMPP** via the community plugin
  [`fastfinge/hermes-xmpp-plugin`](https://github.com/fastfinge/hermes-xmpp-plugin),
  installed through Hermes' own plugin machinery and **pinned to a commit**.

---

## 2. Prerequisites

1. Docker + `docker compose` (already present in this scenario).
2. A running **gufo** server on the host: OpenAI-compatible API at
   `http://host.docker.internal:8080/v1` with a vision-capable model. Its exact model
   id matters (used as `model.default`). In our setup it is **`Qwen3.8 Flash Next`**.
3. An **XMPP account** for the bot (ours is on jabbers.one, which enforces STARTTLS)
   and your own peer JID for the allow-list. Both go in `.env` (see below) — the JIDs
   aren't credentials, but they're personal, so nothing identity-related is tracked.
4. Disk for the whisper model(s) under `/srv/llama/models/whisper`.

---

## 3. Whisper model cache (Speaches needs the HF-hub layout)

Speaches resolves models **only** from a Hugging Face **hub cache**
(`models--Systran--<model>/snapshots/<hash>/…`, including the model card). A flat folder
of weights is rejected, and at runtime the container is **offline**
(`HF_HUB_OFFLINE=1`), so the cache must be pre-populated once (online).

```bash
# The compose mounts /srv/llama/models/whisper -> /srv-cache:ro and sets
# HF_HUB_CACHE=/srv-cache/hub, so download into the .../whisper/hub subfolder:
sudo mkdir -p /srv/llama/models/whisper/hub
docker run --rm -v /srv/llama/models/whisper/hub:/cache python:3.11-slim sh -c '
  pip install --quiet huggingface_hub &&
  huggingface-cli download Systran/faster-whisper-small --cache-dir /cache'
```

Result: `/srv/llama/models/whisper/hub/models--Systran--faster-whisper-small/…`.

> Model choice: `small` is the default (multilingual, incl. German, ~460 MB). `base`
> is optional. See **For later** for a GPU (ROCm/Vulkan) STT engine.

---

## 4. Secrets & config — `.env`

Create **`.env`** in this directory (it is **git-ignored** — see `.gitignore`).
The stack reads secrets and personal JIDs from here; only non-personal `XMPP_*`
connection settings (host/port) live inline in `compose.yaml`.

```bash
# Shared key for the agent's OpenAI-compatible api_server (WebUI + any client).
API_SERVER_KEY=$(openssl rand -hex 16)

# XMPP bot password (referenced by compose as ${XMPP_PASSWORD:?}).
XMPP_PASSWORD=<the bot account password>

# XMPP identity + ACL (referenced by compose as ${XMPP_JID:?} etc.).
# JIDs are not credentials, but they're personal — keep them in .env, not compose.yaml.
XMPP_JID=<bot account, e.g. some-bot@jabbers.one>
XMPP_ALLOWED_USERS=<your own JID>
XMPP_HOME_CHANNEL=<your own JID>

# Optional (defaults shown in compose.yaml):
# DASHBOARD_USER=admin
# DASHBOARD_PASSWORD=admin
# HERMES_WEBUI_PASSWORD=
# GUFO_BASE_URL=http://host.docker.internal:8080/v1
# GUFO_API_KEY=dummy
```

> Put the **secrets** in `.env`. Do not put `XMPP_PASSWORD` anywhere tracked. Keep the
> values in `.env` consistent with what the agent already has; if the agent's home also
> holds `XMPP_*` lines, edit only one place (see Gotchas).

---

## 5. Bring the stack up

```bash
cd generative-ai/hermes
docker compose up -d
docker compose ps        # all three Up; speaches /health -> 200
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/health
```

On first start the agent creates its home + `config.yaml` in the volume.

---

## 6. Configure the agent (gufo model + STT) — the "manual" steps, automated

Use Hermes' own CLI (safe; it preserves the file's ownership, so the agent keeps
permission). Run inside the container. Values below are for **gufo** + **Speaches** with
**auto-detect** STT language.

```bash
H="/opt/hermes/.venv/bin/hermes"
X() { docker compose exec -i hermes "$H" config set "$@"; }

# --- gufo as the LLM/vision provider ---
X model.provider  custom
X model.base_url  "http://host.docker.internal:8080/v1"
X model.default   "Qwen3.8 Flash Next"        # must match gufo's model id

# --- STT: agent-side, OpenAI API -> Speaches sidecar ---
X stt.enabled       true
X stt.provider      openai
X stt.openai.base_url "http://speaches:8000/v1"
X stt.openai.api_key  "not-needed"            # MUST be non-empty — see "dummy api key" below
X stt.openai.model    "Systran/faster-whisper-small"
X stt.openai.language ""                       # auto-detect language; use "de" to force German

docker compose restart hermes
```

**"Fix dummy api key" explained:** Hermes' OpenAI-STT only auto-supplies a placeholder
key when `base_url` is a **private IP**. `speaches` is a **hostname**, so it falls back to
the global `OPENAI_API_KEY=dummy` + `OPENAI_BASE_URL` (= gufo) and fails with **401**.
Setting an explicit `stt.openai.api_key` (any non-empty value) makes Hermes use the
Speaches `base_url`. Speaches accepts any key.

> If a key is refused as unknown, add `--force` (writes under a known section).

Verify:

```bash
docker compose exec hermes "$H" config get stt.provider
docker compose exec hermes "$H" config get stt.openai.model
```

---

## 7. Web UI (`hermes-webui`)

Open **http://127.0.0.1:8787** (loopback; add `HERMES_WEBUI_PASSWORD` in `.env` if you
expose it). It uses the gateway backend, so chat/tools/vision run on the agent and the
gufo model shows up automatically.

Two settings to change in the Web UI (Settings):

- ✅ **Enable `Send raw audio instead of transcribing`** — sends voice notes raw to the
  agent, which transcribes via STT (Speaches). Without this, the WebUI shows "STT
  unavailable" because the WebUI does **no** transcription itself.
- ⬜ **Disable `Check for updates`** — the pinned image shouldn't chase upstream updates.

---

## 8. XMPP bot (OMEMO) — install + configure

Install the plugin through Hermes' plugin system, **pinned to a commit**, non-interactive.
The community-source scan flags the plugin's **README/docs** text (mentions of `pip`,
`sudo`, `.env`) — these are documentation strings, not runtime behavior — so `--force`
overrides that gate.

```bash
# Pin the plugin to an immutable commit (reproducibility):
docker compose exec hermes /opt/hermes/.venv/bin/hermes plugins install \
  fastfinge/hermes-xmpp-plugin \
  --ref d01087a7ab4f26d6624622582dc83b2124ba400d \
  --yes-deps --enable --force
```

> **Ownership gotcha (important):** `docker exec` runs as **root**, so `plugins install`
> creates **new** files under `/opt/data` (`installs/`, `plugins/`) owned by root. The
> agent runs as **uid 10000** and will **crash-loop** (`facts.json … Permission denied`).
> Fix it by restoring ownership after the install:
>
> ```bash
> docker run --rm -v hermes_hermes-data:/d alpine:3.20 chown -R 10000:10000 /d
> ```
>
> Rule of thumb: **editing** existing files in `/opt/data` via root is fine (owner is
> preserved); **creating** files via root needs a follow-up `chown`.

Connection settings come from `compose.yaml` (non-secret host/port) + `.env` (JIDs + password):

```yaml
# compose.yaml — hermes.service.environment (already set):
XMPP_JID: "${XMPP_JID:?...}"                       # from .env
XMPP_HOST: "jabbers.one"
XMPP_PORT: "5222"
XMPP_ALLOWED_USERS: "${XMPP_ALLOWED_USERS:?...}"   # from .env
XMPP_HOME_CHANNEL: "${XMPP_HOME_CHANNEL:?...}"     # from .env
XMPP_PASSWORD: "${XMPP_PASSWORD:?...}"             # from .env
```

Restart and verify:

```bash
docker compose restart hermes
docker compose exec hermes grep -aE "xmpp connected|Gateway running with" \
  /opt/data/logs/gateway.log | tail
# expect:  ✓ xmpp connected
```

### OMEMO (end-to-end encryption)
- OMEMO is **on by default**. The bot OMEMO-encrypts replies to any peer that has
  published device keys — so **keep OMEMO enabled in your client** for this chat, or
  replies won't be visible.
- Trust is **blind-trust-before-verify (BTBV)**: the bot blindly-trusts devices on first
  sighting. Multiple devices for your account each need to be blindly-trusted; they are,
  as long as they appear during the initial discovery.
- The OMEMO identity/sessions live in **`/opt/data/xmpp_omemo.json`**.
  **Do not delete/clear it** to "fix" a device problem — clearing it desyncs the bot from
  your clients (they stop sending key-exchange whispers → `failed to decrypt`). If you
  must touch it, **back it up first**:

  ```bash
  docker run --rm -v hermes_hermes-data:/d -v /tmp:/bk alpine:3.20 \
    sh -c 'cp /d/xmpp_omemo.json /bk/xmpp_omemo.json.bak.$(date +%Y%m%d-%H%M%S)'
  ```

---

## 9. Verification checklist

```bash
# Services + STT health
docker compose ps
curl -s http://127.0.0.1:8000/v1/models | head

# LLM/vision through the gateway api_server (text + image) -> gufo
docker compose exec hermes sh -lc 'KEY=$(grep ^API_SERVER_KEY= /opt/data/.env|cut -d= -f2-)
  curl -s -H "Authorization: Bearer $KEY" http://127.0.0.1:8642/v1/models'   # 200 + lists model

# STT end-to-end (agent -> Speaches): send a voice note via WebUI or XMPP;
# logs: gateway.log shows the transcription; speaches logs a 200.

# XMPP: send a DM from an allow-listed JID; check round-trip:
docker compose exec hermes grep -aE "inbound message: platform=xmpp|\[Xmpp\] Sending" \
  /opt/data/logs/gateway.log | tail
```

---

## 10. Operating notes

- **Logs are files, not `docker logs`** (s6 supervision):
  `/opt/data/logs/gateway.log`, `errors.log`, `agent.log`, …
- **`restart` vs `up -d`:** `docker compose restart` keeps the container filesystem
  (pip installs, plugins survive). A **recreate** (`docker compose up -d` after a config
  change) resets the image's `/opt/hermes/.venv`, but the **plugin code, its dependencies,
  the enabled flag, and the OMEMO store all live in the `hermes_hermes-data` volume** →
  the stack (incl. XMPP) reconnects after a recreate without reinstalling. Verified.
- **`docker exec` heredocs need `-i`** (`docker compose exec -i …`) or stdin isn't
  forwarded and the script silently no-ops.
- **The agent refuses to edit `config.yaml` via its own tools** (security); use
  `hermes config set …` or edit the file directly.

---

## 11. Gotchas (hard-won)

| Symptom | Cause | Fix |
|---|---|---|
| Agent crash-loops: `facts.json … Permission denied` | Root-side `docker exec` created files under `/opt/data` | `docker run --rm -v hermes_hermes-data:/d alpine:3.20 chown -R 10000:10000 /d` |
| STT 401 / hits gufo instead of Speaches | `stt.openai.base_url` is a hostname → Hermes falls back to global dummy key | Set `stt.openai.api_key` to any non-empty value |
| STT "unavailable" in WebUI | WebUI never transcribes; needs raw audio to the agent | Enable **Send raw audio instead of transcribing** |
| Speaches won't load model | Flat folder, or no model card, or offline with empty cache | Use HF **hub cache layout** under `…/whisper/hub` (pre-download, §3) |
| XMPP connects but replies invisible | OMEMO off in your client; or bot cleared its store | Keep OMEMO **on** in client; **don't clear** `xmpp_omemo.json` |
| `failed to decrypt … no session` | Bot/client desync (usually after clearing the store) | Restore a backup of `xmpp_omemo.json`; reset the conversation on the client |
| XMPP connect times out | IPv6 blackhole | Adapter auto-disables v6; ensure `XMPP_HOST`/`XMPP_PORT=5222` are set |
| No XMPP/agent runtime logs in `docker logs` | s6 writes to files | Read `/opt/data/logs/*.log` |

---

## 12. For later (TODO)

- **Best STT model/engine with ROCm / Vulkan support.** The current Speaches image uses
  `faster-whisper` (CTranslate2), which is **CPU/CUDA only** — no AMD ROCm or Vulkan.
  To use AMD/GPU-accelerated STT, evaluate: a **Speaches CUDA build** (NVIDIA only), or a
  **whisper.cpp** build with the **Vulkan** backend exposed behind an OpenAI-compatible
  shim. Keep the same agent config (`stt.provider=openai` → the sidecar's
  `/v1/audio/transcriptions`) so only the sidecar image changes.
- Optional: remove the unused `base` model to free ~140 MB if you standardize on `small`.
- Optional: mirror non-secret `XMPP_*` into `.env` too if you prefer all settings in one file.

See also [`TODO.md`](./TODO.md).

---

## 13. Reference

**Pinned versions**
- Agent: `nousresearch/hermes-agent:v0.22.5`
- Web UI: `ghcr.io/nesquena/hermes-webui:0.52.492`
- STT: `ghcr.io/speaches-ai/speaches:0.8.3-cpu`
- XMPP plugin: `fastfinge/hermes-xmpp-plugin` @ `d01087a7ab4f26d6624622582dc83b2124ba400d`

**Files**
- `compose.yaml` — three pinned services (+ non-secret `XMPP_*`)
- `.env` — `API_SERVER_KEY`, `XMPP_PASSWORD` (git-ignored)
- Volume `hermes_hermes-data` → `/opt/data` (config.yaml, .env, plugins, xmpp_omemo.json, logs)
- Host `/srv/llama/models/whisper/hub` → read-only whisper cache

**Useful commands**
```bash
docker compose ps
docker compose logs -f hermes                # s6 init only; runtime logs are files
docker compose exec hermes /opt/hermes/.venv/bin/hermes config show
docker compose exec hermes tail -n 50 /opt/data/logs/gateway.log
docker compose restart hermes                # keeps container fs
```
