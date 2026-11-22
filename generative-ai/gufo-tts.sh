#!/usr/bin/env bash
# Serve Qwen3-TTS 12Hz 1.7B Base (voice cloning) from gufo on the Strix Halo
# (HIP: /dev/kfd + /dev/dri).  Docs: docs/models/qwen3-tts.md im gufo-Repo.
# Every setting is overridable via env vars, e.g.:  PORT=9000 ./gufo-tts.sh
# Der gufo-Container (LLM, Port 8080) kann parallel laufen.
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/gufo-org/toolboxes/gufo-runtime:0.35.0}"
MODELS_DIR="${MODELS_DIR:-/srv/llama/models}"
MODEL="${MODEL:-/models/Qwen3-TTS-12Hz-1.7B-Base}"
VOICES_DIR="${VOICES_DIR:-/srv/llama/tts-voices}"
VOICE_NAME="${VOICE_NAME:-lucy}"
HOST="${HOST:-127.0.0.1}" # set HOST=0.0.0.0 to expose the server on your LAN
PORT="${PORT:-8082}"
RUN_AS="${RUN_AS:-1000:1000}"

# gufo lauscht im Container fest auf 0.0.0.0:8080 (wie im LLM-Container);
# die eigentliche Exponierung steuert die Port-Mapping-Adresse.
docker run --rm \
  --name gufo-tts \
  --user "$RUN_AS" \
  --group-add render \
  --device /dev/kfd \
  --device /dev/dri \
  --ulimit memlock=-1 \
  -p "$HOST:$PORT:8080" \
  -v "$MODELS_DIR:/models/:ro" \
  -v "$VOICES_DIR:/voices/:ro" \
  "$IMAGE" \
  gufo serve tts \
  --model "$MODEL" \
  --voice "$VOICE_NAME=/voices/$VOICE_NAME.wav" \
  --voice-text "$VOICE_NAME=/voices/$VOICE_NAME.txt" \
  --voice-lang "$VOICE_NAME=German" \
  --host 0.0.0.0 \
  --port 8080
