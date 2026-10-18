#!/usr/bin/env bash
# Serve Qwen3.8 Flash Next from gufo on the Strix Halo (HIP: /dev/kfd + /dev/dri).
# Every setting is overridable via env vars, e.g.:  HOST=0.0.0.0 PORT=8080 ./gufo-run.sh
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/gufo-org/toolboxes/gufo-runtime:0.17.0}"
MODELS_DIR="${MODELS_DIR:-/srv/llama/models/Qwen3.8-Flash-Next-125B-A6B}"
MODEL="${MODEL:-/models/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf}"
MTP_MODEL="${MTP_MODEL:-/models/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf}"
MTPROJ="${MTPROJ:-/models/mmproj-BF16.gguf}"
HOST="${HOST:-127.0.0.1}" # set HOST=0.0.0.0 to expose the server on your LAN
PORT="${PORT:-8080}"
RUN_AS="${RUN_AS:-1000:1000}"

docker run --rm \
  --user "$RUN_AS" \
  --group-add render \
  --device /dev/kfd \
  --device /dev/dri \
  --ulimit memlock=-1 \
  -p "$PORT:$PORT" \
  -v "$MODELS_DIR:/models/:ro" \
  "$IMAGE" \
  gufo serve llm \
  --model "$MODEL" \
  --speculative mtp \
  --mtp-model "$MTP_MODEL" \
  --mmproj "$MTPROJ" \
  --context 262144 \
  --max-tokens 8192 \
  --temperature 1.0 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0.0 \
  --presence-penalty 0.0 \
  --host "$HOST" \
  --port "$PORT"
