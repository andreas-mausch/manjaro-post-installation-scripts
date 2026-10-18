import base64, json, urllib.request
image = base64.b64encode(open("/home/neonew/Pictures/Screenshots/Picture.jpg", "rb").read()).decode()
body = {"model": "Qwen3.8 Flash Next", "temperature": 0, "max_tokens": 8000,
        "messages": [{"role": "user", "content": [
            {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + image}},
            {"type": "text", "text": "Was ist auf dem Bild zu sehen?"}]}]}
request = urllib.request.Request("http://127.0.0.1:8080/v1/chat/completions",
    data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
print(urllib.request.urlopen(request).read().decode())
