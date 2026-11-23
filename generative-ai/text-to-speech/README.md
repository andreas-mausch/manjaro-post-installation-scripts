# Text-to-Speech (Pocket-TTS / Qwen3-TTS)

Seit **23.11.2026** produktiv: **Qwen3-TTS 12Hz 1.7B Base** (lucy-Klon) als
Compose-Stack [`compose.yaml`](compose.yaml) — audio.cpp `audiocpp_server`
(Vulkan) + [`tts-gateway/`](tts-gateway/README.md)-Proxy (OpenAI-API +
mp3/opus-Streaming-Transcode, Host-Port 8081).
Grund: bestes Deutsch aller Tests (Ziffern einwandfrei), ~2× Realtime im
Systemsstillstand — der 5–10×-Punkt wurde bewusst gegen Qualität getauscht.
Ausführliche Findings **und Setup**:
[Model Evaluation Details](Model%20Evaluation%20Details.md#audiocpp-als-qwen3-tts-server-produktiv-schicht-23112026).
Dieses Dokument bündelt am 22.11.2026 vier Datums-Notizen (Originalfassung: Git-Log).

# Startup

```bash
docker compose up -d                   # beide Dienste: audio-cpp-Backend + Gateway
docker compose logs -f gateway         # "[gateway] ready" abwarten
```

# Anforderungen

- Sprache: Deutsch wird unterstützt (und optional Englisch)
- Voice Cloning möglich (aufgrund einer sample.wav, mit sample.txt oder ohne)
- deutlich schneller als Real-Time: Faktor 5-10x wünschenswert
- Optional: Emotion Tags werden unterstützt
- Optional: Support für unterschiedliche Sprecher
- OpenAI API
- [api]: Support für Streaming
- Optional [api]: Output als .wav, .ogg oder .mp3

# Getestete Modelle

Realtime-Faktoren: End-to-End auf Ryzen AI Max 395+ (iGPU Vulkan bzw. CPU),
Testtext „Es ist 13:05. Die Items werden mit Sprites gerendered. Tschüß.“;
Messmethoden in [Details](Model%20Evaluation%20Details.md#geschwindigkeits-benchmarks).
Spalten: ✓ = ja, ✗ = nein, — = nicht geprüft.
„Englisch“ = englische Wörter im deutschen Testtext („Sprites“, „gerendered“).
„Streaming“ = die API liefert Audio während der Generierung aus (HTTP-chunked),
ohne auf die vollständige Synthese zu warten.
„Mehrere Speaker“ = mehrere Stimmen in **einem** Request (Dialog-Modus), nicht
blöß „verschiedene Stimmen pro Request möglich“. Das erfüllt keine getestete
Kombination: jeder Läufer bekommt genau eine Stimme pro Request
(`voice` / `--voice-ref` / `--ref-wav`).

| Modell | Runtime | Release-Date | Größe (MB) | Quantisierung | Realtime-Faktor | Streaming | Voice Cloning | Deutsch | Englisch | Emotion-Tags | Mehrere Speaker |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Qwen3-TTS 1.7B Base (audio.cpp) ✅ in Produktion (23.11.)** | audio.cpp `full-vulkan-20261123-f79c880`, [`compose.yaml`](compose.yaml) (Dienste `audio-cpp` + `gateway`) | — | 2695 | Q8_0_v2 (offizielles GGUF) | ~2–2,3× (Systemsstillstand) / ~1× (LLM-Volllast) | ✓ | ✓ | ✓⁷ | — | ✗⁴ | ✗ |
| Qwen3-TTS 1.7B Base (gufo) | gufo-runtime `0.35.0`, `serve tts`, GPU (HIP) + Gateway-Proxy (Script entfernt 23.11., Git-Geschichte) | — | 3860 | bf16 | ~1,7× gemessen | ✓ | ✓ | ✓⁷ | — | ✗⁴ | ✗ |
| **Pocket-TTS `german_24l` (April, `e041936c`) ✓ Fallback** | `pockettts.cpp fab7972` + `onset-keep-first-frame.patch`, Vulkan0, via Gateway (alter Dienst, Git-Geschichte) | 2026-04 | 379 | Q8_0 (eigenkonvertiert) | ~5,5–6,6× (CPU 4,5–4,7×) | ✓ (immer chunked; wav/pcm/mp3/opus/aac/flac; TTFB 0,02–0,28 s) | ✓ | ✓ | ✓ | — | ✗ |
| Pocket-TTS `german_24l` (April, `e041936c`) | ONNX-Export der KevinAHM-Demo, onnxruntime (Ryzen 7 PRO 7840U) | 2026-04 | — | INT8 | — | — | — | ✓ | ✓ | — | ✗ |
| ~~Pocket-TTS `german` 6l (April)~~ | `pockettts.cpp fab7972`, Vulkan0 | 2026-04 | 138 | Q8_0 (eigenkonvertiert) | ~11× (sustain ~9×) | ✓ (tts-server: pcm/wav) | ✓ | ✓¹ | ✗ | — | ✗ |
| ~~Pocket-TTS `german` 6l (09/2026)~~ | `pockettts.cpp fab7972`, Vulkan0 | 2026-09 | 138 | Q8_0 (Serveurperso) | ~12× (sustain ~9×) | ✓ (tts-server: pcm/wav) | ✓ | ✓¹ | ✗ | — | ✗ |
| ~~Pocket-TTS `german_24l` (Checkpoint 10/2026)~~ | LocalAI v4.12.1 (Backend `pocket_tts` 4.0.1), CPU | 2026-09 | — | f32 | ~0,9–1,1× | — (nicht gemessen) | ✓ | ✗² | ✗ | — | ✗ |
| Pocket-TTS `german` 6l (Stand Okt 2026) | audio.cpp `ghcr.io/0xshug0/audio.cpp:full-cpu` | — | — | Q8_0 | — („sehr schnell“, ungemessen) | — (nur WAV-Datei; Server ungetestet) | ✓ | — | — | — | ✗ |
| ~~OmniVoice `omnivoice-base`~~ | `omnivoice.cpp 1a468d8`, Vulkan0 | — | 626 + 276 (Codec) | Q8_0 | 0,95× (32 Schritte) / 2,8× (8) | — (tts-server vorhanden, ungemessen) | ✓³ | ✓ | ✗ | — | ✗ |
| ~~Qwen3-TTS 0.6B Base~~ | `groxaxo/Qwen3-TTS-OpenAI-Fastapi` @ `e17c1c9`, Python-venv, CPU bf16 | — | 1829 | bf16 | ~0,9× gemessen (fp32 nur ~0,27×) | — | ✓ | ✓ | — | ✗⁴ | ✗ |
| ~~Qwen3-TTS 1.7B Base~~ | wie oben, CPU bf16 | — | 3860 | bf16 | ~0,7× gemessen | — | ✓ | ✓⁷ | — | ✗⁴ | ✗ |
| ~~Qwen3-TTS 1.7B CustomVoice~~ | wie oben, CPU bf16 | — | 3840 | bf16 | ~0,8× gemessen | — | ✗ (nur 9 Preset-Stimmen) | ✓⁵ | ✓ | ✓⁶ | ✗ |
| ~~Chatterbox~~ | audio.cpp `full-cpu`, `chatterbox_q8_0` | — | — | Q8_0 | ungemessen („zu langsam“) | — | ✓ | ✓ | — | — | ✗ |
| ~~Chatterbox-Turbo~~ | nicht gelaufen (per Release-Notes raus) | — | — | — | — | — | ✗ | nur Englisch (350M) | — | ✗ | ✗ |
| ~~Kokoro~~ | nicht getestet | — | — | — | — | — | ✗ (vermutlich) | — | — | — | — |

¹ Deutsch insgesamt okay, aber Ziffern („13:05“) und englische Begriffe schlecht.
² Ziffern unverständlich, englische Wörter eingedeutscht (Hörurteil 29./30.10.2026).
³ Voice Cloning nur **mit Pflicht-Transkript** der Referenz (`--ref-text`).
⁴ Inline-Tags wie `[serious]`/`[excited]` sind keine Steuerelement; Base- und alle
  0.6B-Modelle haben gar keine Emotionssteuerung (Code ignoriert `instruct` hart).
⁵ Offizielles German-WER 1,06 (1.7B-CustomVoice), aber **keine Muttersprachler-Stimme**
  dabei (9 Presets: Ch/Beijing/Sichuan/En/Ja/Ko) — Hörtest offen.
⁶ Keine eckigen Tags, sondern natürlichsprachliche Anweisung im API-Feld `instruct`
  (nur 1.7B-CustomVoice und VoiceDesign).
⁷ Mit deaktivierter Runtime-Normalisierung (`normalize:false`) und „gerendert“ statt
  „gerendered“: **bestes Deutsch aller Tests** (Hörurteil 23.11.2026) — die
  Normalisierung des Runtimes spricht englisch und muss aus.

**Anmerkungen (Hörurteile und Entscheidungsgründe):**

- **Pocket-TTS 24l April — die Wahl.** Bestes Qualitäts-/Tempo-Verhältnis; Ziffern und
  englische Begriffe okay. Auf Vulkan ~5,5×, über das Gateway ~6,6×
  (Stimmen: juergen, vera + Klon `lucy`, jeweils eine pro Request).
  Bekannte Modelleigenschaft: gelegentlich verschluckte Anfangswörter und verfrühter
  Endabbruch — in **allen** Runtimes, nichtbehebbar (Details
  [Fehlerbilder](Model%20Evaluation%20Details.md#fehlerbilder-im-produktivbetrieb-analyse-22112026)).
- ~~Pocket-TTS 6l~~ (April **und** 09/2026): Ziffern/Englisch schlecht → Qualitätsfaktor
  ist die Modellgröße, nicht das Checkpoint-Alter.
- ~~Pocket-TTS 24l, Checkpoint 10/2026~~: unter Realtime (Anforderung verletzt) **und**
  schlechtere Aussprache als April. Offener Gegenhörtest 09/2026-GGUF auf Vulkan (Details).
- ONNX-Demo (April-Export): klang in allen Varianten gut, auch Zahlen/Englisch —
  Beleg für die Sampler-/EOS-Hypothese, keine Basis.
- audio.cpp: sehr schnell, aber teils überhastet/verzerrt; Pocket-TTS in der WebUI nicht
  wählbar (CLI funktioniert); nur WAV-Ausgabe.
- ~~OmniVoice~~: selbst 8 MaskGIT-Schritte sehr gut (nur „gerendered“ auffällig), aber
  0,95–2,8× → Anforderung verletzt; Pflicht-Transkript; ~900 MB Fußabdruck.
- **Qwen3-TTS ✅ in Produktion (23.11.2026, Backend seit_dem selben Tag: audio.cpp)**:
  CPU-Wege bleiben disqualifiziert (~0,7–0,9×; upstream ~1× auf RTX 3090); die
  Qualität entschied: 1.7B-Base-Klon mit unnormalisierten Ziffern = bestes Deutsch
  aller Tests (Fußnote ⁷). Emotionen: nur über `instruct`-Feld mit
  1.7B-CustomVoice/VoiceDesign — Base/Klonen kann keine (Details unter
  [Qwen3-TTS](Model%20Evaluation%20Details.md#qwen3-tts)).
  Erstproduktiv war gufos GPU-Server (~1,7×); zwei parallele gufo-Instanzen
  (LLM+TTS) machten aber Probleme → Umstieg auf audio.cpp `audiocpp_server`
  (Vulkan, Q8_0-GGUF, eigenes Image): ~2× Realtime im Systemsstillstand,
  ~1× unter Volllast des LLM; Setup in den
  [Eval-Details](Model%20Evaluation%20Details.md#audiocpp-als-qwen3-tts-server-produktiv-schicht-23112026).
- ~~Chatterbox~~: klingt sehr gut, aber zu langsam; Turbo = nur Englisch + kein Cloning.
- ~~Kokoro~~: offenbar kein Voice Cloning.

# Alternative Modelle, ungetestet

- KittenTTS
- F5 TTS (auf Reddit als gut und schnell beschrieben)
- Chatterbox-multilingual 500M (unklar, ob audio.cpp das lädt)
- Pocket-TTS `german_2026-09_24l` auf dem gepatchten Vulkan-Stack — GGUF liegt unter
  `/srv/llama/models/pocket-tts/german_2026-09_24l/`, offener Gegenhörtest April vs. 09
  (relevant nur für den ehemaligen Vulkan-Stack)

# Runtimes

| Runtime | ✓ | Kurzbewertung |
|---|---|---|
| **audio.cpp `audiocpp_server` + Gateway** (`0xshug0`, Vulkan/ggml) | ✅ | Produktiv seit 23.11.2026 (Qwen3-TTS 1.7B Base Q8_0_v2 GGUF, lucy-Preset): Image `full-vulkan-20261123-f79c880` (enthält v0.9.6), `mode: streaming` liefert PCM während der Generierung (erstes Audiobyte ~0,65 s), ~2× Realtime im Systemsstillstand / ~1× unter LLM-Volllast, `/v1/audio/voices` aus Config-Presets. Braucht Gateway-Env `stream_format=audio`. Kein HIP/ROCm-Image (nur cpu/cuda/vulkan); `gfx1151_v1`-Kernel-Preset existiert nur im HIP-Pfad. Setup: [Eval-Details](Model%20Evaluation%20Details.md#audiocpp-als-qwen3-tts-server-produktiv-schicht-23112026) |
| **gufo `serve tts` + Gateway-Proxy** (Rust, HIP/GPU) | — | War kurz Produktiv (23.11.2026): `/ready` in ~14 s, ~1,7× Realtime, PCM/SSE/WebSocket-Streaming, Ziffern ohne Normalisierung, Voice = wav+txt auf Disk, deterministische Seeded-Replays. Braucht Gateway (`tts-gateway`) für mp3. Ablösegrund: zwei parallele gufo-Instanzen (LLM+TTS) liefen nicht sauber zusammen; `gufo-tts.sh` entfernt 23.11. (Git-Geschichte) |
| **pockettts.cpp + Gateway** (C++/ggml-Port, Vulkan; alter Stack, Git-Geschichte) | Fallback | Schnellster Weg zu 24l: 4,5–6,6× Realtime; OpenAI-kompatibler `tts-server`. Nachteile: nur WAV/PCM → eigener Python-Gateway ergänzt mp3/opus/aac/flac aus dem PCM-Stream (echtes Streaming bleibt); registrierte Stimmen nur im RAM (flüchtig); Onset-Fix (upstream PR#1) als eigener Patch angewandt |
| Python-Referenz (kyutai/pocket-tts 4.0.1) | | ~0,97× Realtime auf CPU (f32) → Anforderung klar verletzt; April-Asset-/Tokenizer-Rätsel müssten neu gelöst werden |
| LocalAI v4.12.1 | | Produktiv bis 30.10.2026, dann abgelöst: echte OpenAI-API mit opus/mp3, aber Python-Backend mit 1 Intraop-Thread (24l unter Realtime) und „ogg“ lieferte Vorbis statt Opus |
| audio.cpp (`0xshug0`), Okt-Test via `full-cpu` | | Sehr schnelle CLI, aber WebUI-Bug (Pocket-TTS nicht auswählbar); dazumal als Serving-Basis verworfen — heute Produktiv-Runtime (siehe erste Zeile) |
| ONNX (KevinAHM-Demo-Stack) | | Lokal reproduziert, guter Klang (INT8, 1 und 8 Steps); ohne eigenes Serving — nur Erkenntnisquelle |
| omnivoice.cpp @ `1a468d8` | | Läuft sauber, eigener OpenAI-Server vorhanden; aber nur 0,95–2,8× |
| Qwen3-TTS-FastAPI (`groxaxo` @ `e17c1c9`) | | Sauberstes Repo (WebUI, API, Docs, ROCm-Image); CPU-Nachmessung 22./23.11.: ~0,7–0,9× Realtime, gufos `serve tts` (GPU) ~1,7×, upstream ~1× auf RTX 3090 → Qwen3-TTS zu langsam |
