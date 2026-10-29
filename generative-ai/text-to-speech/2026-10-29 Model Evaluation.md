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

### Benchmark: PocketTTS german vs. german_24l (LocalAI, CPU)

Getestet am 2026-10-29: Wie viel langsamer ist das größere deutsche 24-Layer-Modell
(`german_24l`) gegenüber dem eingesetzten `german`-Checkpoint?

Setup: LocalAI v4.12.1, CPU-Backend (wie im Hermes-Stack), zwei Server parallel —
`german` auf 8081 (laufender `localai`-Dienst), `german_24l` in einem Wegwerf-Container
auf 8082 mit Modell-YAML `language:german_24l` und den Gewichten aus
`/srv/llama/models/pocket-tts/german_24l`. Jeweils 1 Warmup + 3 Messläufe, alternierend,
gleicher Text, gemessen mit `curl` `time_total` (inkl. HTTP-Overhead).

Satz 1 („Hallo, das ist ein Test der deutschen Sprachausgabe. Heute probiere ich ein
groesseres Modell aus und schaue, wie viel Zeit das kostet."):

| Modell | API-Zeit (Ø) | Audio (Ø) | Rechenzeit pro Sekunde Audio |
|---|---|---|---|
| german | 2,49 s | 7,81 s | ~0,32 s (~3x schneller als Realtime) |
| german_24l | 9,84 s | 9,04 s | ~1,09 s (unter Realtime) |

Satz 2 („Es ist 13:05. Die Items werden mit Sprites gerendered. Tschüß."):

| Modell | API-Zeit (Ø) | Audio (Ø) | Rechenzeit pro Sekunde Audio |
|---|---|---|---|
| german | 2,21 s | 6,56 s | ~0,34 s (~3x schneller als Realtime) |
| german_24l | 8,52 s | 7,76 s | ~1,10 s (unter Realtime) |

Ergebnis: `german_24l` ist ~4x langsamer (pro Sekunde Audio ~3,4–3,9x) und erreicht auf
der CPU nicht einmal Realtime-Tempo. Damit verletzt es die Anforderung „5–10x schneller
als Realtime" deutlich; das aktuelle `german` bleibt die Wahl für Lucy/XMPP.
zusätzlich spricht `german_24l` denselben Text langsamer (längere Audioausgabe).
Audioqualität wurde nicht bewertet, nur Geschwindigkeit.

Setup-Hinweise:

- Das `pocket_tts`-Paket (v4.0.1) im LocalAI-Backend unterstützt `german_24l` nativ als
  `language`-Option. Wichtig: `language:german` mit den 24l-Gewichten zu mounten schlägt
  fehl (state_dict: Unexpected keys `flow_lm.transformer.layers.6..23`), die Architektur-
  konfiguration kommt aus der Sprach-Config des Backends.
- Benötigte Bind-Mounts (analog zum bestehenden `german`-Setup in `../hermes/compose.yaml`):
  - `model.safetensors` -> `/models/huggingface/hub/models--kyutai--pocket-tts/snapshots/2dd944b099d06bb9edbd221fef138685711d9bf0/languages/german_24l/model.safetensors`
  - `tokenizer.json` -> `/models/huggingface/hub/models--kyutai--pocket-tts-without-voice-cloning/snapshots/4e1e0a3e611c51c0b4ed8174fc10f32a54644303/languages/german_24l/tokenizer.json`
- Caveats: Einzelner Rechner, nur je 3 Messungen, CPU-Backend setzt selbst 1 Intraop-Thread
  (siehe LocalAI.md).

## pockettts.cpp (GGUF, Vulkan)

<https://github.com/ServeurpersoCom/pockettts.cpp> — C++17-Port von Pocket TTS auf ggml,
mit CPU/CUDA/Metal/Vulkan-Backend und zwei Tools: `pocket-tts` (Text -> WAV) und
`tts-server` (OpenAI-kompatible HTTP-API).

Build (Arch/Manjaro): `git clone --recurse-submodules` + `./buildvulkan.sh`; benötigt
`vulkan-headers`, `spirv-headers`, `glslang`, `spirv-tools` (hier schon installiert).
Strix-Halo-iGPU wird von RADV sauber erkannt (Vulkan 1.4, coopmat-Matrix-Cores).
Getestet am 2026-10-29 mit `pocket-tts-german_24l-Q8_0.gguf` aus
`/srv/llama/models/pocket-tts/Serveurperso-GGUF/` und Klone-Stimme `sample.wav`:

```bash
echo "Testtext" | ./build/pocket-tts \
  --model /srv/llama/models/pocket-tts/Serveurperso-GGUF/pocket-tts-german_24l-Q8_0.gguf \
  --voice sample.wav --device Vulkan0 -o out.wav
```

Messwerte (gleiche Sätze wie beim LocalAI-Benchmark; `[TTS]`-Zeilen des Tools = Synthese
ohne Modell-Ladung (~0,4 s) und Voice-Encoding (~0,6 s), die der CLI pro Prozess separat
ausweist):

| Backend | Satz 1 (Ø) | Satz 2 (Ø) | Tempo |
|---|---|---|---|
| LocalAI CPU, german (Referenz) | 2,49 s | 2,21 s | ~3x Realtime |
| LocalAI CPU, german_24l (Referenz) | 9,84 s | 8,52 s | ~0,9x (unter Realtime) |
| pockettts.cpp, CPU | 1,84 s | 1,97 s | 4,5–4,7x, sehr stabil |
| pockettts.cpp, Vulkan0 | 0,58–1,14 s | 1,29–1,54 s | 5,5–12x, volatil (Bursts bis 17x) |
| tts-server, Vulkan0, via HTTP | — | ~1,23 s | ~6,6x |

Erkenntnisse:

- **24l wird dadurch nutzbar:** schon der reine CPU-Build macht `german_24l` ~4,6x
  schneller als Realtime und ist damit sogar schneller als LocalAI mit dem kleinen
  `german`-Checkpoint. Gründe: alle CPU-Kerne + Q8_0-Quantisierung statt 1 Intraop-Thread
  + f32 im Python-Backend. Auf Vulkan (~6,6x) ist die 5–10x-Anforderung erfüllt.
- Vulkan-Taktvolatilität: Zahlen streuen stark (sustained ~6–7x, Bursts 12–17x); nicht
  thermisch (Tctl ~53 °C), vermutlich Taktstufen des APU. Für belastbare Zahlen länger
  messen.
- `tts-server` ist OpenAI-kompatibel: `POST /v1/audio/speech` (`input`, `voice`,
  `response_format`, `seed`, `temperature`), `GET/POST/DELETE /v1/audio/voices` —
  Voice-Cloning funktioniert über `POST /v1/audio/voices` mit base64-WAV (bei großen
  Dateien via `curl --data @datei`, sonst „Argument list too long").
- Einschränkungen ggü. LocalAI: nur `response_format` `wav`/`pcm` (kein Opus/OGG/MP3 —
  damals Hauptgrund für LocalAI), registrierte Stimmen sind nach Neustart weg, ein Modell
  pro Prozess. `pcm` streamt s16le während der Generierung (praktisch für Live-Ausgabe).

Fazit: Speed-Technik wäre gegeben; Audioqualität 24l-Q8 vs. german-f32 und eine
Opus-Konvertierungsstrategie sind noch offen.

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
