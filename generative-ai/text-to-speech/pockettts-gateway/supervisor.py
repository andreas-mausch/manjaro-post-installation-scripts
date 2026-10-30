#!/usr/bin/env python3
"""Exit when either service exits; forward container shutdown to both."""
import os
import signal
import subprocess
import sys
import time


def supervise(backend_command, gateway_command):
    children = []
    stopping = False

    def stop(signum, frame):
        nonlocal stopping
        stopping = True

    previous = {sig: signal.signal(sig, stop) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        for command in (backend_command, gateway_command):
            children.append(subprocess.Popen(command, start_new_session=True))
        while not stopping:
            if any(child.poll() is not None for child in children):
                return 1
            time.sleep(0.1)
        return 0
    finally:
        for child in children:
            try:
                # Include gateway encoder descendants in shutdown.
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 5
        for child in children:
            try:
                child.wait(timeout=max(0, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
        for sig, handler in previous.items():
            signal.signal(sig, handler)


if __name__ == "__main__":
    sys.exit(supervise(sys.argv[1:], [sys.executable, "/opt/tts/startup.py"]))
