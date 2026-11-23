#!/usr/bin/env python3
"""Register an optional backend reference, then replace this process with the gateway."""
import base64
import json
import os
import sys
import time
import urllib.request


def bootstrap():
    reference = os.environ.get("PKTTS_REF_WAV", "")
    if reference:
        name = os.environ["PKTTS_SERVER_VOICE"]
        backend = "http://127.0.0.1:8085"
        for _ in range(240):
            try:
                with urllib.request.urlopen(backend + "/v1/models", timeout=2) as response:
                    response.read()
                break
            except OSError:
                time.sleep(0.5)
        else:
            raise RuntimeError("backend not reachable for reference registration")
        with open(reference, "rb") as source:
            body = json.dumps({"name": name, "wav_b64": base64.b64encode(source.read()).decode()}).encode()
        request = urllib.request.Request(backend + "/v1/audio/voices", data=body,
                                         headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=120) as response:
            response.read()
        print(f"[startup] reference '{name}' registered in backend RAM", flush=True)
    os.execv(sys.executable, [sys.executable, "/opt/tts/gateway.py"])


if __name__ == "__main__":
    bootstrap()
