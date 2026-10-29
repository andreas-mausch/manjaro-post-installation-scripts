Ich habe heute verschiedene Modelle angeguckt und getestet.

# Anforderungen

- Sprache: Deutsch wird unterstützt (und optional Englisch)
- Voice Cloning möglich (mit sample.txt oder ohne)
- deutlich schneller als Real-Time: Faktor 5-10x wünschenswert
- Optional: Emotion Tags werden unterstützt

# Getestet und lauffähig

## Qwen3-TTS (Base, mit Clone Voice) -> langsam

<https://github.com/groxaxo/Qwen3-TTS-Openai-Fastapi.git>

git commit hash: `783bf0e51596f1eb1e70124258f0e1ea4bf3b40a`

Lief super!

```bash
git clone https://github.com/groxaxo/Qwen3-TTS-Openai-Fastapi.git
cd Qwen3-TTS-Openai-Fastapi/
python3 -m venv .venv
source .venv/bin/activate.fish
python -m pip install --upgrade pip
pip install -e ".[api]"
```

Zum Starten:

```bash
TTS_MODEL_NAME=Qwen/Qwen3-TTS-12Hz-0.6B-Base python -m api.main
```

Ich habe über die WebUI einfach den Clone Voice Modus ausprobiert:
.wav sample hochgeladen, Text eingegeben, der im Sample zu hören ist.
Und danach Text eingegeben, der generiert werden soll, auf generieren geklickt:
Hat auf Anhieb gut geklappt.

Ich hatte zuerst das 1.7B Model getestet, das war mir aber etwas zu langsam.
0.6B klang für mich auch noch gut genug, war aber immer noch etwas langsam.

Das Repo hat alles dabei: WebUI, API, Docs. Wirkt sehr gut.

Was nicht geklappt hat:
Tags wie `[serious]` oder `[excited]`, siehe hier:
<https://www.qwen3tts.net/qwen3-tts-prompt-guide>

## Pocket TTS

Demo: <https://huggingface.co/spaces/KevinAHM/pocket-tts-web>

Das habe ich mit audio.cpp probiert, weil es dort besonders schnell laufen soll.

```bash
python tools/model_manager_v2.py list
python tools/model_manager_v2.py install pocket_tts_german_q8_0 --models-root=./models/
```

```bash
./audiocpp_cli \
  --task tts \
  --family pocket_tts \
  --model ./models/PocketTTS-GGUF/german \
  --backend cpu \
  --load-option "language=german" \
  --text "Hallo, sag mal etwas zu mir." \
  --voice-ref ../sample.wav \
  --out output.wav
```

Sehr schnell, aber spricht manchmal schnell und klingt dadurch etwas komisch / verzerrt.
Würde mir aber ausreichen für Lucy in XMPP.

Docker:

```bash
docker run --rm --device /dev/dri \
  -p 8080:8080 \
  --group-add "$(getent group render | cut -d: -f3)" \
  --group-add "$(getent group video | cut -d: -f3)" \
  -v "./models:/models:ro" \
  ghcr.io/0xshug0/audio.cpp:full-cpu \
  server --ui --ui-management --host 0.0.0.0 --port 8080 --backend cpu --model /models/PocketTTS-GGUF/german
```

Komisch: Ich kann Pocket-TTS nicht in der WebUI auswählen, aber über die CLI funktioniert es gut.
Offen: Geht es über die API mit Hermes?

Obacht: audio.cpp bietet nur Generierung von WAV an, kein MP3 oder OGG. (Obwohl, MP3 geht wohl mit Options?)

Deswegen: Nutzung von LocalAI, was eine OpenAI API anbietet, die opus, mp3 etc. anbietet.

# Ungeeignet

## Kokoro

Kann kein Voice Cloning (?)

## ~~Chatterbox / Chatterbox-Turbo~~

```bash
python tools/model_manager_v2.py list
python tools/model_manager_v2.py install chatterbox_q8_0 --models-root=./models/
```

```bash
./audiocpp_cli \
  --task tts \
  --family chatterbox \
  --model ./models/Chatterbox-GGUF \
  --backend cpu \
  --language de \
  --text "Hallo, sag mal etwas zu mir." \
  --voice-ref ../sample.wav \
  --out output.wav
```

Standard-Chatterbox ist mir zu langsam, ähnlich wie Qwen3-TTS.
Klingt sehr gut aber.

Es gibt aber auch Chatterbox-Turbo: Da kann das 350M Model allerdings nur englisch,
es gibt aber auch 500M Chatterbox-multilingual. Ich weiß nur nicht, ob es mit audio.cpp funktioniert.

> Chatterbox Turbo does not support custom voice cloning (only the built-in default voice)

Damit ist es raus.

# Ungetestet

## Omnivoice

## KittenTTS

## F5 TTS

Habe ich auf reddit gelesen, dass es gut und schnell sein soll.
Habe ich aber nicht getestet.
