import io
import json
import os
import shutil
import sys
import tempfile
import threading
import unittest
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
            handler._speech(b'{"response_format":"mp3"}')
        self.assertFalse(handler.wfile.getvalue().endswith(b"0\r\n\r\n"))
        self.assertTrue(handler.close_connection or handler.error[0] == 502)

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg required")
    def test_encoder_failure_is_not_success(self):
        handler = self.handler()
        with patch.dict(gateway.FFMPEG_FORMATS, {"mp3": ["-c:a", "missing_encoder", "-f", "mp3"]}):
            with patch.object(gateway, "backend_request", return_value=Stream(b"\0" * 48000)):
                handler._speech(b'{"response_format":"mp3"}')
        self.assertEqual(handler.error[0], 502)
        self.assertIn("ffmpeg exited", handler.error[1]["error"]["message"])

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg required")
    def test_successful_formats(self):
        for fmt in ("mp3", "opus", "wav"):
            with self.subTest(fmt=fmt):
                handler = self.handler()
                with patch.object(gateway, "backend_request", return_value=Stream(b"\0" * 48000)):
                    handler._speech(json.dumps({"response_format": fmt}).encode())
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
