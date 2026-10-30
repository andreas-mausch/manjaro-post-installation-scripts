#!/usr/bin/env python3
"""OpenAI TTS gateway in front of pockettts.cpp's tts-server.

The tts-server only speaks wav/pcm. This gateway exposes the same OpenAI API
(POST /v1/audio/speech, GET /v1/models, GET/POST/DELETE /v1/audio/voices) and
additionally serves mp3/opus/aac/flac via ffmpeg transcoding — streamed
(chunked), i.e. the client receives bytes while generation is still running.

Python stdlib only; ffmpeg must be on PATH.
"""
import json
import os
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND = os.environ.get("TTS_BACKEND", "http://127.0.0.1:8085")
PORT = int(os.environ.get("GATEWAY_PORT", "8080"))
MODEL_NAME = os.environ.get("TTS_MODEL_NAME", "")         # e.g. pocket-tts-german (drop-in)

SAMPLE_RATE = 24000  # the tts-server streams s16le mono at 24 kHz
MAX_BODY_BYTES = int(os.environ.get("TTS_MAX_BODY_BYTES", "8388608"))
MAX_INPUT_CHARS = int(os.environ.get("TTS_MAX_INPUT_CHARS", "10000"))
IO_TIMEOUT = float(os.environ.get("TTS_IO_TIMEOUT", "30"))
STREAM_TIMEOUT = float(os.environ.get("TTS_STREAM_TIMEOUT", "180"))
MAX_CONNECTIONS = int(os.environ.get("TTS_MAX_CONNECTIONS", "16"))
MAX_SYNTHESIS = int(os.environ.get("TTS_MAX_SYNTHESIS", "2"))
if min(MAX_BODY_BYTES, MAX_INPUT_CHARS, IO_TIMEOUT, STREAM_TIMEOUT,
       MAX_CONNECTIONS, MAX_SYNTHESIS) <= 0:
    raise ValueError("TTS resource limits must be positive")
SYNTHESIS_SLOTS = threading.BoundedSemaphore(MAX_SYNTHESIS)

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


def backend_request(path, method="GET", body=None, timeout=IO_TIMEOUT):
    req = urllib.request.Request(f"{BACKEND}{path}", method=method, data=body)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    return urllib.request.urlopen(req, timeout=timeout)


def interrupt_upstream(response):
    # urllib has no cancellation API. Shutdown unblocks a concurrent read
    # before close() takes the buffered reader lock.
    try:
        response.fp.raw._sock.shutdown(socket.SHUT_RDWR)
    except (AttributeError, OSError):
        pass


class Server(ThreadingHTTPServer):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.slots = threading.BoundedSemaphore(MAX_CONNECTIONS)

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            try:
                request.settimeout(IO_TIMEOUT)
                request.sendall(b"HTTP/1.1 429 Too Many Requests\r\n"
                                b"Content-Length: 0\r\nConnection: close\r\n"
                                b"Retry-After: 1\r\n\r\n")
            finally:
                self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()


def wait_for_backend():
    # Wait for the backend (tts-server is loading the model).
    for _ in range(240):
        try:
            with backend_request("/v1/models", timeout=2) as response:
                response.read()
            break
        except Exception:
            time.sleep(0.5)
    else:
        log("ERROR: backend not reachable")
        sys.exit(1)

    log("ready")


# ---------------------------------------------------------------- handler

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def setup(self):
        super().setup()
        self.connection.settimeout(IO_TIMEOUT)

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

    def _forward_simple(self, path, body=None, method="GET", timeout=IO_TIMEOUT):
        """Pass non-audio routes through 1:1."""
        try:
            with backend_request(path, method, body, timeout=timeout) as resp:
                data, status, ctype = resp.read(), resp.status, resp.headers.get("Content-Type", "application/json")
        except urllib.error.HTTPError as e:
            with e:
                data, status, ctype = e.read(), e.code, e.headers.get("Content-Type", "application/json")
        except Exception as e:
            self._send_json(502, {"error": {"message": f"backend: {e}"}})
            return 502
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        return status

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
                with backend_request("/v1/models", timeout=10) as resp:
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
        self.close_connection = True  # Reject unread bodies without reusing the socket.
        if self.headers.get("Transfer-Encoding"):
            self._send_json(501, {"error": {"message": "chunked requests are not supported"}})
            return
        lengths = self.headers.get_all("Content-Length", [])
        if not lengths:
            self._send_json(411, {"error": {"message": "Content-Length required"}})
            return
        try:
            if len(lengths) != 1:
                raise ValueError()
            length = int(lengths[0])
            if length < 0:
                raise ValueError()
        except ValueError:
            self._send_json(400, {"error": {"message": "invalid Content-Length"}})
            return
        if length > MAX_BODY_BYTES:
            self._send_json(413, {"error": {"message": "request body too large"}})
            return
        try:
            body = self.rfile.read(length)
        except TimeoutError:
            self._send_json(408, {"error": {"message": "request body timed out"}})
            return
        if len(body) != length:
            self._send_json(400, {"error": {"message": "incomplete request body"}})
            return
        if self.path == "/v1/audio/speech":
            self._speech(body)
        elif self.path == "/v1/audio/voices":
            self._forward_simple(self.path, body, "POST", timeout=120)
        else:
            self._send_json(404, {"error": {"message": "not found"}})

    def do_DELETE(self):
        if self.path.startswith("/v1/audio/voices/"):
            self._forward_simple(self.path, method="DELETE")
        else:
            self._send_json(404, {"error": {"message": "not found"}})

    # -- speech ---------------------------------------------------------------
    def _speech(self, body):
        if not SYNTHESIS_SLOTS.acquire(blocking=False):
            self._send_json(429, {"error": {"message": "synthesis capacity exhausted"}})
            return
        try:
            self._stream_speech(body)
        finally:
            SYNTHESIS_SLOTS.release()

    def _stream_speech(self, body):
        try:
            payload = json.loads(body)
            if not isinstance(payload, dict):
                raise ValueError()
            text = payload.get("input")
            if not isinstance(text, str) or not text.strip() or len(text) > MAX_INPUT_CHARS:
                self._send_json(400, {"error": {"message": f"input must contain 1 to {MAX_INPUT_CHARS} characters"}})
                return
            fmt = (payload.get("response_format") or "mp3").lower()
        except Exception:
            self._send_json(400, {"error": {"message": "invalid JSON"}})
            return
        if fmt not in FFMPEG_FORMATS and fmt != "pcm":
            self._send_json(400, {"error": {"message": f"response_format '{fmt}' not supported"}})
            return
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
        expired = threading.Event()

        def expire():
            expired.set()
            interrupt_upstream(up)

        timer = threading.Timer(STREAM_TIMEOUT, expire)
        timer.daemon = True
        timer.start()

        def emit(chunk):
            nonlocal started
            if expired.is_set():
                raise TimeoutError("synthesis deadline exceeded")
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
            if expired.is_set():
                raise TimeoutError("synthesis deadline exceeded")
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
            timer.cancel()
            interrupt_upstream(up)
            up.close()

    def _transcode(self, up, fmt, emit):
        ffmpeg = subprocess.Popen(
            ["ffmpeg", "-loglevel", "error",
             "-f", "s16le", "-ar", str(SAMPLE_RATE), "-ac", "1", "-i", "pipe:0",
             *FFMPEG_FORMATS[fmt], "pipe:1"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        errors = []
        stderr = bytearray()
        timer = threading.Timer(STREAM_TIMEOUT, ffmpeg.kill)
        timer.daemon = True
        timer.start()

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
            timer.cancel()
            if ffmpeg.poll() is None:
                ffmpeg.kill()
            ffmpeg.wait()
            interrupt_upstream(up)
            up.close()
            feeder.join(timeout=10)
            drainer.join(timeout=10)
            for pipe in (ffmpeg.stdin, ffmpeg.stdout, ffmpeg.stderr):
                pipe.close()


if __name__ == "__main__":
    wait_for_backend()
    Server(("0.0.0.0", PORT), Handler).serve_forever()
