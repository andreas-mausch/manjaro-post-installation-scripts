# Text-to-Speech (Pocket-TTS)

Produktive Sprachausgabe des Hermes-Stacks: **Pocket-TTS german_24l
(April-Checkpoint)** mit [`pockettts-gateway/`](pockettts-gateway/README.md)
(`pockettts.cpp` + Vulkan, OpenAI-kompatible API, Host-Port 8081).
Ausführliche Findings: [Model Evaluation Details](Model%20Evaluation%20Details.md).
Dieses Dokument bündelt am 22.11.2026 vier Datums-Notizen (Originalfassung: Git-Log).

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
| **Pocket-TTS `german_24l` (April, `e041936c`) ✅ gewählt** | `pockettts.cpp fab7972` + `onset-keep-first-frame.patch`, Vulkan0, via `pockettts-gateway` | 2026-04 | 379 | Q8_0 (eigenkonvertiert) | ~5,5–6,6× (CPU 4,5–4,7×) | ✓ (immer chunked; wav/pcm/mp3/opus/aac/flac; TTFB 0,02–0,28 s) | ✓ | ✓ | ✓ | — | ✗ |
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
- ~~Qwen3-TTS~~: Nachmessung 22./23.11.: ~0,9× Realtime (CPU bf16), 1.7B-Base nur
  ~0,7× — auch upstream kommen auf einer RTX 3090 nur ~1× heraus, die 5–10×-
  Anforderung ist mit dieser Modellfamilie aktuell auf keinem Backend erreichbar.
  Qualität dagegen bestätigt: 1.7B-Base-Klon ohne Runtime-Normalisierung = bestes
  Deutsch aller Tests (siehe Fußnote ⁷). Emotionen: nur über `instruct`-Feld mit
  1.7B-CustomVoice/VoiceDesign — Base/Klonen kann keine (Details unter
  [Qwen3-TTS](Model%20Evaluation%20Details.md#qwen3-tts)).
  Repo (WebUI, API, Docs) sonst sehr gut.
- ~~Chatterbox~~: klingt sehr gut, aber zu langsam; Turbo = nur Englisch + kein Cloning.
- ~~Kokoro~~: offenbar kein Voice Cloning.

# Alternative Modelle, ungetestet

- KittenTTS
- F5 TTS (auf Reddit als gut und schnell beschrieben)
- Chatterbox-multilingual 500M (unklar, ob audio.cpp das lädt)
- Pocket-TTS `german_2026-09_24l` auf dem gepatchten Vulkan-Stack — GGUF liegt unter
  `/srv/llama/models/pocket-tts/german_2026-09_24l/`, offener Gegenhörtest April vs. 09
  (April-Paket ist Basis, auf der Produktiv läuft)
- gufo-integriertes Qwen3-TTS — gufo bietet Qwen3-TTS selbst an und ist damit vermutlich
  optimierter als unser Python-venv-Aufsetzer; vor eigenem Qwen3-TTS-Einsatz erst das
  testen ([Doku](https://github.com/gufo-org/gufo/blob/main/docs/models/qwen3-tts.md),
  Notiz 22.11.2026)

# Runtimes

| Runtime | ✓ | Kurzbewertung |
|---|---|---|
| **pockettts.cpp + pockettts-gateway** (C++/ggml-Port, Vulkan) | ✅ | Schnellster Weg zu 24l: 4,5–6,6× Realtime; OpenAI-kompatibler `tts-server`. Nachteile: nur WAV/PCM → eigener Python-Gateway ergänzt mp3/opus/aac/flac aus dem PCM-Stream (echtes Streaming bleibt); registrierte Stimmen nur im RAM (flüchtig); Onset-Fix (upstream PR#1) als eigener Patch angewandt |
| Python-Referenz (kyutai/pocket-tts 4.0.1) | | ~0,97× Realtime auf CPU (f32) → Anforderung klar verletzt; April-Asset-/Tokenizer-Rätsel müssten neu gelöst werden |
| LocalAI v4.12.1 | | Produktiv bis 30.10.2026, dann abgelöst: echte OpenAI-API mit opus/mp3, aber Python-Backend mit 1 Intraop-Thread (24l unter Realtime) und „ogg“ lieferte Vorbis statt Opus |
| audio.cpp (`0xshug0`) | | Sehr schnelle CLI, aber WebUI-Bug (Pocket-TTS nicht auswählbar) und nur WAV → keine Serving-Basis |
| ONNX (KevinAHM-Demo-Stack) | | Lokal reproduziert, guter Klang (INT8, 1 und 8 Steps); ohne eigenes Serving — nur Erkenntnisquelle |
| omnivoice.cpp @ `1a468d8` | | Läuft sauber, eigener OpenAI-Server vorhanden; aber nur 0,95–2,8× |
| Qwen3-TTS-FastAPI (`groxaxo` @ `e17c1c9`) | | Sauberstes Repo (WebUI, API, Docs, ROCm-Image); CPU-Nachmessung 22./23.11.: ~0,7–0,9× Realtime, upstream ~1× auf RTX 3090 → Qwen3-TTS zu langsam |
