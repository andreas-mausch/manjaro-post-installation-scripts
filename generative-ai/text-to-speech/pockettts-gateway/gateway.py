#!/usr/bin/env python3
"""OpenAI TTS gateway in front of pockettts.cpp's tts-server.

The tts-server only speaks wav/pcm. This gateway exposes the same OpenAI API
(POST /v1/audio/speech, GET /v1/models, GET/POST/DELETE /v1/audio/voices) and
additionally serves mp3/opus/aac/flac via ffmpeg transcoding — streamed
(chunked), i.e. the client receives bytes while generation is still running.

Also persistent: registered voices (the tts-server loses them on restart) and
the reference voice from TTS_REF_WAV, registered as TTS_DEFAULT_VOICE at
startup.

Python stdlib only; ffmpeg must be on PATH.
"""
import base64
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND = os.environ.get("TTS_BACKEND", "http://127.0.0.1:8085")
PORT = int(os.environ.get("GATEWAY_PORT", "8080"))
STATE_DIR = os.environ.get("TTS_STATE_DIR", "/data/voices")
DEFAULT_VOICE = os.environ.get("TTS_DEFAULT_VOICE", "")   # e.g. "lucy"
REF_WAV = os.environ.get("TTS_REF_WAV", "")               # e.g. /references/sample.wav
MODEL_NAME = os.environ.get("TTS_MODEL_NAME", "")         # e.g. pocket-tts-german (drop-in)

SAMPLE_RATE = 24000  # the tts-server streams s16le mono at 24 kHz

# response_format -> ffmpeg encoder arguments (or raw pass-through for pcm)
FFMPEG_FORMATS = {
    "mp3":  ["-c:a", "libmp3lame", "-b:a", "64k", "-f", "mp3"],
    "opus": ["-c:a", "libopus", "-b:a", "48k", "-f", "ogg"],
    "ogg":  ["-c:a", "libopus", "-b:a", "48k", "-f", "ogg"],
    "aac":  ["-c:a", "aac", "-b:a", "64k", "-f", "adts"],
    "flac": ["-c:a", "flac", "-f", "flac"],
    # Non-seekable RIFF uses 0xffffffff lengths, deliberately not a final WAV.
    "wav":  ["-c:a", "pcm_s16le", "-rf64", "never", "-f", "wav"],
}
CONTENT_TYPES = {
    "mp3": "audio/mpeg", "opus": "audio/ogg", "ogg": "audio/ogg",
    "aac": "audio/aac", "flac": "audio/flac", "wav": "audio/wav",
    "pcm": "application/octet-stream",
}


def log(*a):
    print("[gateway]", *a, flush=True)


def backend_request(path, method="GET", body=None, timeout=None):
    req = urllib.request.Request(f"{BACKEND}{path}", method=method, data=body)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    return urllib.request.urlopen(req, timeout=timeout)


def safe_name(name):
    return re.sub(r"[^A-Za-z0-9._-]", "_", name or "")[:100] or "voice"


# ---------------------------------------------------------------- voice registry

def register_voice(name, body_json):
    """Forwards a voice registration to the backend and persists it."""
    resp = backend_request("/v1/audio/voices", "POST", json.dumps(body_json).encode(), timeout=120)
    resp.read()
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(os.path.join(STATE_DIR, safe_name(name) + ".json"), "w") as f:
        json.dump(body_json, f)
    log(f"voice '{name}' registered and persisted")


def startup_voices():
    # Wait for the backend (tts-server is loading the model).
    for _ in range(240):
        try:
            backend_request("/v1/models", timeout=2).read()
            break
        except Exception:
            time.sleep(0.5)
    else:
        log("ERROR: backend not reachable")
        sys.exit(1)

    # Restore persisted registrations.
    if os.path.isdir(STATE_DIR):
        for fn in sorted(os.listdir(STATE_DIR)):
            if not fn.endswith(".json"):
                continue
            try:
                with open(os.path.join(STATE_DIR, fn)) as f:
                    body = json.load(f)
                register_voice(body.get("name", fn), body)
            except Exception as e:
                log(f"warning: could not re-activate voice from {fn}: {e}")

    # Register the reference voice as default if not present yet.
    if DEFAULT_VOICE and REF_WAV and os.path.isfile(REF_WAV):
        try:
            with backend_request("/v1/audio/voices", timeout=10) as response:
                existing = json.load(response)["voices"]
            have = any((v.get("name") if isinstance(v, dict) else v) == DEFAULT_VOICE for v in existing)
        except Exception as e:
            log(f"warning: cannot check default voice, leaving it unchanged: {e}")
            have = True
        if not have:
            with open(REF_WAV, "rb") as f:
                body = {"name": DEFAULT_VOICE, "wav_b64": base64.b64encode(f.read()).decode()}
            try:
                register_voice(DEFAULT_VOICE, body)
            except Exception as e:
                log(f"warning: reference voice '{DEFAULT_VOICE}' not registered: {e}")
    log("ready")


# ---------------------------------------------------------------- handler

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # quieter, compact log style
        log(self.command, self.path, "→", args[1] if len(args) > 1 else "")

    # -- small helpers -------------------------------------------------------
    def _send_json(self, status, payload):
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _begin_chunked(self, status, ctype):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

    def _write_chunk(self, data):
        if data:
            self.wfile.write(f"{len(data):X}\r\n".encode() + data + b"\r\n")

    def _end_chunked(self):
        self.wfile.write(b"0\r\n\r\n")

    def _forward_simple(self, path, body=None, method="GET"):
        """Pass non-audio routes through 1:1."""
        try:
            resp = backend_request(path, method, body, timeout=30)
            data, status, ctype = resp.read(), resp.status, resp.headers.get("Content-Type", "application/json")
        except urllib.error.HTTPError as e:
            data, status, ctype = e.read(), e.code, e.headers.get("Content-Type", "application/json")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    # -- routes ---------------------------------------------------------------
    def do_GET(self):
        if self.path == "/health":
            try:
                with backend_request("/v1/models", timeout=2) as response:
                    json.load(response)
                self._send_json(200, {"status": "ok"})
            except Exception as e:
                self._send_json(503, {"status": "unavailable", "error": str(e)})
        elif self.path == "/v1/models":
            try:
                resp = backend_request("/v1/models", timeout=10)
                models = json.load(resp)
            except Exception as e:
                self._send_json(502, {"error": {"message": f"backend: {e}"}})
                return
            if MODEL_NAME:  # drop-in for existing configurations
                for m in models.get("data", []):
                    m["id"] = MODEL_NAME
            self._send_json(200, models)
        elif self.path.startswith("/v1/audio/voices"):
            self._forward_simple(self.path)
        else:
            self._send_json(404, {"error": {"message": "not found"}})

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0) or 0))
        if self.path == "/v1/audio/speech":
            self._speech(body)
        elif self.path == "/v1/audio/voices":
            try:
                payload = json.loads(body)
                register_voice(payload.get("name", ""), payload)
                self._send_json(200, {"object": "list", "data": [{"id": payload.get("name")}]})
            except urllib.error.HTTPError as e:
                self._send_json(e.code, {"error": {"message": e.read().decode(errors="replace")}})
            except Exception as e:
                self._send_json(400, {"error": {"message": str(e)}})
        else:
            self._send_json(404, {"error": {"message": "not found"}})

    def do_DELETE(self):
        if self.path.startswith("/v1/audio/voices/"):
            name = self.path.rsplit("/", 1)[-1]
            self._forward_simple(self.path, method="DELETE")
            try:
                os.remove(os.path.join(STATE_DIR, safe_name(name) + ".json"))
            except FileNotFoundError:
                pass
        else:
            self._send_json(404, {"error": {"message": "not found"}})

    # -- speech ---------------------------------------------------------------
    def _speech(self, body):
        try:
            payload = json.loads(body)
            fmt = (payload.get("response_format") or "mp3").lower()
        except Exception:
            self._send_json(400, {"error": {"message": "invalid JSON"}})
            return
        if fmt not in FFMPEG_FORMATS and fmt != "pcm":
            self._send_json(400, {"error": {"message": f"response_format '{fmt}' not supported"}})
            return
        if DEFAULT_VOICE and not payload.get("voice"):
            payload["voice"] = DEFAULT_VOICE
        payload["response_format"] = "pcm"  # backend streams s16le/24 kHz/mono

        try:
            up = backend_request("/v1/audio/speech", "POST", json.dumps(payload).encode())
        except urllib.error.HTTPError as e:
            self._send_json(e.code, {"error": {"message": e.read().decode(errors="replace")}})
            return
        except Exception as e:
            self._send_json(502, {"error": {"message": f"backend: {e}"}})
            return

        started = False

        def emit(chunk):
            nonlocal started
            if not started:
                self._begin_chunked(200, CONTENT_TYPES[fmt])
                started = True
            self._write_chunk(chunk)

        try:
            if fmt == "pcm":
                while True:
                    chunk = up.read1(65536)
                    if not chunk:
                        break
                    emit(chunk)
            else:
                self._transcode(up, fmt, emit)
            if not started:
                self._begin_chunked(200, CONTENT_TYPES[fmt])
            self._end_chunked()
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True  # client aborted
        except Exception as e:
            log("error while streaming:", e)
            if started:
                self.close_connection = True
            else:
                self._send_json(502, {"error": {"message": str(e)}})
        finally:
            up.close()

    def _transcode(self, up, fmt, emit):
        ffmpeg = subprocess.Popen(
            ["ffmpeg", "-loglevel", "error",
             "-f", "s16le", "-ar", str(SAMPLE_RATE), "-ac", "1", "-i", "pipe:0",
             *FFMPEG_FORMATS[fmt], "pipe:1"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        errors = []
        stderr = bytearray()

        def drain():
            while True:
                chunk = ffmpeg.stderr.read1(4096)
                if not chunk:
                    break
                stderr.extend(chunk)
                del stderr[:-8192]

        def feed():
            try:
                while True:
                    chunk = up.read1(65536)
                    if not chunk:
                        break
                    ffmpeg.stdin.write(chunk)
            except Exception as e:
                errors.append(e)
            finally:
                try:
                    ffmpeg.stdin.close()
                except Exception:
                    pass

        feeder = threading.Thread(target=feed, daemon=True)
        drainer = threading.Thread(target=drain, daemon=True)
        feeder.start()
        drainer.start()
        try:
            while True:
                chunk = ffmpeg.stdout.read1(65536)
                if not chunk:
                    break
                emit(chunk)
            feeder.join(timeout=10)
            if feeder.is_alive():
                raise RuntimeError("upstream feeder did not finish")
            code = ffmpeg.wait(timeout=10)
            drainer.join(timeout=10)
            if errors:
                raise RuntimeError(f"upstream stream failed: {errors[0]}")
            if code:
                raise RuntimeError(f"ffmpeg exited {code}: {stderr.decode(errors='replace')}")
        finally:
            if ffmpeg.poll() is None:
                ffmpeg.kill()
            ffmpeg.wait()
            up.close()
            feeder.join(timeout=10)
            drainer.join(timeout=10)
            for pipe in (ffmpeg.stdin, ffmpeg.stdout, ffmpeg.stderr):
                pipe.close()


if __name__ == "__main__":
    startup_voices()
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
