#!/bin/sh
# Starts tts-server (container loopback only) and the gateway on :8080.
set -eu

MODEL="${PKTTS_MODEL:?PKTTS_MODEL must be set}"
VOICES="${PKTTS_VOICES:-}"
DEVICE="${PKTTS_DEVICE:-Vulkan0}"
BACKEND_PORT=8085

ARGS="--model $MODEL --device $DEVICE --host 127.0.0.1 --port $BACKEND_PORT"
if [ -n "$VOICES" ] && [ -f "$VOICES" ]; then
    ARGS="$ARGS --voices $VOICES"
fi
# tts-server prefers a built-in voice as its default; the gateway sets the
# target voice per request anyway.
if [ -n "${PKTTS_SERVER_VOICE:-}" ]; then
    ARGS="$ARGS --voice $PKTTS_SERVER_VOICE"
fi

exec python3 /opt/tts/supervisor.py tts-server $ARGS
