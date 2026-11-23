# TTS gateway (OpenAI API) — proxy in front of the audio.cpp server

Standalone TTS stack replacing the `localai` service from
[`../../hermes/compose.yaml`](../../hermes/compose.yaml).
[`../compose.yaml`](../compose.yaml) defines the proxy service
**`gateway`** (container `tts-gateway-1`; productive since 2026-11-23):
`gateway.py` alone,
proxying to the **audio.cpp server** (`../compose.yaml` service `audio-cpp`,
compose-internal `audio-cpp:8080`, debug-published on
`127.0.0.1:8083`) — Qwen3-TTS 12Hz 1.7B Base, voice lucy, model id `qwen3-tts-12hz-1.7b-base`
(see [audio.cpp upstream mode](#audiocpp-upstream-mode-productive-since-2026-11-23)).

The gateway speaks the OpenAI `/v1/audio/speech` API and streams every
`response_format` (`mp3|opus|ogg|aac|flac|wav|pcm`) by transcoding the
backend's s16le/24 kHz PCM stream while generation runs.

The former production setup — the same image with the embedded
`pockettts.cpp` Vulkan backend (Pocket-TTS german 24l, April checkpoint,
Q8_0, ~5.5× realtime) — was removed from compose on 2026-11-23; its service
definition lives in this file's Git history. The sections below
(voice bootstrap, `PKTTS_*` configuration) document that backend.

```
Hermes/WebUI/curl ──> gateway :8081 (host) ──> audio.cpp server :8083 ──> Vulkan
                      OpenAI API + ffmpeg:        OpenAI API, streams
                      mp3/opus/aac/flac/wav/pcm,  s16le/24 kHz PCM while
                      streamed (chunked)          generating
```

`pockettts.cpp`'s `tts-server` (pinned to `fab7972`) speaks the OpenAI
endpoints but only WAV/PCM — in exchange, PCM streams during generation.
The build applies `onset-keep-first-frame.patch` (the not-yet-merged onset
fix from [pockettts.cpp#1](https://github.com/ServeurpersoCom/pockettts.cpp/pull/1)):
stock `fab7972` drops the first 80 ms frame of every chunk, which clips
word onsets — see the
[analysis](../Model%20Evaluation%20Details.md#fehlerbilder-im-produktivbetrieb-analyse-22112026).
The bundled Python gateway (`gateway.py`, stdlib only + ffmpeg) adds the
**mp3, opus, aac, flac** formats (ogg alias = real Opus, better than LocalAI's
"ogg" which delivered Vorbis) and encodes from the PCM stream — the client
receives bytes before the answer is complete.

All runtime voice state lives only in backend RAM. Registered voices are
intentionally lost on backend/container restart or crash: no persistence,
restore, rollback, filesystem cache or runtime state volume is used. The external,
read-only reference `sample.wav` is read at startup and cloned into RAM as
**`lucy`** by the separate `startup.py` bootstrap. The backend's native
`--voice lucy` (`PKTTS_SERVER_VOICE`) sets the default. The reference and model
bind mounts are inputs, not persisted runtime state, and remain unchanged.
Any old state volume is unused; existing host files and
volumes are not deleted or migrated.

## Startup & rebuild

Start: see [`../README.md#startup`](../README.md#startup) (compose stack).

After source changes (e.g. `gateway.py`): bump the image tag in
`../compose.yaml` (the tag pins the build, repo convention), then
`docker compose build gateway && docker compose up -d` from
`text-to-speech/` — both work through the `build:` + `image:` pair.

The service listens on host port `8081` (same port as LocalAI before; host
port 8080 is taken by gufo). It is published on **all interfaces** — like
gufo — because Docker port bindings only match the published address, so a
`127.0.0.1` bind would be unreachable for containers (their
`host.docker.internal` is the host's bridge IP). The API has no auth; that
is the same trade-off gufo accepts on a trusted LAN. A cleaner alternative
(shared Docker network, loopback-only again) is sketched in "Networking
upgrade" below. **Stop `localai` first**, otherwise the two fight over 8081
(see "Cutover").

## Test

```bash
# WAV (streaming RIFF, unknown length)
curl --fail-with-body http://localhost:8081/v1/audio/speech -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-tts-12hz-1.7b-base","input":"Hallo, sag mal etwas zu mir.","response_format":"wav"}' \
  --output test.wav

# Opus, streaming: measures time-to-first-byte and total time
curl -N --fail-with-body -o test.ogg -w 'TTFB: %{time_starttransfer}s  total: %{time_total}s\n' \
  http://localhost:8081/v1/audio/speech -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-tts-12hz-1.7b-base","input":"Es ist 13:05. Die Items werden mit Sprites gerendered. Tschüß.","response_format":"opus"}'

# Verify codec (expected: opus, mono)
ffprobe -v error -show_entries stream=codec_name,sample_rate,channels -of json test.ogg

# Voices: audio.cpp returns its configured presets (lucy + default)
curl -s http://localhost:8081/v1/audio/voices
```

Omitting `voice` is fine — the gateway injects `TTS_DEFAULT_VOICE` (`lucy`)
into the upstream request. Voice registration (`POST /v1/audio/voices`) is a
pass-through: the current audio.cpp backend has **no** registration endpoint
(voices live in its `server.json` presets or a `voice_dir` library), so it
answers 404/405 there. With the former pockettts.cpp backend, registration,
listing and deletion were proxied including response body and status; names
were case-insensitive in that backend. Audio conversion uses FFmpeg pipes
only, without temporary audio files.

Verified against the pinned [server CLI and adapter](https://github.com/ServeurpersoCom/pockettts.cpp/blob/fab7972/tools/tts-server.cpp):
`--voice` takes a registry name, not a WAV path. `find_voice` resolves that name
at synthesis time, checking runtime registrations before built-ins; startup does
not require the default to be loaded yet. There is no API to change the default.
The bootstrap waits for the backend, registers the reference once via its native
API, then execs the gateway. Registration failure prevents gateway startup and
lets supervision restart the stack rather than silently using another voice.

## Cutting Hermes over to this stack (done 2026-10-30)

* Hermes agent config (volume `hermes_hermes-data`, `config.yaml`):
  `tts.openai.base_url: http://host.docker.internal:8081/v1`,
  `model: pocket-tts-german` (the gateway reports exactly that model id —
  drop-in), `voice: lucy`. The pre-switch config is backed up in the volume
  as `backups/config/config.yaml.bak.tts-switch.*`.
* The `localai` service block has been removed from
  `../../hermes/compose.yaml`; the LocalAI volumes (`localai-*`) are still
  there until a rollback is ruled out (`docker volume rm` them then).
  Details of the old setup:
  [Model Evaluation Details](../Model%20Evaluation%20Details.md#localai-ehemaliges-produktiv-setup-bis-30102026).
* Verified: synthesis request from inside the `hermes` container
  (`host.docker.internal:8081`) returns real MP3.

## audio.cpp upstream mode (productive since 2026-11-23)

`../compose.yaml` runs the image with an entrypoint override — `gateway.py`
alone as a pure proxy in front of the audio.cpp server (same file, service
`audio-cpp`, compose-internal `audio-cpp:8080`; Qwen3-TTS 12Hz 1.7B Base +
lucy preset; setup:
[Model Evaluation Details](../Model%20Evaluation%20Details.md#audiocpp-als-qwen3-tts-server-produktiv-schicht-23112026)). Chosen because two
parallel gufo instances (LLM + TTS) did not run cleanly together. Two env
vars adapt the upstream request (both unset = pockettts/gufo behavior):

- `TTS_STREAM_FORMAT=audio` — audio.cpp only streams raw PCM when the speech
  request carries `stream_format` (`audio` = binary chunks; `sse` would be
  base64 events). The gateway always wants the binary stream, so it overwrites
  any client-supplied value, like it does with `response_format`.
- `TTS_DEFAULT_VOICE=lucy` — fills a missing/empty/null `voice` in the speech
  request with a backend preset name. Explicit non-empty voices pass through.

Measured through the proxy (2026-11-23, opus): first byte 0.25 s short
sentence / 1.7 s long sentence, total ≈ synthesis time (~2× realtime at system
idle, ~1× while the 125B LLM runs hot).

**FFmpeg input pipeline (fixed 2026-11-23):** ffmpeg's file/pipe protocol
pads buffered reads up to `PIPE_THRESHOLD` = 128 KiB of input before the first
demuxed packet — rate- and chunk-size-independent. With the fast pockettts
backend that padding hid under the generation time; with a ~1× backend the
first output byte came only after ~3 s. The gateway therefore serves the
backend PCM over a per-request loopback TCP socket that ffmpeg connects to
(`-i tcp://127.0.0.1:<port>`, listener bound before `Popen`) instead of
stdin — first output byte back to ~0.1 s. CLI knobs do not help
(`-probesize`, `-analyzeduration`, `-fflags +nobuffer`, `-re`, `-blocksize`;
feeding WAV instead of raw makes it worse), details in
[Model Evaluation Details](../Model%20Evaluation%20Details.md#audiocpp-als-qwen3-tts-server-produktiv-schicht-23112026).

## gufo upstream mode (historical, 23.11.2026 — one day)

`compose.yaml` (this directory, before the merge into `../compose.yaml`) ran
the image with an entrypoint override — `gateway.py` alone
as a pure proxy in front of `gufo serve tts` (`../../gufo-tts.sh`, host port
8082, Qwen3-TTS 12Hz 1.7B Base + lucy). No gateway code change was needed —
gufo streams s16le/24 kHz PCM just like `tts-server`, so
`TTS_BACKEND=http://host.docker.internal:8082` kept every transcoder
(mp3/opus/aac/flac/wav, chunked) working unchanged. `gufo serve tts` and its
`gufo-tts.sh` were retired as fallback on 2026-11-23; both live in the Git
history.

- No Vulkan devices, no `PKTTS_*` vars, no `PKTTS_REF_WAV` registration — lucy
  comes from gufo's `--voice`/`--voice-text` serve flags.
- Clients use the gufo model id `qwen3-tts-12hz-1.7b-base` directly (set in the
  Hermes agent config). gufo's mapping must be published on `0.0.0.0`
  (script: `HOST=0.0.0.0`) or containers can't reach it.
- Exactly one thing occupies :8081. The old embedded-Vulkan service was removed
  from compose (Git history); rebuilding that path means restoring its block
  and pointing the Hermes `tts.openai.model` back at `pocket-tts-german`..
- Measured through the proxy (2026-11-23): mp3 first byte 1.9–2.9 s, ogg 1.2 s
  (gufo's first audio ~0.2–0.35 s plus ffmpeg buffering), total ≈ synthesis time.

## Configuration (`../compose.yaml`, `gateway.environment`)

| Variable | Default | Purpose |
|---|---|---|
| `TTS_BACKEND` | `http://127.0.0.1:8085` | upstream base URL (compose: `http://host.docker.internal:8083`, the audio.cpp server) |
| `TTS_STREAM_FORMAT` | unset | added as `stream_format` to every speech request (compose: `audio`, required by audio.cpp; leave unset for gufo/pockettts) |
| `TTS_DEFAULT_VOICE` | unset | fills a missing/empty/null `voice` upstream (compose: `lucy`; leave unset to forward voice handling entirely to the client) |
| `PKTTS_MODEL` | german_24l_april Q8_0 | GGUF language pack (6l packs work too, see benchmark) |
| `PKTTS_VOICES` | german_24l_april-voices.gguf | built-in voices (optional) |
| `PKTTS_DEVICE` | `Vulkan0` | `CPU` as fallback without /dev/dri |
| `PKTTS_SERVER_VOICE` | `lucy` | native backend `--voice` default registry name |
| `PKTTS_REF_WAV` | `/references/sample.wav` | optional startup reference registered under `PKTTS_SERVER_VOICE` |
| `TTS_MODEL_NAME` | `pocket-tts-german` | outward model id (drop-in; unused when the backend reports its own id — audio.cpp and gufo both report `qwen3-tts-12hz-1.7b-base`) |

## Operations & limits

- Resource limits are configurable through environment variables:
  `TTS_MAX_BODY_BYTES=8388608` (8 MiB), `TTS_MAX_INPUT_CHARS=10000`,
  `TTS_MAX_CONNECTIONS=16`, `TTS_MAX_SYNTHESIS=2`, `TTS_IO_TIMEOUT=30`
  (socket inactivity, seconds), and `TTS_STREAM_TIMEOUT=180` (stream deadline
  after backend headers, seconds). All must be positive. Voice registration
  has a separate 120-second backend I/O timeout. Excess capacity returns 429,
  oversized bodies 413, and invalid/empty input 400. Requests require a single
  Content-Length; chunked request bodies are unsupported. POST connections
  close after their response, including when a request body is rejected.
- Streaming failures before audio headers return an error response. After
  headers they close the connection without the successful terminating chunk;
  clients must treat incomplete HTTP chunk framing as an error, not usable
  complete audio. Upstream reads, downstream writes, and encoder lifetime are
  bounded. Disconnect cleanup interrupts upstream reads and reaps FFmpeg.
- AMD/iGPU: the **audio-cpp backend** service needs `/dev/dri` + groups
  `render`/`video` (GIDs via `getent group render video`, defaults in its
  `../compose.yaml` service definition).
- `response_format`: `mp3|opus|ogg|aac|flac|wav|pcm`. Format resolution:
  explicit `response_format` > `Accept` header (`audio/ogg|audio/opus|
  audio/mpeg|audio/aac|audio/flac|audio/wav|audio/x-wav`, q-values honored,
  q=0 rejected, wildcards count as "no preference") > default `opus`
  (deviation from OpenAI's `mp3`): 24 kbps mono, `libopus` speech tuning
  (`-application voip`, 60 ms frames) — voice-note grade at ~2.7× less data
  than the old 48k/20 ms setting, and the 24 kHz source caps bandwidth at
  12 kHz anyway.
- Non-standard extension `bitrate` in the request body (OpenAI has none):
  desired average bitrate for the lossy encoders as bits/s (`24000`) or with
  `k` suffix (`"24k"`, `"64kbps"`), clamped to 6k–512k, ignored for
  flac/wav/pcm, rejected with 400 if unparseable. Consumed by the gateway and
  never forwarded to the backend.
- Streaming: responses are always chunked. Measured with the audio.cpp backend
  (opus): TTFB 0.25 s (short sentence), total ≈ synthesis time. Historical
  (pockettts 24l, Vulkan): TTFB 0.02 s (mp3/wav) or 0.28 s (opus), total
  0.4–0.9 s for the test sentence.
- WAV is encoded from streaming PCM, not passed through from the backend.
  Its RIFF and data sizes are deliberately `0xffffffff` (unknown length on a
  non-seekable output). HTTP chunk termination marks completion; these sizes
  are not the actual audio length. Players requiring finalized WAV sizes may
  reject it or report a wrong duration. Use MP3/Opus for those clients, or
  remux the downloaded WAV locally into a seekable file. No buffering of the
  complete answer is introduced. FLAC also has unknown duration while streaming.
- Model load takes < 1 s; `/health` queries the backend with a two-second
  timeout and returns 503 if unavailable. The container supervisor exits if
  either service dies so the compose restart policy can recover both. SIGTERM
  stops both services and their encoder children (five-second grace period).
- The gateway is deliberately minimal (no auth). Published on all interfaces
  (see "Startup"), the API is reachable from the LAN — same policy as gufo on
  this machine; only run on networks you trust.

## Regression tests

Run `python3 -m unittest -v` in this directory (FFmpeg required for codec tests).
The tests include real FFmpeg and local HTTP streaming: MP3, Opus, WAV and PCM
deliver audio before the mock backend finishes; truncated upstream streams and
expired deadlines must not produce a successful HTTP terminal chunk. They also
cover encoder errors, health, child exits, capacity limits, unchanged voice
proxying when `TTS_DEFAULT_VOICE`/`TTS_STREAM_FORMAT` are unset, their
injection when set, separate startup reference registration and the TCP-fed
encoder pipeline. Codec tests exercise all supported formats.

### Networking upgrade (optional, not done)

Publishing 8081 host-wide works but exposes the unauthenticated API. The
clean alternative is one shared external network for both stacks:

```bash
docker network create tts
```

declare `networks: tts: { external: true }` in both compose files (with the
services joining `[default, tts]`), point Hermes at `http://gateway:8080/v1`
— and the gateway can go back to a loopback-only bind (`127.0.0.1:8081:8080`).
