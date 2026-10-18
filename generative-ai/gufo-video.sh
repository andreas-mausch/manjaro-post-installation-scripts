#!/usr/bin/env bash
# Generate a short video with MiniMax H3 via gufo on the Strix Halo.
# Prompt is the first arg (or $PROMPT); override other settings via env vars.
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/gufo-org/toolboxes/gufo-runtime:20260924T104050}"
MODELS_DIR="${MODELS_DIR:-/srv/llama/models/MiniMax-H3}"
PROMPT="${1:-${PROMPT:-A red fox walking through snow}}"
OUTPUT="${OUTPUT:-/tmp/output.mp4}"
SEED="${SEED:-42}"
RUN_AS="${RUN_AS:-1000:1000}"
OUT_DIR="$(dirname "$OUTPUT")"
OUT_NAME="$(basename "$OUTPUT")"

docker run --rm \
  --user "$RUN_AS" \
  --group-add render \
  --device /dev/kfd \
  --device /dev/dri \
  --ulimit memlock=-1 \
  -v "$MODELS_DIR:/models/:ro" \
  -v "$OUT_DIR:/output" \
  "$IMAGE" \
  gufo video \
  --model /models \
  --preset exact \
  --seed "$SEED" \
  --output "/output/$OUT_NAME" \
  --profile \
  "$PROMPT"
