# Model Evaluation Details

Ausführliche Fassung zu [README.md](README.md) (Auswahltabellen, Runtimes).
Zusammengeführt am 22.11.2026 aus vier Datums-Notizen: Modell-Eval 29.10.2026,
Vulkan-Benchmark 30.10.2026, Onset-Analyse 22.11.2026, LocalAI-Setup-Doku.
Originalfassungen im Git-Log.

# Pocket-TTS

Produktives Modell. Paketstand und Eigenkonversion:
[`models/README.md`](models/README.md). Kurz: April-Checkpoint `e041936c`
(gated `kyutai/pocket-tts`), selbst zu Q8_0-GGUF konvertiert (das ungated Mirror
nullt `mimi.encoder.*` → Klonen defekt; Encoder lässt sich nicht vom neueren
Checkpoint anpfropfen, Mimi-Codec wurde komplett neu trainiert). Ablage
`/srv/llama/models/pocket-tts/`, jeweils GGUF neben den Ausgangsgewichten:

| Verzeichnis | Inhalt |
|---|---|
| `german/` | April-6l + `pocket-tts-german_april-Q8_0.gguf` / `-voices.gguf` (26 Stimmen), `spm2json.py` |
| `german_24l/` | April-24l + `pocket-tts-german_24l_april-Q8_0.gguf` / `-voices.gguf` (juergen, vera) — **Produktion** |
| `german_2026-09/`, `german_2026-09_24l/` | Jüngerer Stand (Safetensors + Serveurperso-GGUFs Q8_0 + Stimmen) |

Die GGUFs tragen `pocket.gen.frames_after_eos = -1` (auto) und
`pocket.gen.temperature = 0.3` — identisch zu Serveurpersos offiziellen Paketen.

## Checkpoint-Frage: April (`e041936c`) vs. jünger

**Ausgangslage.** Die Browser-Demo
([KevinAHM/pocket-tts-web](https://huggingface.co/spaces/KevinAHM/pocket-tts-web),
ONNX) klang mit deutschen Zahlen und englischen Wörter deutlich besser als unsere
damaligen Runtimes (LocalAI/Python mit aktuellem Checkpoint, pockettts.cpp).
Testtext durchgehend: „Es ist 13:05. Die Items werden mit Sprites gerendered.
Tschüß.“ (prüft Ziffern + englische Begriffe), Voice juergen.

**Lokale Reproduktion der ONNX-Demo (30.10., Ryzen 7 PRO 7840U):** mit
zusammenpassenden April-Gewichten, April-Tokenizer und April-Jürgen klingt auch
die native Python-Version gut. ONNX INT8: alle sechs Aufnahmen gut, sowohl mit
1 als auch 8 Steps. **Der entscheidende Unterschied ist das Modellpaket, nicht
Python vs. ONNX.**

**Einzelbefunde (Python 4.0.1, CPU-f32, 1 Step):**

- Neuerer Checkpoint: Zahlen unverständlich, englische Wörter eingedeutscht;
  Temperatur 0,7 statt 0,3 löst das nicht.
- Demo-/April-Tokenizer mit neueren Gewichten: komplettes Kauderwelsch — die
  Token-IDs haben andere Bedeutungen, einfacher Tokenizer-Austausch geht nicht.
- April-Voice-State mit neueren Gewichten: alle zwölf Aufnahmen brechen nach
  0,72 s ab, fast nur Rauschen. Kein sinnvoller Test.
- Passendes April-Paket (Gewichte + SentencePiece-Tokenizer + Jürgen-State, alle
  aus Revision `e041936c`): Aussprache passt, auch Zahlen und Englisch. Seed 101
  am besten; bei Seed 202 fehlt am Anfang „Es ist“, Seed 303 klingt etwas aggressiv.

**Geprüfte Asset-Kombinationen:**

| Test | Gewichte | Tokenizer | Jürgen-Voice-State |
|---|---|---|---|
| Native Baseline | neuer `4e1e0a3e` | neuerer Tokenizer | Release-Default `a7056f50` |
| Checkpoint-passende Stimme | neuer `4e1e0a3e` | neuerer Tokenizer | `4e1e0a3e` |
| Roher Tokenizer-Tausch | neuer `4e1e0a3e` | April/Demo | Release-Default oder April |
| Gemischter April-Voice-Test | neuer `4e1e0a3e` | neuerer oder April | April `e041936c` |
| Funktionierendes Paket | April `e041936c` | April `e041936c` | April `e041936c` |

Auch die zum neueren Checkpoint *passende* Stimme liefert schlechte Aussprache —
es liegt nicht an einer einzelnen abweichenden Voice-Version. Erfolgreich war nur
der Tausch des gesamten zusammengehörenden Pakets; welcher Teil der neueren
Paketänderungen die Aussprache verschlechtert, ist nicht isoliert.

**Gewichtsvergleich:** ONNX und der neuere native Checkpoint sind verschiedene
Gewichtssätze, nicht nur unterschiedlich quantisiert. Demo-Tokenizer und die
gesamte Text-Embedding-Tabelle stimmen exakt mit dem öffentlichen April-Checkpoint
`e041936c` überein; geprüfte Transformer-, Flow- und Decoder-Gewichte passen
ebenfalls (vollständiger Vergleich ausstehend). Details:
`weight-analysis/WEIGHT_COMPARISON.md` im Archiv (siehe Material & Fundorte).

**Verifizierter April-Lauf (30.10.):** vollständiger öffentlicher Checkpoint,
SentencePiece-Tokenizer, Jürgen-State aus `e041936c`; alle drei Asset-Hashes und
alle 358 geladenen Tensoren geprüft; Seed 101 reproduziert bit-identisch. Native
EOS-Einstellungen (Schwelle −4, Mindestframe 6, Nachlauf 3 Frames):

| Seed | Audio | Generierung ohne Modellladen | EOS-Frame |
|---|---|---|---|
| 101 | 5,20 s | 5,345 s | 62 |
| 202 | 6,08 s | 6,257 s | 73 |
| 303 | 7,28 s | 7,504 s | 88 |

**Zusatztest April-6l (30.10.):** Gewichte, Tokenizer und eigener Jürgen-State aus
`languages/german@e041936c`; 6 Transformer-Layer, alle 214 Tensoren geprüft; nur der
byte-identische Tokenizer wurde wiederverwendet, nicht der 24L-Voice-State.

| Seed | Audio | Generierung ohne Modellladen | EOS-Frame |
|---|---|---|---|
| 101 | 5,28 s | 1,715 s | 63 |
| 202 | 4,00 s | 1,337 s | 47 |
| 303 | 4,96 s | 1,614 s | 59 |

Alle drei enden durch EOS. Aggregiert ~3,05× Realtime vs. ~0,97× beim passenden
24L-Lauf (~3,14× schneller pro Audiosekunde); kein alternierender Benchmark,
nur drei Seeds. **Hörurteil:** April-24L klingt deutlich besser; 6L spricht
selbst auf April englische Wörter zu eingedeutscht und Zahlen schlecht.
Für den Testtext ist April-24L trotz Rechenaufwand die bessere Wahl.
Direkter 6L-/24L-Hörvergleich: `april-german-6l/listen.html` im Archiv.

**Bewertete Testdateien (Satz 2, Voice juergen, lokale Runtimes):**

| Datei | Runtime/Konfiguration | Urteil |
|---|---|---|
| `e-f32-python-juergen.wav` | LocalAI, Python 4.0.1, f32, 1 Step | schlecht |
| `g-bf16-vulkan.wav` | pockettts.cpp, BF16-GGUF, Vulkan | schlecht |
| `h-bf16-cpu-nofa.wav` | pockettts.cpp, BF16-GGUF, CPU, FP32-Attn | schlecht |
| `c-cpu-nofa-temp0.wav` | pockettts.cpp, Q8_0, CPU, temp 0 | (nicht bewertet; 22.11. nachgereicht: degenerate, s. Sampler-Sweep) |
| `p-steps1.wav` / `p-steps8.wav` | Python 4.0.1, HEAD-Checkpoint, 1/8 Steps | 8 Steps: Früh-Abbruch |
| `i-april-run1/2.wav` | Python 4.0.1, April-Checkpoint + April-juergen | Kauderwelsch (früher Mischversuch; der verifizierte matched Lauf unten klingt gut) |

## Hypothesen: Warum die ONNX-Demo gut klingt

1. Die ONNX-Portierung implementiert Sampler (externer Flow-Loop), EOS oder
   Text-Vorverarbeitung anders als Referenz/GGUF — und genau das macht den
   Qualitätsunterschied aus.
2. Der ONNX-Export (April) könnte aus dem **gated** Repo `kyutai/pocket-tts` von
   einer anderen Revision stammen als der verglichene ungated Zwilling (lokal
   ohne HF-Zugang nicht prüfbar).
3. Die Voice-Embeddings der Demo wurden möglicherweise mit dem ONNX-Mimi neu
   gerechnet und passen nicht 1:1 zu den safetensors-States aus dem HF-Repo.

## Offener Gegenhörtest: 24l April vs. 2026-09

Der Qualitätsfaktor ist die Modellgröße (24l), nicht das Checkpoint-Alter —
April vs. 09/2026 war beim 6l tempo- und qualitätsseitig neutral (Hörurteil
30.10.). Ob das **24l** zwingend auf April stehen muss, ist nie gegeneinander
gehört: `german_2026-09_24l/pocket-tts-german_24l-Q8_0.gguf` steht bereit.
Andreas' Notiz: Nach früheren Tests klang 24l mit 09/2026-Gewichten deutlich
schlechter — Releasestand wäre dann beim 24l der Qualitätsfaktor (Gegenteil der
beim 6l widerlegten Alters-Hypothese). **Aufwand ~10 min** (Sweep-Seeds auf dem
gepatchten Stack), Entscheidungshilfe für einen eventuellen Modellwechsel.

## Geschwindigkeits-Benchmarks

### LocalAI CPU: german (6l) vs. german_24l (29.10.2026)

Setup: LocalAI v4.12.1, CPU-Backend (wie im damaligen Hermes-Stack), zwei Server
parallel — `german` auf 8081 (laufender Dienst), `german_24l` als Wegwerf-Container
auf 8082 mit Modell-YAML `language:german_24l` und Gewichten aus
`/srv/llama/models/pocket-tts/german_24l`. Jeweils 1 Warmup + 3 Messläufe,
alternierend, gleicher Text, `curl` `time_total` (inkl. HTTP-Overhead).

Satz 1 („Hallo, das ist ein Test der deutschen Sprachausgabe. Heute probiere ich
ein groesseres Modell aus und schaue, wie viel Zeit das kostet.“):

| Modell | API-Zeit (Ø) | Audio (Ø) | Rechenzeit pro Sekunde Audio |
|---|---|---|---|
| german | 2,49 s | 7,81 s | ~0,32 s (~3× Realtime) |
| german_24l | 9,84 s | 9,04 s | ~1,09 s (unter Realtime) |

Satz 2 („Es ist 13:05. Die Items werden mit Sprites gerendered. Tschüß.“):

| Modell | API-Zeit (Ø) | Audio (Ø) | Rechenzeit pro Sekunde Audio |
|---|---|---|---|
| german | 2,21 s | 6,56 s | ~0,34 s (~3× Realtime) |
| german_24l | 8,52 s | 7,76 s | ~1,10 s (unter Realtime) |

Ergebnis: `german_24l` ~4× langsamer (pro Audiosekunde ~3,4–3,9×), erreicht auf der
CPU nicht einmal Realtime-Tempo und spricht denselben Text zudem langsamer.
Audioqualität damals nicht bewertet. Setup-Hinweise: `pocket_tts` 4.0.1
unterstützt `german_24l` nativ als `language`-Option; `language:german` mit
24l-Gewichten schlägt fehl (Unexpected keys `flow_lm.transformer.layers.6..23` —
Architektur kommt aus der Sprach-Config des Backends). Benötigte Bind-Mounts an die
HF-Snapshot-Pfade: `model.safetensors` →
`models--kyutai--pocket-tts/snapshots/2dd944b0…/languages/german_24l/model.safetensors`,
`tokenizer.json` →
`models--kyutai--pocket-tts-without-voice-cloning/snapshots/4e1e0a3e…/languages/german_24l/tokenizer.json`.
Caveats: Einzelrechner, je 3 Messungen, CPU-Backend setzt selbst 1 Intraop-Thread.

### pockettts.cpp: CPU und Vulkan (29.10.2026)

`pocket-tts-german_24l-Q8_0.gguf` (damals Serveurperso-GGUF) + Klon-Stimme
`sample.wav`, gleiche Sätze wie oben; `[TTS]`-Zeilen = Synthese ohne Modell-Ladung
(~0,4 s) und Voice-Encoding (~0,6 s):

| Backend | Satz 1 (Ø) | Satz 2 (Ø) | Tempo |
|---|---|---|---|
| LocalAI CPU, german (Referenz) | 2,49 s | 2,21 s | ~3× Realtime |
| LocalAI CPU, german_24l (Referenz) | 9,84 s | 8,52 s | ~0,9× |
| pockettts.cpp, CPU | 1,84 s | 1,97 s | 4,5–4,7×, sehr stabil |
| pockettts.cpp, Vulkan0 | 0,58–1,14 s | 1,29–1,54 s | 5,5–12×, volatil (Bursts bis 17×) |
| tts-server, Vulkan0, via HTTP | — | ~1,23 s | ~6,6× |

Kernbefund: **24l wird nutzbar** — schon der CPU-Build ist ~4,6× Realtime
(alle Kerne + Q8_0 statt 1 Intraop-Thread + f32); auf Vulkan ist die
5–10×-Anforderung erfüllt. Vulkan-Taktvolatilität: nicht thermisch (Tctl ~53 °C),
vermutlich APU-Taktstufen.

### Vulkan-Duell: Pocket-TTS vs. OmniVoice (30.10.2026)

Ryzen AI Max 395+ (iGPU „AMD Radeon 8060S Graphics“, RADV STRIX_HALO, Vulkan 1.4
+ KHR_coopmat). Alle Läufer C++/GGML mit identischem Backend (`--device Vulkan0`),
Stimmklone aus derselben `sample.wav` (7,3 s, Transkript in `sample.txt`).

|  | Pocket-TTS (german 6l, 2026-04) | Pocket-TTS (german 6l, 2026-09) | Pocket-TTS (german_24l, 2026-04) | OmniVoice |
|---|---|---|---|---|
| Runtime | `pockettts.cpp` fab7972 | `pockettts.cpp` fab7972 | `pockettts.cpp` fab7972 | `omnivoice.cpp` 1a468d8 |
| Modell | `german_april` Q8_0, 138 MB (eigenkonvertiert) | `german` Q8_0, 138 MB (Serveurperso-GGUF) | `german_24l_april` Q8_0, 379 MB (eigenkonvertiert) | `omnivoice-base` Q8_0, 626 MB + Codec Q8_0, 276 MB |
| Architektur | 6-Layer-Flow-LM (~100 M), Mimi-Codec | wie links, jüngerer Checkpoint | 24-Layer-Flow-LM, Mimi-Codec | 612-M-Qwen3-Backbone, MaskGIT-Decoder + Higgs-DAC-Codec |
| Voice Cloning | `--voice sample.wav` | wie links | wie links | `--ref-wav sample.wav` **+ `--ref-text` Pflicht** |
| Generierung | Defaults (1 Flow-Schritt), Seed 42 | wie links | wie links | Standard 32 MaskGIT-Schritte × CFG; zusätzlich 16/8 gemessen |
| **End-to-End-Zeit (Ø)** | **0,50 s** (0,28–0,62) | **0,45 s** (0,28–0,61) | **1,03 s** (0,53–1,30) | **4,56 s** (32 St.) · 2,57 s (16) · 1,60 s (8) |
| **Audiolänge (Ø)** | 5,52 s | 5,60 s | 5,68 s | 4,35 s (32) · 4,43 s (16) · 4,44 s (8) |
| **Tempo (Ø, inkl. Start)** | **~11× Realtime** | **~12× Realtime** | **~5,5× Realtime** | **0,95×** · 1,7× (16) · 2,8× (8) |
| Nur Synthese | 0,14–0,39 s | 0,14–0,38 s | 0,34–1,0 s | LM 3,7–4,1 s + Codec-Decode ~0,12 s |
| Modell-Load / Stimm-Encoding | ~80 ms / ~100 ms | ~85 ms / ~80 ms | ~110 ms / ~145 ms | ~0,3 s gesamt (tmpfs-geschönt) |
| HTTP-Server | `tts-server`, OpenAI-kompatibel | wie links | wie links | `tts-server`, OpenAI-kompatibel |
| **Audioqualität (Hörurteil 30.10.)** | Ziffern & englische Begriffe schlecht | wie links | **sehr gut — Favorit**; minimal vorn/hinten abgeschnitten | 8 Steps sehr gut, nur „gerendered“ auffällig; 32/16 ungehört |

Messmethode: je Konfiguration 1 Warmup + 3 Messläufe, **strikt alternierend in
identischer GPU-Sitzung**, Seed 42, Zeit = kompletter Prozess (Load + Encoding +
Synthese + WAV-Write). Achtung Taktvolatilität: Letzter Messblock bei deutlich
höherem Takt; Sustain-Werte: 6l ~9×, 24l ~4,5×.

Kernaussagen:

- Tempo-Ranking: 6l (~11–12×) → 24l (~5,5×) → OmniVoice (0,95× bei 32 Schritten);
  24l ist ~4,4× schneller als OmniVoice und erfüllt 5–10× im Sustain knapp;
  OmniVoice verfehlt sie selbst mit 8 Schritten (2,8×).
- OmniVoice spricht denselben Satz ~20 % schneller (4,35 s statt 5,5–5,7 s Audio) —
  sein RTF ist eher geschönt; pro erzeugter Sekunde ist der Abstand größer.
- Fußabdruck: OmniVoice ~900 MB (inkl. HuBERT-/DAC-Encoder), 24l ~380 MB, 6l ~130 MB;
  kalter Disk-Load trifft OmniVoice härter (Modelle lagen in /tmp).
- Bedienung: Pocket-TTS braucht nur die Referenz-WAV; OmniVoice zwingend das
  Referenz-Transkript (oder ASR im Python-Stack).
- 24l braucht pro Audiosekunde ~2,5× so lange wie 6l — Qualität ist nicht gratis,
  aber auf Vulkan tragfähig.

Hörurteil 30.10. (Andreas, identischer Seed/Clone, Dateien in `out/`): 24l April
= Favorit (einziger Makel: vorne/hinten ganz leicht abgeschnitten → später als
Frame-Drop-Bug identifiziert, s. Fehlerbilder); OmniVoice 8 Steps sehr gut; beide
6l-Varianten bei Ziffern/Englisch schlecht.

**Empfehlung (30.10.):** `german_24l_april` Q8_0 auf Vulkan als Produktiv-Kandidat.
6l nur akzeptabel, wenn nie Zahlen oder englische Begriffe vorkommen.

Repro:

```bash
# Pocket-TTS (alle drei Pakete gleich, nur --model wechseln, z. B.:)
#   german/pocket-tts-german_april-Q8_0.gguf
#   german_2026-09/pocket-tts-german-Q8_0.gguf
#   german_24l/pocket-tts-german_24l_april-Q8_0.gguf
echo "Testtext" | ~/Documents/coding/tts/pockettts.cpp/build/pocket-tts \
  --model /srv/llama/models/pocket-tts/german_24l/pocket-tts-german_24l_april-Q8_0.gguf \
  --voice sample.wav --device Vulkan0 --seed 42 -o out.wav

# OmniVoice (Voice Cloning, Standard 32 Schritte)
echo "Testtext" | omnivoice.cpp/build/omnivoice-tts \
  --model models/omnivoice-base-Q8_0.gguf \
  --codec models/omnivoice-tokenizer-Q8_0.gguf \
  --ref-wav sample.wav --ref-text ref.txt \
  --lang German --device Vulkan0 --seed 42 -o out.wav
```

### Python-Referenz: Wechsel keine Option

Geschwindigkeit (german_24l): Python 4.0.1 CPU-f32 ≈ **0,97× Realtime** (unter
Realtime), pockettts.cpp CPU 4,5–4,7×, Vulkan + Gateway ~6,6× → Python verletzt
die Anforderung „5–10× schneller als Realtime“ deutlich. Zusätzlich müssten
April-Checkpoint-/Tokenizer-Rätsel (s. o.) und der GGUF-Bau komplett neu gelöst
werden. Wakamex belegte zudem Frame-Äquivalenz des C++-Ports gegen die
F32-Referenz (pockettts.cpp PR#1) — Qualität spricht nicht für den Wechsel.

## Fehlerbilder im Produktivbetrieb (Analyse 22.11.2026)

Symptom im Produktivbetrieb (`pockettts-gateway`, german_24l_april Q8_0, Vulkan,
Klon-Stimme `lucy`): **Silben am Wortanfang fehlen**, gelegentlich auch am Ende.

### Onset-Clipping: Upstream verwirft den ersten Frame jedes Chunks (behoben)

Commit [`c53c1ff` „Drop the onset frame of every chunk“](https://github.com/ServeurpersoCom/pockettts.cpp/commit/c53c1ffd79bbbb6cc5588907ff9cd8e195ccf578)
(27.09.2026) verwirft in `pt_synthesize` den ersten 80-ms-Frame **jedes** Chunks,
um einen Click des kalten Mimi-Decoders zu entfernen. Beginnt die Sprache in diesem
Frame (regelmäßig, seed- und stimmenabhängig), fehlt der Wortanfang. Verifiziert:
unser gepinnter Build `fab7972` enthält `c53c1ff` (`git merge-base --is-ancestor`).
Auch Chunk-Übergänge mitten im Satz betroffen — deshalb mal früher, mal später.

Der Click ist real, kommt aber laut Kyutai vom frischen Decoder-State, nicht vom
Frame selbst; Kyutai hält in der Python-Referenz den Frame und faden nur die ersten
5 ms ein ([#332](https://github.com/kyutai-labs/pocket-tts/pull/332)/[#335](https://github.com/kyutai-labs/pocket-tts/pull/335)).

Fix für uns: [pockettts.cpp#1](https://github.com/ServeurpersoCom/pockettts.cpp/pull/1)
(`wakamex`, 15.10.2026, Commit `11fc272`: ersten Frame behalten, 5 ms Fade-in) —
seit über 5 Wochen offen, nicht gemerged (master bis 17.11. nur ggml-Rebases).
Übernommen als `pockettts-gateway/onset-keep-first-frame.patch`, angewandt im
Dockerfile; Image `local/pocket-tts-vulkan:fab7972-onset1`. Hinweis: Jeder Chunk
wird 80 ms länger (Frame bleibt erhalten) — für den Gateway transparent.

Deployment-Beleg (22.11.): seed-gleich ist jede Aufnahme exakt 80 ms länger; die
verworfenen Frames enthielten hörbares Material (RMS ≈ −25 dB, keine Stille).

### Verschluckte/falsche Anfangswörter: Voice-Prompt und Modell-Lotterie

Hintergrund: Trainings-Prompts enden immer in einer Sprechpause. Endet ein
Voice-Prompt mitten in der Sprache (out-of-distribution), „setzt das Modell sie
fort“ → Bursts und falsche/fehlende Anfangswörter. Kyutai behebt das in
[#334](https://github.com/kyutai-labs/pocket-tts/pull/334) (`end_on_pause`:
trailing silence schneiden, letzte 20 ms ausfaden, 80 ms Stille anhängen;
Bursts 17/400 → 0/400, One-Word-Treffer 425/480 → 451/480).
`pt_voice_from_audio` in pockettts.cpp (unser Weg für `lucy` via
`POST /v1/audio/voices`) wendet `end_on_pause` **nicht** an; auch die States
unseres `-voices.gguf` (juergen/vera) entsprechen dem Vor-#334-Schnitt.
Messungen in pockettts.cpp#1: mit Vor-#334-State liegt Sprache in ~31 % der Clips
(25/80) im Frame 0, mit `end_on_pause`-State nur in ~8 %.

**end_on_pause-Experiment (22.11.), nicht übernommen:** `sample.wav`
(44,1 kHz stereo) vorverarbeitet (ffmpeg: Silence-Cut → 20 ms Fade-out →
+80 ms Stille) und als Wegwerf-Voice `lucyfix` registriert. Ergebnis:
**transkript-identisch zu `lucy` pro Seed, kein messbarer Effekt** — `sample.wav`
endet bereits nach ~133 ms Stille, also nahe einer Sprechpause; der #334-Fall
(Prompt endet mitten im Wort) trifft hier nicht zu. `startup.py` bleibt
unverändert. (Vorverarbeitung ist übrigens *Pre*-Processing des Prompts vor dem
Voice-Encoding, keine Nachbearbeitung der Ausgabe — sie würde also an der Ursache
ansetzen, bringt hier nur nichts.)

**STT-Kontrolle + Sampler-Sweep** (whisper.cpp `small`, gepatchter Build,
Voice lucy, 8 Seeds; s1 = „Es ist 13:05 …“, s3 = „Okay, los geht’s.“):

| Einstellung | s1 „Es ist…“ | s3 „Okay…“ | Bemerkung |
|---|---|---|---|
| Standard | 6/8 | 4/8 | Referenz |
| + end_on_pause (lucyfix) | 5/8 | 4/8 | seed-identisch zu lucy → kein Effekt |
| temperature 0,4 | — | 5/8 | kein clear winner |
| temperature 0,1 | 6/8 | 5/8 Onset | Satzmitte degeneriert („Okay, no skates“) |
| temperature 0,0 | degenerate | degenerate | s1 bricht nach „Das ist 1305.“ ab → **greedy-Kollaps, vermutlich Port-Bug**, upstream meldbar |

Caveat: whisper small ist konservativ — ein als „Das ist“ transkribiertes
„Es ist“ kann sich korrekt anhören. Seed 4 produziert über alle Voices und
Temperaturen degenerate Ausgaben (whisper halluziniert „Copyright WDR 2020“).
Nebenbefund: gestreamte WAVs mit unbekannter RIFF-Länge (unser Gateway-Format)
bringen `whisper-cli` zum Segfault — vor STT immer auf 16 kHz Mono-PCM konvertieren.

### Einordnung: zwei Fehlerklassen

1. **Runtime-Bug (war pockettts.cpp, behoben):** konstantes Onset-Clipping durch
   den Frame-Drop. Die Online-Demos liefen nie mit diesem Bug.
2. **Modell-Lotterie (nicht fixbar, nur abfederbar):** kurzes erstes Wort wird
   übersprungen/ersetzt. Zeigt sich in **allen** Runtimes: Kyutai misst nach allen
   Fixes noch ~6 % Fehlstarts (Ein-Wort-Texte), und unser eigener Python-4.0.1-Lauf
   vom 30.10. auf April-Gewichten verlor bei Seed 202 „Es ist“ — ohne eine Zeile
   cpp-Code.

**Warum die Online-Demos trotzdem „perfect“ wirken:** (1) kuratierte,
nach-#334-regenerierte Voice-States statt Hausklon `lucy` und Vor-#334-GGUF-States;
(2) neuere/andere Modellpakete bzw. beim ONNX-Demo möglicherweise anderes
Sampler-/EOS-Verhalten ([Hypothesen](#hypothesen-warum-die-onnx-demo-gut-klingt)); (3) der Mensch drückt bei
versemmelter Antwort einfach erneut Generate — genau die Retry-Schicht, die im
automatischen Betrieb fehlt; (4) Demo-Texte sind meist volle Sätze, die Lotterie
trifft vor allem Kurzantworten.
### Ende-Abschneiden: Early EOS (offen)

Früher EOS-Abbruch der Generierung in **allen** Runtimes in etwa jedem 3. Lauf
(Seed-Lotterie bei Temperatur/eos_threshold; im April-Protokoll dokumentiert,
unabhängig vom Onset-Thema). Optionen: `eos_threshold` erhöhen,
`--frames-after-eos`-Feintuning, oder Konsumenten-seitig Mindestausgabelänge
prüfen. Nicht behoben durch den Onset-Patch.

### Gateway unschuldig

Reine Byte-Pipe (Backend-PCM → ffmpeg → HTTP-Chunk), kein Trimming, keine
Stille-Logik. Ein „Stille-Polsterung“-Workaround (Benchmark 30.10.) wurde nie
implementiert und ist auch nicht nötig.

### Entscheidung (22.11., Andreas)

Der gepatchte April-Stack läuft unverändert weiter; keine Verifikations-/Retry-Schicht
(ASR-Roundtrip + Seed-Retry wäre machbar, ~87–99 % Erfolg in 3 Versuchen bei den
gemessenen Trefferquoten, wurde aber nicht gebaut). Wenn ein Modellwechsel ansteht,
zuerst den [offenen Gegenhörtest](#offener-gegenhörtest-24l-april-vs-2026-09) fahren und gegen den
Zahlen-/Englisch-Nachteil der neueren Pakete abwägen; Class-2-Fehler („Okay“
verschluckt) gelten bis dahin als hingenommene Modelleigenschaft.

### Offene Experimente (Entscheidungshilfe Modellwechsel)

1. **`german_2026-09_24l` (Serveurperso-GGUF Q8_0, `/srv/llama/models/pocket-tts/german_2026-09_24l/`)
   auf dem gepatchten Stack** mit den s1/s3-Seeds 1–8 + Hörtest — entscheidet
   „unser konkretes Modell?“; Aufwand ~10 min.
2. **Python-`main` (nach allen Fixes) + April-Weights + `sample.wav`-Klon + Seed** —
   entscheidet „Port?“; Aufwand ~1 h, Assets vorhanden.
3. Optional: greedy-Kollaps bei temperature 0 als Issue an ServeurpersoCom/pockettts.cpp
   melden (Repro `t0.0-*.wav`, s. Material).

# Qwen3-TTS

Qwen/Qwen3-TTS-12Hz-0.6B-Base, getestet 29.10.2026 über
[groxaxo/Qwen3-TTS-OpenAI-Fastapi](https://github.com/groxaxo/Qwen3-TTS-OpenAI-Fastapi)
@ `783bf0e51596f1eb1e70124258f0e1ea4bf3b40a`:

```bash
python3 -m venv .venv && source .venv/bin/activate.fish
python -m pip install --upgrade pip && pip install -e ".[api]"
TTS_MODEL_NAME=Qwen/Qwen3-TTS-12Hz-0.6B-Base python -m api.main
```

- Voice Clone über die WebUI (Sample hochladen + Transkript): klappt auf Anhieb.
- Erst 1.7B getestet — zu langsam; 0.6B „klang noch gut genug, war aber immer noch
  etwas langsam“.
- Repo hat alles dabei (WebUI, API, Docs) — wirkt sehr gut.
- Emotion-Tags wie `[serious]`/`[excited]` funktionierten nicht — Aufklärung siehe
  Retest unten: Inline-Tags sind nicht vorgesehen, und Base-Modelle haben
  prinzipbedingt keine Emotionssteuerung.

## Retest 22./23.11.2026 (Ryzen AI Max 395+, Repo e17c1c9)

Aufbau: `uv`-venv Python 3.12, `torch`-CPU-Wheels, Repo-Stand `e17c1c9`;
Server mit `TTS_BACKEND=pytorch TTS_DEVICE=cpu TTS_DTYPE=bfloat16`. Stolperstein:
`TTS_LAZY_LOAD=True` ist Standard — `/health` bleibt bis zur ersten Sprachanfrage
unready. Lucy-Klon als Voice-Library-Profil (`voice=clone:lucy`, ICL mit
`ref_text`), Referenz wie im Gateway: `sample.wav` + Transkript.

**Geschwindigkeit** (1 Warmup + 3 Läufe, Sätze wie im Oktober-Protokoll;
Realtime-Faktor = Audiosekunden pro API-Sekunde):

| Konfiguration | s1 | s2 | Bemerkung |
|---|---|---|---|
| 0.6B-Base, lucy-Klon, **bf16** | **0,92×** | 0,90× | schnellster CPU-Pfad (Zen5 nativ AVX512-BF16) |
| 0.6B-Base, lucy-Klon, fp32 | 0,26× | 0,27× | Server-Warnung „bf16 unsupported“ gilt für ältere CPUs, hier umgekehrt |
| 1.7B-Base, lucy-Klon, bf16 | 0,73× | 0,70× | fairer Vergleich: gleiche Stimme/Modus, nur größere Modelle werden **langsamer** |
| 1.7B-CustomVoice, Preset Aiden | — | **0,78×** | Preset ohne Klon-Encoding — schnellste Emotions-Variante |

Zum Einordnen: die upstream-eigenen Benchmarks des Repos erreichen mit 1.7B auf einer
**RTX 3090** nur RTF ~0,97 (Official) bzw. ~0,83 (vLLM-Omni). Qwen3-TTS ist
aktuell auf keinem Backend in der Nähe der 5–10×-Anforderung; Abstand zum
Produktiv-Stack (24l Vulkan ~5,5–6,6×) also Faktor ~7–8.

**Emotionssteuerung (Code- + Praxischeck):**

Qwen verteilt Klonbarkeit und Emotionskontrolle auf getrennte Checkpoints —
pro Modellvariante entscheidet man sich für eines von beidem:

| 1.7B-Variante | Voice Cloning | Emotionen (`instruct`) |
|---|---|---|
| **1.7B-Base** | ✓ (3-s-Klon aus Referenz-WAV + Transkript) | ✗ |
| **1.7B-CustomVoice** | ✗ (nur 9 Preset-Stimmen) | ✓ |
| **1.7B-VoiceDesign** | ✗ (Stimme per Beschreibung erfunden) | ✓ |

- kein Tag-Vokabular; Steuerung über natürliches Sprach-Kommando im API-Feld
  `instruct` („Sprich wütend und schroff."). Eckige Inline-Tags im Text sind keine
  Steuerelemente.
- Nur **1.7B-CustomVoice** und **1.7B-VoiceDesign** unterstützen `instruct`;
  Base (unser Klon-Weg) und alle 0.6B-Varianten nicht — `qwen3_tts_model.py`
  setzt `instruct` für 0.6B hart auf `None`. **Klonbare Stimme + Emotion schließen
  sich bei Qwen3-TTS derzeit aus** (Workaround laut Modellkarte: VoiceDesign →
  Referenz-Clip erzeugen → davon klonen, Emotion geht dabei aber flöten).
- Hörtest-Material (Aiden, identischer Satz): `instruct` wirkt sichtbar —
  „fröhlich“ 8,5 s / „traurig“ 8,8 s / „wütend“ 6,0 s / ohne 6,2 s (unterschiedliches
  Sprechtempo). Dateien + Gegenhören:
  `~/Documents/coding/tts/qwen3-tts-bench-2026-11/listen.html` (dort auch
  Gateway-`lucy` vs. Qwen-0.6B- und 1.7B-`lucy`-Klon je 3 Läufe sowie die
  Textvarianten aus dem nächsten Absatz).
- CustomVoice hat **keine deutschsprachige Preset-Stimme** (9 Voices: Ch/Beijing/
  Sichuan/En/Ja/Ko); offizielles German-WER 1,057 (1.7B-CV) bzw. 2,722 (0.6B-CV),
  Base zero-shot DE: 1,089 (0.6B) / 1,235 (1.7B). Deutsche Qualität der Presets ist
  Hörtest-offen.

**Textvorverarbeitung — der eigentliche Qualitätssprung (Hörtest 23.11.):**

- Der Normalisierer des Runtimes (`api/services/text_processing.py`, inflect-basiert)
  arbeitet **englisch** und hatte den Testsatz vor der Synthese umgeschrieben:
  `Es ist 13:05.` → `Es ist thirteen oh five.` — das englische „13:05" im Audio ging
  also auf die Vorverarbeitung, nicht aufs Modell.
- Die API nimmt pro Request `normalization_options: {"normalize": false}` durch und
  lässt den Text unverändert. Ergebnis: **lucy spricht „13:05" einwandfrei Deutsch** —
  und mit der Korrektur `gerendered` → `gerendert` ist das mit Abstand das beste
  deutsche Ergebnis aller Tests (Hörurteil 23.11.2026, besser als der
  Produktiv-Gateway).
- Pseudo-Anglizismen wie „gerendered" beißen das Modell; gängiges „gerendert" macht
  den Satz rund. Wer Qwen3-TTS Deutsch betreibt, muss die eingebaute Normalisierung
  abschalten und ggf. selbst deutsch normalisieren (oder vornormalisierte Texte
  anliefern).

**Fazit:** Die Qualitätsfrage ist beantwortet: **Ja** — der 1.7B-Base-Klon (ohne
Runtime-Normalisierung) klingt besser als unser Pocket-TTS-Stack. Ausgeschieden ist
Qwen3-TTS trotzdem, und zwar allein an der Geschwindigkeit: ~0,7× Realtime hier,
~1× auf einer RTX 3090 upstream, gebraucht werden 5–10×. Der einzige denkbare Hebel
bleibt gufos integrierte Qwen3-TTS-Variante (ungetestet,
[Doku](https://github.com/gufo-org/gufo/blob/main/docs/models/qwen3-tts.md)).

# OmniVoice

Vollständige Benchmark-Tabelle (30.10., Vulkan): siehe
[Geschwindigkeits-Benchmarks](#geschwindigkeits-benchmarks). Ergänzend:

- Architektur: 612-M-Qwen3-Backbone + MaskGIT-Decoder + Higgs-DAC-Codec;
  Voice Cloning via `--ref-wav` **mit Pflicht-`--ref-text`** (oder ASR im
  Python-Stack).
- Hörurteil: 8-MaskGIT-Schritte sehr gut, nur „gerendered“ auffällig;
  32/16 Schritte ungehört.
- Raus wegen Tempo (0,95× bei 32 / 2,8× bei 8 Schritten) — Requirement 5–10× verletzt.
- Als „vielversprechend“ auch in der April-Eval-Diskussion genannt; im 24l-Vergleich
  nicht ausgewählt.

# Chatterbox / Chatterbox-Turbo

Getestet 29.10.2026 über audio.cpp (`chatterbox_q8_0`, CPU):

```bash
python tools/model_manager_v2.py install chatterbox_q8_0 --models-root=./models/
./audiocpp_cli --task tts --family chatterbox --model ./models/Chatterbox-GGUF \
  --backend cpu --language de --text "Hallo, sag mal etwas zu mir." \
  --voice-ref ../sample.wav --out output.wav
```

Klingt sehr gut, aber Standard-Chatterbox ist zu langsam (ähnlich Qwen3-TTS).
Chatterbox-Turbo: das 350M-Modell kann nur Englisch; offiziell
„Chatterbox Turbo does not support custom voice cloning (only the built-in default
voice)“ → raus. Chatterbox-multilingual 500M existiert, Unterstützung in audio.cpp
unbekannt (ungetestet).

# Kokoro

Offenbar kein Voice Cloning (?) — daher ungeeignet, nicht getestet.

# Runtimes im Detail

## pockettts.cpp + Gateway — gewählt ✅

[github.com/ServeurpersoCom/pockettts.cpp](https://github.com/ServeurpersoCom/pockettts.cpp),
C++17/ggml-Port mit CPU/CUDA/Metal/Vulkan; Tools `pocket-tts` (CLI) und
`tts-server` (OpenAI-kompatibel: `POST /v1/audio/speech` mit `input`, `voice`,
`response_format`, `seed`, `temperature`; `GET/POST/DELETE /v1/audio/voices`).
Arch-Build: `git clone --recurse-submodules` + `./buildvulkan.sh`
(vulkan-headers, spirv-headers, glslang, spirv-tools); Strix-Halo-iGPU wird von
RADV sauber erkannt (Vulkan 1.4, coopmat).

Grenzen ggü. LocalAI: nur `wav`/`pcm` (kein Opus/MP3 — damals Hauptgrund für
LocalAI), registrierte Stimmen nach Neustart weg, ein Modell pro Prozess.
`pcm` streamt s16le während der Generierung. Voice-Registration großer Dateien
via `curl --data @datei` (sonst „Argument list too long“).

Das eigene [`pockettts-gateway/`](pockettts-gateway/README.md) (stdlib-Python +
ffmpeg) ergänzt mp3/opus/aac/flac (ogg-Alias = echtes Opus), codet aus dem
PCM-Stream (echtes Streaming, TTFB 0,02–0,28 s) und bootstraps die
Startup-Registrierung von `lucy`. Zwei bewusst getroffene Designentscheidungen
(29./30.10.):

- **Streaming bleibt erhalten:** durchgehende PCM-/FFmpeg-/HTTP-Pipeline, wartet
  nie auf die vollständige Generierung. Streaming-WAV hat unbekannte RIFF-Längen —
  Clients müssen die Konvention unterstützen (s. Caveat whisper-cli oben).
- **Voice-State ausschließlich im RAM:** keine Persistenz/Restaurierung; beim
  Start wird nur die read-only gemountete `sample.wav` erneut als `lucy`
  registriert (`startup.py`), Backend-Default via `--voice lucy`.

## LocalAI: ehemaliges Produktiv-Setup (bis 30.10.2026)

Abgelöst durch das Gateway (Grund: Qualität + Tempo des 24l-April-Modells auf
Vulkan, s. Benchmarks). Diente als TTS-Sidecar im Hermes-Stack
(`../hermes/compose.yaml`, Dienst `localai`, Image `localai/localai:v4.12.1`);
Modellname `pocket-tts-german` ist bis heute die Drop-in-Kennung des Gateways.
Wesentliche Details, falls das Setup je rehydriert wird:

- Schreibgeschützte Bind-Mounts, nicht in Git, müssen vor dem ersten Start
  existieren (`create_host_path: false` → fehlende Dateien scheitern laut):
  `/srv/llama/models/pocket-tts/german/model.safetensors` + `tokenizer.json` an
  die vom Backend erwarteten HF-Snapshot-Pfade, `sample.wav` → `/references/`
  (außerhalb von `/models`, damit LocalAI sie nicht als Modell listet).
  `HF_HUB_OFFLINE=1` verhindert Downloads; kein HF-Token. `tokenizer.model` wird
  für diesen Checkpoint nicht verwendet.
- Persistente, explizit benannte Volumes: `localai-models`, `localai-backends`,
  `localai-configuration`, `localai-data`. Backend-Auto-Install beim ersten Start
  (dafür Internet). Port: Host 8081 (8080 belegt durch gufo), intern
  `http://localai:8080`.
- Healthcheck prüft nur Server-Bereitschaft, nicht gelungenes Cloning → zur
  Funktionsprüfung immer einen echten `/v1/audio/speech`-Aufruf machen.
- **Codec-Falle:** `response_format:"ogg"` lieferte WAV; `"opus"` lieferte Ogg,
  aber laut ffprobe **Vorbis, nicht Opus** — der Parametername garantiert nicht
  den Codec. (Grund, warum das Gateway explizit `libopus` nutzt.)
- Hermes-Anbindung: `tts.provider=openai` → `http://localai:8080/v1`, Modell
  `pocket-tts-german` (Kommandos im Hermes-README, Abschnitt 6).
- Betrieb: `docker compose stop localai` hält den Rest untouched; `down -v`
  löscht die Volumes (Modell-Dateien unter `/srv` und `sample.wav` nicht).
- Tempo: PocketTTS-Backend setzt selbst 1 Intraop-Thread; kein `threads`-Flag
  gesetzt (der Wrapper garantiert keine PyTorch-Threadzahl).

## audio.cpp

[ghcr.io/0xshug0/audio.cpp:full-cpu](https://github.com/0xshug0/audio.cpp),
getestet 29.10.2026:

```bash
python tools/model_manager_v2.py install pocket_tts_german_q8_0 --models-root=./models/
./audiocpp_cli --task tts --family pocket_tts --model ./models/PocketTTS-GGUF/german \
  --backend cpu --load-option "language=german" --text "Hallo, sag mal etwas zu mir." \
  --voice-ref ../sample.wav --out output.wav
docker run --rm --device /dev/dri -p 8080:8080 \
  --group-add "$(getent group render | cut -d: -f3)" \
  --group-add "$(getent group video | cut -d: -f3)" \
  -v "./models:/models:ro" ghcr.io/0xshug0/audio.cpp:full-cpu \
  server --ui --ui-management --host 0.0.0.0 --port 8080 --backend cpu \
  --model /models/PocketTTS-GGUF/german
```

Sehr schnell, spricht aber manchmal überhastet/komisch/verzerrt (für Lucy/XMPP
dennoch ausreichend befunden). Merkwürdig: Pocket-TTS in der WebUI nicht auswählbar,
CLI funktioniert. Nur WAV-Ausgabe (MP3 evtl. mit Optionen?) → damals der Grund für
den LocalAI-Umweg.

## ONNX (KevinAHM-Demo-Stack)

Lokal reproduziert am 30.10.2026 auf Ryzen 7 PRO 7840U: alle sechs Aufnahmen gut
(INT8, 1 und 8 Steps) — mit zusammenpassenden April-Assets. Diente als Beleg,
dass das Modellpaket (April) der Qualitätsfaktor ist; Erkenntnisse unter
[Checkpoint-Frage](#checkpoint-frage-april-e041936c-vs-jünger) und
[Hypothesen](#hypothesen-warum-die-onnx-demo-gut-klingt). Keine Serving-Basis.

# Material & Fundorte

Persistente Ablagen:

- `/srv/llama/models/pocket-tts/` — alle Modellpakete inkl. Produktion (Konvention
  und Build-Rezept: [`models/README.md`](models/README.md)).
- `~/Desktop/2026-10-30 Pocket-TTS german_24l Test vs. onnx/` — alle 39 Aufnahmen,
  Hörvergleichsseiten (`listen.html`), Skripte, Berichte; u. a.
  `weight-analysis/WEIGHT_COMPARISON.md`, `april-matched/MATCHED_APRIL.md`,
  `april-german-6l/APRIL_GERMAN_6L.md` (36 WAVs per SHA256 unverändert).
- `~/Documents/coding/tts/proben-2026-10-29/` — Test-WAVs, Mess-Skripte,
  LocalAI-Modell-YAML für 24l.
- `~/Documents/coding/tts/modelle/` — April-Checkpoint + April-juergen (ungated,
  `e041936c`; neu ladbar von `kyutai/pocket-tts-without-voice-cloning@e041936c`
  unter `languages/german_24l/model.safetensors` bzw.
  `.../embeddings/juergen.safetensors`, kein Token nötig) und BF16-GGUF
  (Serveurperso) für Präzisionstests. Der April-Tokenizer wurde nie verglichen.
- `~/Documents/coding/tts/pockettts.cpp/build/` — lokaler Vulkan-Build.
- Python-Referenz (4.0.1) reproduzierbar im LocalAI-Image: `docker run` mit
  `localai/localai:v4.12.1`, Volumes `localai-models:/models` +
  `localai-backends:/backends`, `HF_HUB_OFFLINE=1`, Gewichte auf den
  HF-Snapshot-Pfad mounten, dann
  `/backends/cpu-pocket-tts/venv/bin/python` (`TTSModel.load_model(language="german_24l")`).
- STT-Kontrollen: Image `ghcr.io/ggml-org/whisper.cpp:main-d1be6fde…`
  (`/app/build/bin/whisper-cli`), Modell `ggml-small.bin` von
  `huggingface.co/ggerganov/whisper.cpp`.

Flüchtig (tmpfs `/tmp/opencode/`, überlebten keinen Reboot — alle Kernaussagen
stehen hier): `tts-bench/` (30.10.-Mess-WAVs, `bench-final.jsonl`, `bench.py`),
`tts-onset/` (A/B-Material + `listen.html` 22.11.), `onset/` (Sweep-WAVs
inkl. `t0.0-*` für den Upstream-Report, `sample-fix.wav`), `whisper-models/`.
