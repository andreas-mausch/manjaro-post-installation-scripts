import io
import http.client
import json
import shutil
import subprocess
import sys
import threading
import unittest
from contextlib import contextmanager
from email.message import Message
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import mock_open, patch
from urllib.error import HTTPError

import gateway
import supervisor
import startup


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

    def test_voice_routes_proxy_backend_responses_without_files(self):
        for method, path, body, timeout in (
                ("POST", "/v1/audio/voices", b'{"name":"LUCY","wav_b64":"sample"}', 120),
                ("POST", "/v1/audio/voices", b'{"name":"other","state_b64":"state"}', 120),
                ("POST", "/v1/audio/voices", b'[]', 120),
                ("DELETE", "/v1/audio/voices/A%2FB", None, gateway.IO_TIMEOUT),
                ("GET", "/v1/audio/voices", None, gateway.IO_TIMEOUT)):
            for status in (200, 400, 404):
                with self.subTest(method=method, body=body, status=status):
                    handler = self.handler()
                    handler.path = path
                    handler.headers = Message()
                    if body is not None:
                        handler.headers["Content-Length"] = str(len(body))
                        handler.rfile = Stream(body)
                    data = b'{"backend":"response"}'
                    headers = Message()
                    headers["Content-Type"] = "application/json"
                    response = Stream(data)
                    response.status, response.headers = status, headers
                    effect = HTTPError(path, status, "rejected", headers, response) if status >= 400 else None
                    with patch("builtins.open", side_effect=AssertionError("runtime file access")):
                        with patch.object(gateway, "backend_request", return_value=response, side_effect=effect) as forward:
                            getattr(handler, "do_" + method)()
                    forward.assert_called_once_with(path, method, body, timeout=timeout)
                    self.assertEqual(handler.status, status)
                    self.assertEqual(handler.wfile.getvalue(), data)
                    self.assertEqual(handler.response_headers["Content-Type"], "application/json")
                    self.assertEqual(handler.response_headers["Content-Length"], str(len(data)))

    def test_voice_backend_unavailable_returns_502(self):
        for method in ("POST", "DELETE", "GET"):
            handler = self.handler()
            handler.path = "/v1/audio/voices" + ("/lucy" if method == "DELETE" else "")
            handler.headers = Message()
            handler.headers["Content-Length"] = "2"
            handler.rfile = Stream(b'{}')
            with patch.object(gateway, "backend_request", side_effect=OSError("offline")) as forward:
                getattr(handler, "do_" + method)()
            self.assertEqual(handler.error[0], 502)
            self.assertEqual(forward.call_count, 1)

    def test_gateway_readiness_has_no_reference_initialization(self):
        with patch.object(gateway, "backend_request", return_value=Stream(b'{}')) as backend:
            with patch("builtins.open", side_effect=AssertionError("unexpected file access")):
                gateway.wait_for_backend()
        backend.assert_called_once_with("/v1/models", timeout=2)

    def test_startup_registers_reference_before_exec(self):
        with patch.dict(startup.os.environ, {"PKTTS_SERVER_VOICE": "lucy", "PKTTS_REF_WAV": __file__}):
            with patch.object(startup.urllib.request, "urlopen", side_effect=[Stream(b'{}'), Stream()]) as backend:
                with patch("builtins.open", mock_open(read_data=b"reference")) as reference:
                    with patch.object(startup.os, "execv") as execute:
                        startup.bootstrap()
                        self.assertTrue(backend.call_args.args[0].data)
                reference.assert_called_once_with(__file__, "rb")
                request = backend.call_args.args[0]
                self.assertEqual(request.full_url, "http://127.0.0.1:8085/v1/audio/voices")
                self.assertEqual(json.loads(request.data), {"name": "lucy", "wav_b64": "cmVmZXJlbmNl"})
                self.assertEqual(backend.call_args.kwargs, {"timeout": 120})
                execute.assert_called_once_with(sys.executable, [sys.executable, "/opt/tts/gateway.py"])

    def test_startup_without_reference_execs_without_backend_or_files(self):
        with patch.dict(startup.os.environ, {"PKTTS_REF_WAV": ""}):
            with patch.object(startup.urllib.request, "urlopen") as backend:
                with patch("builtins.open", side_effect=AssertionError("unexpected file access")):
                    with patch.object(startup.os, "execv") as execute:
                        startup.bootstrap()
                backend.assert_not_called()
                execute.assert_called_once()

    def test_startup_registration_failure_does_not_launch_gateway(self):
        with patch.dict(startup.os.environ, {"PKTTS_SERVER_VOICE": "lucy", "PKTTS_REF_WAV": __file__}):
            with patch.object(startup.urllib.request, "urlopen", side_effect=[Stream(b'{}'), OSError("offline")]):
                with patch("builtins.open", mock_open(read_data=b"reference")):
                    with patch.object(startup.os, "execv") as execute:
                        with self.assertRaises(OSError):
                            startup.bootstrap()
                execute.assert_not_called()

    def test_speech_leaves_voice_absent_or_unchanged(self):
        for fields in ({}, {"voice": "VeRA"}, {"voice": ""}, {"voice": None}, {"voice": 42}):
            payload = {"input": "test", "response_format": "pcm", **fields}
            with patch.object(gateway, "backend_request", return_value=Stream(b'pcm')) as backend:
                self.handler()._speech(json.dumps(payload).encode())
            self.assertEqual(json.loads(backend.call_args.args[2]), payload)

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
        handler.response_headers = {}
        handler.send_response = lambda status: setattr(handler, "status", status)
        handler.send_header = lambda key, value: handler.response_headers.update({key: value})
        handler.end_headers = lambda: None
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
        for fmt in gateway.CONTENT_TYPES:
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
