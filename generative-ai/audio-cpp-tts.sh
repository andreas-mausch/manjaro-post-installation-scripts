#!/usr/bin/env bash
# Serve Qwen3-TTS 12Hz 1.7B Base (voice cloning) from audio.cpp on the Strix
# Halo (Vulkan/RADV: /dev/dri). Trial alternative to gufo-tts.sh — same model
# id (qwen3-tts-12hz-1.7b-base) and voice lucy, so the tts-gateway and Hermes
# keep working unchanged. No official ROCm/HIP image exists (Vulkan only);
# docs: https://github.com/0xShug0/audio.cpp (docs/models/qwen3_tts.md).
# Every setting is overridable via env vars, e.g.:  PORT=9000 ./audio-cpp-tts.sh
# The gufo LLM container (port 8080) can run in parallel.
set -euo pipefail

# Gepinnt: Tag des Tages-Builds vom 23.11.2026 (commit f79c880, Deckblatt
# sha256:70443d55…), identisch mit full-vulkan beim Pull am 23.11.
# Enthält v0.9.6 (Release 21.11.2026) plus folgende main-Commits — ein
# exaktes v0.9.6-Release-Image existiert nicht, CI baut täglich von main.
IMAGE="${IMAGE:-ghcr.io/0xshug0/audio.cpp:full-vulkan-20261123-f79c880}"
MODELS_DIR="${MODELS_DIR:-/srv/llama/models}"
VOICES_DIR="${VOICES_DIR:-/srv/llama/tts-voices}"
CONFIG="${CONFIG:-$(dirname "$(realpath "$0")")/text-to-speech/audio-cpp/server.json}"
HOST="${HOST:-0.0.0.0}" # set HOST=0.0.0.0 to expose the server on your LAN
PORT="${PORT:-8083}"

docker run --rm \
  --name audio-cpp-tts \
  --user "${RUN_AS:-1000:1000}" \
  --device /dev/dri \
  --group-add "$(getent group render | cut -d: -f3)" \
  --group-add "$(getent group video | cut -d: -f3)" \
  -p "$HOST:$PORT:8080" \
  -v "$MODELS_DIR:/models:ro" \
  -v "$VOICES_DIR:/voices/:ro" \
  -v "$CONFIG:/app/server.json:ro" \
  "$IMAGE" \
  server --config /app/server.json --backend vulkan
