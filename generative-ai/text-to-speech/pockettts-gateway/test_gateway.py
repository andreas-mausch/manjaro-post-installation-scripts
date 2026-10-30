import io
import http.client
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from contextlib import contextmanager
from email.message import Message
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch

import gateway
import supervisor


class Stream(io.BytesIO):
    def read1(self, size=-1):
        return self.read(size)


class BrokenStream(Stream):
    def read1(self, size=-1):
        raise OSError("injected upstream failure")


class GatewayTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg required")
    def test_disconnect_reaps_encoder_and_closes_upstream(self):
        processes = []
        popen = subprocess.Popen

        def spawn(*args, **kwargs):
            process = popen(*args, **kwargs)
            processes.append(process)
            return process

        def disconnect(chunk):
            raise BrokenPipeError("injected client disconnect")

        upstream = Stream(b"\0" * 480000)
        with patch.object(gateway.subprocess, "Popen", side_effect=spawn):
            with self.assertRaises(BrokenPipeError):
                self.handler()._transcode(upstream, "opus", disconnect)
        self.assertTrue(upstream.closed)
        self.assertIsNotNone(processes[0].poll())
        self.assertTrue(all(pipe.closed for pipe in (processes[0].stdin, processes[0].stdout, processes[0].stderr)))

    @contextmanager
    def serving(self, handler, server_class=ThreadingHTTPServer):
        server = server_class(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            yield server
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg required")
    def test_real_http_streams_before_generation_finishes_and_detects_truncation(self):
        release = threading.Event()
        complete = threading.Event()
        fail = threading.Event()

        class Backend(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *args):
                pass

            def do_POST(self):
                self.rfile.read(int(self.headers["Content-Length"]))
                self.send_response(200)
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                data = b"\0" * 480000
                self.wfile.write(f"{len(data):X}\r\n".encode() + data + b"\r\n")
                self.wfile.flush()
                release.wait(10)
                complete.set()
                if not fail.is_set():
                    self.wfile.write(b"0\r\n\r\n")
                self.close_connection = True

        with self.serving(Backend) as upstream:
            with patch.object(gateway, "BACKEND", f"http://127.0.0.1:{upstream.server_port}"):
                with self.serving(gateway.Handler, gateway.Server) as server:
                    for fmt, broken, timed in (("mp3", False, False), ("opus", False, False),
                                              ("wav", False, False), ("pcm", False, False),
                                              ("mp3", True, False), ("pcm", False, True),
                                              ("mp3", False, True)):
                        with self.subTest(fmt=fmt, broken=broken, timed=timed):
                            release.clear()
                            complete.clear()
                            fail.set() if broken else fail.clear()
                            connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
                            try:
                                with patch.object(gateway, "STREAM_TIMEOUT", 0.2 if timed else 180):
                                    connection.request("POST", "/v1/audio/speech", json.dumps({"input": "test", "response_format": fmt}))
                                    response = connection.getresponse()
                                    self.assertEqual(response.status, 200)
                                    self.assertTrue(response.read1(100))
                                    self.assertFalse(complete.is_set(), "stream buffered until generation completed")
                                    if not timed:
                                        release.set()
                                    if broken or timed:
                                        with self.assertRaises(http.client.IncompleteRead):
                                            response.read()
                                    else:
                                        self.assertTrue(response.read())
                            finally:
                                release.set()
                                connection.close()
                                self.assertTrue(complete.wait(2), "mock generation did not finish")

    def test_request_limits_and_busy_capacity(self):
        handler = self.handler()
        handler.path = "/v1/audio/speech"
        for length, expected in (("-1", 400), ("invalid", 400), (str(gateway.MAX_BODY_BYTES + 1), 413)):
            handler.headers = Message()
            handler.headers["Content-Length"] = length
            handler.do_POST()
            self.assertEqual(handler.error[0], expected)
        for payload in ([], {"input": ""}, {"input": "x" * (gateway.MAX_INPUT_CHARS + 1)}):
            handler._speech(json.dumps(payload).encode())
            self.assertEqual(handler.error[0], 400)
        with patch.object(gateway, "SYNTHESIS_SLOTS", threading.BoundedSemaphore(1)):
            gateway.SYNTHESIS_SLOTS.acquire()
            handler._speech(b'{"input":"test"}')
            self.assertEqual(handler.error[0], 429)
            gateway.SYNTHESIS_SLOTS.release()
            handler._speech(b'[]')
            self.assertTrue(gateway.SYNTHESIS_SLOTS.acquire(blocking=False))

    def test_connection_capacity_returns_429(self):
        with self.serving(gateway.Handler, gateway.Server) as server:
            for _ in range(gateway.MAX_CONNECTIONS):
                server.slots.acquire()
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=2)
            try:
                connection.request("GET", "/health")
                self.assertEqual(connection.getresponse().status, 429)
            finally:
                connection.close()
                for _ in range(gateway.MAX_CONNECTIONS):
                    server.slots.release()

    def test_concurrent_registration_keeps_complete_json(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(gateway, "STATE_DIR", directory):
                with patch.object(gateway, "backend_request", side_effect=lambda *a, **k: Stream()):
                    threads = [threading.Thread(target=gateway.register_voice,
                               args=("lucy", {"name": "lucy", "wav_b64": str(i) * 1000}))
                               for i in range(8)]
                    for thread in threads:
                        thread.start()
                    for thread in threads:
                        thread.join()
                self.assertEqual(len(os.listdir(directory)), 1)
                with open(gateway.voice_path("lucy")) as file:
                    self.assertEqual(len(json.load(file)["wav_b64"]), 1000)

    def test_voice_filenames_and_atomic_updates(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(gateway, "STATE_DIR", directory):
                with patch.object(gateway, "backend_request", side_effect=lambda *a, **k: Stream()):
                    for name in ("a/b", "a_b", "LUCY", "lucy"):
                        gateway.register_voice(name, {"name": name, "wav_b64": name})
                self.assertEqual(len(os.listdir(directory)), 3)
                with open(gateway.voice_path("LUCY")) as file:
                    self.assertEqual(json.load(file), {"name": "lucy", "wav_b64": "lucy"})
                with patch.object(gateway, "backend_request", side_effect=OSError("offline")):
                    with self.assertRaises(OSError):
                        gateway.register_voice("lucy", {"name": "lucy"})
                self.assertTrue(os.path.exists(gateway.voice_path("lucy")))

    def test_delete_only_removes_state_after_backend_success(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(gateway, "STATE_DIR", directory):
                with patch.object(gateway, "backend_request", return_value=Stream()):
                    gateway.register_voice("A/B", {"name": "A/B"})
                handler = self.handler()
                handler.path = "/v1/audio/voices/A%2FB"
                with patch.object(handler, "_forward_simple", return_value=500):
                    handler.do_DELETE()
                self.assertTrue(os.path.exists(gateway.voice_path("a/b")))
                with patch.object(handler, "_forward_simple", return_value=200) as forward:
                    handler.do_DELETE()
                forward.assert_called_once_with("/v1/audio/voices/a%2Fb", method="DELETE")
                self.assertFalse(os.path.exists(gateway.voice_path("a/b")))

    def test_default_voice_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.multiple(gateway, STATE_DIR=directory, DEFAULT_VOICE="lucy", REF_WAV=__file__):
                for listing in (b'{"voices":[{"name":"lucy"}]}', b'{"voices":["lucy"]}', b'{}'):
                    with patch.object(gateway, "backend_request", side_effect=[Stream(b"{}"), Stream(listing)]):
                        with patch.object(gateway, "register_voice") as register:
                            gateway.startup_voices()
                            register.assert_not_called()

    def test_missing_default_voice_is_registered(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.multiple(gateway, STATE_DIR=directory, DEFAULT_VOICE="lucy", REF_WAV=__file__):
                with patch.object(gateway, "backend_request", side_effect=[Stream(b"{}"), Stream(b'{"voices":[]}')]):
                    with patch.object(gateway, "register_voice") as register:
                        gateway.startup_voices()
                        self.assertEqual(register.call_args.args[0], "lucy")

    def test_supervisor_exits_on_either_child_failure(self):
        for commands in (("raise SystemExit(0)", "import time; time.sleep(60)"),
                         ("import time; time.sleep(60)", "raise SystemExit(2)")):
            self.assertEqual(supervisor.supervise(
                [sys.executable, "-c", commands[0]],
                [sys.executable, "-c", commands[1]]), 1)

    def test_health_depends_on_backend(self):
        handler = self.handler()
        handler.path = "/health"
        with patch.object(gateway, "backend_request", side_effect=OSError("offline")):
            handler.do_GET()
        self.assertEqual(handler.error[0], 503)
        with patch.object(gateway, "backend_request", return_value=Stream(b'{"data":[]}')):
            handler.do_GET()
        self.assertEqual(handler.error[0], 200)

    def handler(self):
        handler = object.__new__(gateway.Handler)
        handler.close_connection = False
        handler.wfile = io.BytesIO()
        handler._begin_chunked = lambda *args: None
        handler._send_json = lambda status, body: setattr(handler, "error", (status, body))
        return handler

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg required")
    def test_upstream_failure_is_not_success(self):
        handler = self.handler()
        with patch.object(gateway, "backend_request", return_value=BrokenStream()):
            handler._speech(b'{"input":"test","response_format":"mp3"}')
        self.assertFalse(handler.wfile.getvalue().endswith(b"0\r\n\r\n"))
        self.assertTrue(handler.close_connection or handler.error[0] == 502)

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg required")
    def test_encoder_failure_is_not_success(self):
        handler = self.handler()
        with patch.dict(gateway.FFMPEG_FORMATS, {"mp3": ["-c:a", "missing_encoder", "-f", "mp3"]}):
            with patch.object(gateway, "backend_request", return_value=Stream(b"\0" * 48000)):
                handler._speech(b'{"input":"test","response_format":"mp3"}')
        self.assertEqual(handler.error[0], 502)
        self.assertIn("ffmpeg exited", handler.error[1]["error"]["message"])

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg required")
    def test_successful_formats(self):
        for fmt in ("mp3", "opus", "wav"):
            with self.subTest(fmt=fmt):
                handler = self.handler()
                with patch.object(gateway, "backend_request", return_value=Stream(b"\0" * 48000)):
                    handler._speech(json.dumps({"input": "test", "response_format": fmt}).encode())
                self.assertTrue(handler.wfile.getvalue().endswith(b"0\r\n\r\n"))
                self.assertFalse(handler.close_connection)

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg required")
    def test_wav_has_deliberate_unknown_lengths(self):
        chunks = []
        self.handler()._transcode(Stream(b"\0" * 48000), "wav", chunks.append)
        wav = b"".join(chunks)
        self.assertEqual(wav[:8], b"RIFF\xff\xff\xff\xff")
        offset = wav.index(b"data")
        self.assertEqual(wav[offset + 4:offset + 8], b"\xff" * 4)
        self.assertEqual(len(wav[offset + 8:]), 48000)


if __name__ == "__main__":
    unittest.main()
