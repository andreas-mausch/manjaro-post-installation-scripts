# TTS container: pockettts.cpp on Vulkan (OpenAI API)

Standalone TTS stack replacing the `localai` service from
[`../../hermes/compose.yaml`](../../hermes/compose.yaml). Model: **Pocket-TTS
german 24l, April checkpoint, Q8_0** (`/srv/llama/models/pocket-tts/german_24l/`),
synthesis on the iGPU via Vulkan — ~5.5× realtime instead of ~0.9×
(LocalAI/Python/CPU with 24l); see the [benchmark](2026-10-30-benchmark.md).

```
Hermes/WebUI/curl ──> gateway :8080 (in container) ──> tts-server 127.0.0.1:8085 ──> Vulkan
                      OpenAI API + ffmpeg:              OpenAI API, wav/pcm only
                      mp3/opus/aac/flac/wav/pcm,        (pcm = stream while
                      streamed (chunked)                 generating)
```

`pockettts.cpp`'s `tts-server` (pinned to `fab7972`) speaks the OpenAI
endpoints but only WAV/PCM — in exchange, PCM streams during generation. The
bundled Python gateway (`gateway.py`, stdlib only + ffmpeg) adds the
**mp3, opus, aac, flac** formats (ogg alias = real Opus, better than LocalAI's
"ogg" which delivered Vorbis) and encodes from the PCM stream — the client
receives bytes before the answer is complete.

The gateway also fixes two `pockettts.cpp` shortcomings vs. LocalAI: registered
voices survive restarts (persisted in the `pockettts-gateway-state` volume) and the reference
voice `sample.wav` is cloned at startup into voice **`lucy`**, set as the
default (env `TTS_DEFAULT_VOICE`).

## Startup

```bash
docker compose up -d --build    # first build needs internet + a few minutes
docker compose logs -f pockettts-gateway   # wait for "[gateway] ready"
```

The service listens on `127.0.0.1:8081` (same port as LocalAI before; host
port 8080 is taken by gufo). **Stop `localai` first**, otherwise the two fight
over 8081 (see "Cutover").

## Test

```bash
# WAV (streaming RIFF, unknown length)
curl --fail-with-body http://localhost:8081/v1/audio/speech -H 'Content-Type: application/json' \
  -d '{"model":"pocket-tts-german","input":"Hallo, sag mal etwas zu mir.","response_format":"wav"}' \
  --output test.wav

# Opus, streaming: measures time-to-first-byte and total time
curl -N --fail-with-body -o test.ogg -w 'TTFB: %{time_starttransfer}s  total: %{time_total}s\n' \
  http://localhost:8081/v1/audio/speech -H 'Content-Type: application/json' \
  -d '{"model":"pocket-tts-german","input":"Es ist 13:05. Die Items werden mit Sprites gerendered. Tschüß.","response_format":"opus"}'

# Verify codec (expected: opus, mono)
ffprobe -v error -show_entries stream=codec_name,sample_rate,channels -of json test.ogg

# Voices: lucy (cloned, default) + built-ins (juergen, vera) + your own
curl -s http://localhost:8081/v1/audio/voices
```

Omitting `voice` is fine (→ `lucy`). Register your own reference voices via
`POST /v1/audio/voices` with `{"name":"…","wav_b64":"…"}` (base64 WAV; for
large files use `--data @file`); they survive restarts.
Names are case-insensitive (stored lowercase), with 1 to 100 characters.
State filenames use SHA-256 instead of lossy character replacement; existing
registrations migrate on startup. Updates use atomic replacement, and registry
mutations are serialized. A failed backend deletion retains the saved voice.

## Cutting Hermes over to this stack

While the `localai` service is still running:

```bash
(cd ../../hermes && docker compose stop localai)   # frees port 8081
docker compose up -d
```

Hermes keeps seeing `http://host.docker.internal:8081/v1` with model
`pocket-tts-german` (the gateway reports exactly that model id). If the Hermes
configuration pointed at `http://localai:8080` (compose network), switch it to
`host.docker.internal:8081` — the concrete `config set` commands are in
[`../../hermes/README.md`](../../hermes/README.md), section 6.

Once everything works, the `localai` service block can be removed from
`../../hermes/compose.yaml`; clean up the LocalAI volumes (`localai-*`)
afterwards with `docker volume rm`. Details of the old setup:
[`LocalAI.md`](LocalAI.md).

## Configuration (compose.yaml `environment`)

| Variable | Default | Purpose |
|---|---|---|
| `PKTTS_MODEL` | german_24l_april Q8_0 | GGUF language pack (6l packs work too, see benchmark) |
| `PKTTS_VOICES` | german_24l_april-voices.gguf | built-in voices (optional) |
| `PKTTS_DEVICE` | `Vulkan0` | `CPU` as fallback without /dev/dri |
| `TTS_DEFAULT_VOICE` | `lucy` | voice for requests without one; cloned from REF_WAV |
| `TTS_REF_WAV` | `/references/sample.wav` | bind mount of the reference |
| `TTS_MODEL_NAME` | `pocket-tts-german` | outward model id (drop-in) |

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
- AMD/iGPU: the container needs `/dev/dri` + groups `render`/`video`
  (GIDs via `getent group render video`, kept as defaults in compose.yaml).
- `response_format`: `mp3|opus|ogg|aac|flac|wav|pcm` (default `mp3`, like OpenAI).
- Streaming: responses are always chunked. Measured (24l, Vulkan): TTFB 0.02 s
  (mp3/wav) or 0.28 s (opus), total time 0.4–0.9 s for the test sentence.
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
- The gateway is deliberately minimal (no auth — loopback-only, as before);
  handle encryption/exposure the same way as LocalAI.

## Regression tests

Run `python3 -m unittest -v` in this directory (FFmpeg required for codec tests).
The tests include real FFmpeg and local HTTP streaming: MP3, Opus, WAV and PCM
deliver audio before the mock backend finishes; truncated upstream streams and
expired deadlines must not produce a successful HTTP terminal chunk. They also
cover encoder errors, health, child exits, persistence and capacity limits.
