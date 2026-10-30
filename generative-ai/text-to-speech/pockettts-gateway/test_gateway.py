import io
import json
import shutil
import unittest
from unittest.mock import patch

import gateway


class Stream(io.BytesIO):
    def read1(self, size=-1):
        return self.read(size)


class BrokenStream(Stream):
    def read1(self, size=-1):
        raise OSError("injected upstream failure")


class GatewayTests(unittest.TestCase):
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
