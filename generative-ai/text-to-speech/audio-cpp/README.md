# audio.cpp TTS server (Qwen3-TTS, voice cloning)

Productive TTS backend behind [`../tts-gateway/`](../tts-gateway/README.md)
(since 2026-11-23). [audio.cpp](https://github.com/0xShug0/audio.cpp)'s
`audiocpp_server` serves **Qwen3-TTS 12Hz 1.7B Base** (voice cloning) on the
Strix Halo via **Vulkan** — chosen because two parallel gufo instances
(LLM + TTS) did not run cleanly together.

```
Hermes/WebUI → tts-gateway :8081 (OpenAI API + opus/mp3) → audio-cpp server :8083 (PCM) → Vulkan
```

## Start

```bash
../audio-cpp-tts.sh          # container audio-cpp-tts, host port 8083
```

Model: `/srv/llama/models/Qwen3-TTS-12Hz-1.7B-Base-GGUF/qwen3-tts-12hz-1.7b-base-q8_0_v2.gguf`
(official Q8 package from [audio-cpp/audio.cpp-gguf](https://huggingface.co/audio-cpp/audio.cpp-gguf)).
Voices: `/srv/llama/tts-voices/` (read-only); `lucy` is a server-side voice
preset in `server.json` (reference wav + transcript), so clients can send
`"voice": "lucy"` — and the tts-gateway fills a missing voice via
`TTS_DEFAULT_VOICE`.

## Pinning

`server.json` + `../audio-cpp-tts.sh` pin
`ghcr.io/0xshug0/audio.cpp:full-vulkan-20261123-f79c880` (manifest digest
`sha256:70443d55…`, identical to `full-vulkan` when pulled on 2026-11-23).
The tag contains audio.cpp v0.9.6 (released 2026-11-21) plus following
`main` commits — CI publishes daily `full-<backend>-<date>-<sha>` tags only,
no per-release images.

## Gateway contract

* `mode: "streaming"` + request `"response_format":"pcm"` + `"stream_format":"audio"`
  → raw s16le/24 kHz/mono PCM streamed while generating (first audio byte ~0.65 s).
  Without `stream_format` audio.cpp does not stream; the tts-gateway sets it via
  `TTS_STREAM_FORMAT=audio`.
* Model id `qwen3-tts-12hz-1.7b-base` (same as the former gufo backend) →
  Hermes and existing configs unchanged.
* `GET /v1/audio/voices` returns the configured presets. There is **no** POST
  voice registration (unlike the old pockettts.cpp backend) — voices live in
  `server.json` or a `voice_dir` library.

Measured 2026-11-23 (details in [`Model Evaluation Details.md`](Model%20Evaluation%20Details.md#audiocpp-als-qwen3-tts-server-produktiv-schicht-23112026)):
~2–2.3× realtime when the system is idle, ~1× under full LLM load (gufo: ~1.7×).
No ROCm/HIP Docker image exists upstream; the HIP path (gfx1151 +
`--backend-impl gfx1151_v1`) would need a self-built image.
