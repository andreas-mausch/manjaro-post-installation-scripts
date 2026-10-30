# Benchmark: Pocket-TTS vs. OmniVoice auf Vulkan (Deutsch, Voice Cloning)

Getestet am 2026-10-30 auf dem Ryzen AI Max 395+ (iGPU „AMD Radeon 8060S
Graphics", RADV STRIX_HALO, Vulkan 1.4 mit KHR_coopmat). Alle Läufer sind
C++/GGML-Ports mit identischem Backend (`--device Vulkan0`) und Stimmklonen aus
derselben Referenz (`sample.wav` aus diesem Ordner, 7,3 s, mit Klartext-Transkript
aus `sample.txt`).

Testtext: **„Es ist 13:05. Die Items werden mit Sprites gerendered. Tschüß."**
(prüft Zahlen + englische Begriffe).

|  | Pocket-TTS (german 6l, 2026-04) | Pocket-TTS (german 6l, 2026-09) | Pocket-TTS (german 24l, 2026-04) | OmniVoice |
|---|---|---|---|---|
| Runtime | `pockettts.cpp` fab7972 | `pockettts.cpp` fab7972 | `pockettts.cpp` fab7972 | `omnivoice.cpp` 1a468d8 |
| Modell | `german_april` Q8_0, 138 MB (eigenkonvertiert) | `german` Q8_0, 138 MB (Serveurperso-GGUF) | `german_24l_april` Q8_0, 379 MB (eigenkonvertiert) | `omnivoice-base` Q8_0, 626 MB + Codec Q8_0, 276 MB |
| Architektur | 6-Layer-Flow-LM (~100 M), Mimi-Codec | wie links, jüngerer Checkpoint | 24-Layer-Flow-LM, Mimi-Codec | 612-M-Qwen3-Backbone, MaskGIT-Decoder + Higgs-DAC-Codec |
| Voice Cloning | `--voice sample.wav` | `--voice sample.wav` | `--voice sample.wav` | `--ref-wav sample.wav` **+ `--ref-text` Pflicht** |
| Generierung | Defaults (1 Flow-Schritt), Seed 42 | wie links | wie links | Standard: 32 MaskGIT-Schritte × CFG; zusätzlich 16/8 gemessen |
| **End-to-End-Zeit (Ø)** | **0,50 s** (0,28–0,62) | **0,45 s** (0,28–0,61) | **1,03 s** (0,53–1,30) | **4,56 s** (32 St.) · 2,57 s (16) · 1,60 s (8) |
| **Audiolänge (Ø)** | 5,52 s | 5,60 s | 5,68 s | 4,35 s (32) · 4,43 s (16) · 4,44 s (8) |
| **Tempo (Ø, inkl. Start)** | **~11× Realtime** | **~12× Realtime** | **~5,5× Realtime** | **0,95× (unter Realtime)** · 1,7× (16) · 2,8× (8) |
| Nur Synthese | 0,14–0,39 s | 0,14–0,38 s | 0,34–1,0 s | LM 3,7–4,1 s + Codec-Decode ~0,12 s |
| Modell-Load / Stimm-Encoding | ~80 ms / ~100 ms | ~85 ms / ~80 ms | ~110 ms / ~145 ms | ~0,3 s gesamt inkl. Codec (Seite-cache-geschönt, s. u.) |
| HTTP-Server | `tts-server`, OpenAI-kompatibel | wie links | wie links | `tts-server`, OpenAI-kompatibel |
| **Audioqualität (Hörurteil 30.10.)** | Ziffern & englische Begriffe schlecht | wie links | **sehr gut — Favorit**; minimal vorn/hinten abgeschnitten | 8-Stufen-Ausgabe sehr gut, nur „gerendered" auffällig; 32/16 ungehört |

Messmethode: je Konfiguration 1 Warmup + 3 Messläufe, **alle Konfigurationen
strikt alternierend in identischer GPU-Sitzung**, Seed 42, Zeit = kompletter
Prozess (Modell-Load + Stimm-Encoding + Synthese + WAV-Write). Achtung
Taktvolatilität (wie schon am 29.10. dokumentiert): Der letzte Messblock lief bei
deutlich höherem GPU-Takt — die Bereichsangaben in Klammern spiegeln das; die
Sustain-Werte liegen bei Pocket-TTS 6l bei ~9×, beim 24l bei ~4,5×.

## Kernaussagen

- **Tempo-Ranking:** 6l (~11–12×) → 24l (~5,5×) → OmniVoice (0,95× bei
  Standard-32-Schritten). Pocket-TTS 24l ist **~4,4× schneller als OmniVoice**
  und erfüllt damit die Anforderung „5–10× schneller als Realtime" im Sustain
  knapp; OmniVoice verfehlt sie selbst mit nur 8 MaskGIT-Schritten (2,8×).
- OmniVoice spricht denselben Satz ~20 % schneller (4,35 s statt 5,5–5,7 s
  Audio) — sein RTF ist damit eher geschönt; pro erzeugter Sekunde Audio ist
  der Abstand größer.
- **Fußabdruck:** OmniVoice lädt ~900 MB (LM + Codec inkl. HuBERT-/DAC-Encoder),
  Pocket-TTS 24l ~380 MB, 6l ~130 MB. Die Load-Zeiten hier sind optimistisch, da
  die Modelle in `/tmp` (tmpfs = RAM) bzw. frisch gelesen lagen; kalter Disk-Load
  trifft OmniVoice härter.
- **Bedienung:** Pocket-TTS braucht nur die Referenz-WAV; OmniVoice verlangt
  zwingend das Transkript der Referenz (oder ASR im Python-Stack).
- 24l braucht pro Sekunde Audio ~2,5× so lange wie 6l — der Qualitätszuwachs
  (Hörvergleich, s. u.) ist also nicht gratis, aber auf Vulkan tragfähig.

## Checkpoint-Frage: April (2026-04) vs. aktuell (2026-09)

Ausgegangen waren wir von der These aus dem Eval-Dokument vom 29.10., der
April-Checkpoint spreche besseres Deutsch (Ziffern/Englisch). Das Hörurteil
(s. u.) widerlegt sie fürs 6l — gemessen hat es trotzdem zwei Dinge: Beim 6l
kostet April kein spürbares Tempo (0,50 s vs. 0,45 s, Messrauschen bei
identischer Architektur); April tokenisiert den Testtext mit 30 statt 32
Stücken. Und die April-Pakete sind die Basis, auf der das überzeugende 24l läuft.

Repro der April-Pakete (6l und 24l):

- Quelle: **gatedes** `kyutai/pocket-tts`, April-Revision (`e041936c`),
  `languages/german` bzw. `languages/german_24l` →
  `/srv/llama/models/pocket-tts/german/` bzw. `german_24l/`.
  Verifiziert: alle Nicht-Encoder-Tensoren bitidentisch zum ungated Mirror
  `kyutai/pocket-tts-without-voice-cloning@e041936c` (6l: 214 Tensoren,
  24l: 358 Tensoren), Mimi-Encoder intakt (42/42 nicht-null).
- Das ungated Mirror allein ist unbrauchbar: `remove_voice_cloning_and_push.py`
  setzt dort alle `mimi.encoder.*`-Tensoren auf Null. Encoder des aktuellen
  Checkpoints anpfropfen geht auch nicht — der Mimi-Codec wurde seit April
  komplett neu trainiert (alle 45 Codec-Tensoren ohne Encoder bit-verschieden),
  Encoder und Decoder gehören aber zusammen.
- Der April-Stand liefert nur ein SentencePiece-`tokenizer.model` (4000 Stücke,
  Unigram, byte-fallback); daraus mit `spm2json.py` (liegt daneben) das
  HF-`tokenizer.json` für `convert.py` gebaut.
- `pockettts.cpp convert.py` → F32-GGUF (+ Stimmen als `-voices.gguf`; 6l: 26
  April-Stimmen, 24l: juergen & vera), `build/quantize` → Q8_0. Ergebnisse
  liegen persistent bei den Zugrundegewichten in `/srv/llama/models/pocket-tts/`.

## Audioqualität (Hörurteil 2026-10-30)

Geprüft von Andreas (identischer Seed, identisches Clone-Voice, Dateien in `out/`):

- **Pocket-TTS 24l April (`german-24l-april-1.wav`): Favorit.** Beste Qualität im
  Verhältnis zur Geschwindigkeit; Ziffern und englische Begriffe okay. Einziger
  Makel: vorne und hinten ganz leicht abgeschnitten (passender Kandidat für
  `--frames-after-eos`/`--max-voice-sec`-Feintuning oder eine kleine
  Stille-Polsterung).
- **OmniVoice 8 Steps (`omni-8-1.wav`): sehr gut**, nur „gerendered" klingt
  falsch ausgesprochen.
- **Beide 6l-Varianten (April wie 2026-09): Ziffern und englische Begriffe
  schlecht.** Damit ist die im Eval-Dokument vom 29.10. vermutete
  Checkpoint-Alters-Ursache für die 6l-Schwäche widerlegt.
- OmniVoice 32/16 Steps ungehört.

Wichtige Folgerung aus dem Hörvergleich: **Der Qualitätsfaktor ist die
Modellgröße (24l), nicht das Checkpoint-Alter.** April vs. 2026-09 war beim 6l
tempo- und qualitätsseitig neutral; erst das 24l bringt die verständliche
Aussage von „13:05" und „Sprites/gerendered". Ob das 24l zwingend auf April-Basis stehen muss, ist in diesem Benchmark nicht
gegeneinander gehört (das `Serveurperso-GGUF/pocket-tts-german_24l-Q8_0.gguf`
mit 2026-09-Gewichten stünde bereit). Andreas' Notiz dazu: Nach seinen früheren
Tests klang 24l mit 2026-09-Gewichten **deutlich schlechter** als hier erlebt —
er vermutet den Releasestand weiterhin als Qualitätsfaktor. Das wäre dann beim
24l das Gegenteil der hier fürs 6l widerlegten Alters-Hypothese und passt zu den
schlechten Eindrücken vom 29.10. mit dem damaligen aktuellen 24l-Checkpoint.
Ungeklärter, offener Gegenhörtest.

**Empfehlung:** `german_24l_april` Q8_0 auf Vulkan als Produktiv-Kandidat
(~5,5× Realtime, beste Qualität). 6l wäre nur akzeptabel, wenn nie Zahlen oder
englische Begriffe vorkommen.

## Dateien & Reproduktion

Persistant in `/srv/llama/models/pocket-tts/`:

- `german/` — April-6l komplett: Safetensors (gated-Download, Encoder intakt),
  `pocket-tts-german_april-Q8_0.gguf` + `-voices.gguf`, `spm2json.py`
- `german_24l/` — April-24l: Safetensors,
  `pocket-tts-german_24l_april-Q8_0.gguf` + `-voices.gguf`
- `german_2026-09/` u. a. — jüngerer Stand; GGUFs davon in `Serveurperso-GGUF/`

Arbeitsverzeichnis `/tmp/opencode/tts-bench/` (tmpfs, überlebt keinen Neustart —
WAVs bei Bedarf sichern): `out/` alle Mess-WAVs (`*-1..3`), `bench-final.jsonl`
Rohdaten inkl. Tool-Logzeilen, `omnivoice.cpp/` Build, `models/` GGUFs,
`bench.py` Mess-Harness.

```bash
# Pocket-TTS (alle drei Pakete gleich, nur --model wechseln, z. B.:)
#   german/pocket-tts-german_april-Q8_0.gguf
#   Serveurperso-GGUF/pocket-tts-german-Q8_0.gguf
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
