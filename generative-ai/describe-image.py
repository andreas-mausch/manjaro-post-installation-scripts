#!/usr/bin/env python3
"""Ask a gufo-hosted vision model to describe an image.

Usage:
    ./describe-image.py PATH_TO_IMAGE [--prompt "..."] [--model NAME] [--url URL]

Defaults target the local Qwen3.8 Flash Next server on http://127.0.0.1:8080.
"""
import argparse
import base64
import json
import mimetypes
import sys
import urllib.error
import urllib.request


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("image", help="path to the image file to describe")
    parser.add_argument("--prompt", default="Was ist auf dem Bild zu sehen?")
    parser.add_argument("--model", default="Qwen3.8 Flash Next")
    parser.add_argument("--url", default="http://127.0.0.1:8080/v1/chat/completions")
    parser.add_argument("--max-tokens", type=int, default=8000)
    args = parser.parse_args()

    mime = mimetypes.guess_type(args.image)[0] or "application/octet-stream"
    with open(args.image, "rb") as f:
        image = base64.b64encode(f.read()).decode()

    body = {
        "model": args.model,
        "temperature": 0,
        "max_tokens": args.max_tokens,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{image}"}},
                    {"type": "text", "text": args.prompt},
                ],
            }
        ],
    }

    request = urllib.request.Request(
        args.url,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request) as response:
            data = json.loads(response.read().decode())
    except urllib.error.URLError as exc:
        print(f"request failed: {exc}", file=sys.stderr)
        return 1

    message = data["choices"][0]["message"]
    if message.get("reasoning_content"):
        print("— reasoning —\n" + message["reasoning_content"] + "\n")
    print(message.get("content", ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
