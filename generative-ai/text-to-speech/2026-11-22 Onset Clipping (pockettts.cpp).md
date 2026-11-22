# Onset-Clipping in pockettts.cpp (Wortanfänge abgehackt)

Analyse am 2026-11-22. Symptom im Produktivbetrieb (`pockettts-gateway`,
german_24l_april Q8_0, Vulkan, Klon-Stimme `lucy`): **Silben am Wortanfang fehlen**,
gelegentlich auch am Ende von Sätzen.

## Ursache 1 (Hauptverdacht): Upstream wirft den ersten Frame jedes Chunks weg

Commit [`c53c1ff` „Drop the onset frame of every chunk"](https://github.com/ServeurpersoCom/pockettts.cpp/commit/c53c1ffd79bbbb6cc5588907ff9cd8e195ccf578)
(27.09.2026) verwirft in `pt_synthesize` den ersten 80-ms-Frame **jedes** Chunks,
um einen Click des kalten Mimi-Decoders zu entfernen. Beginnt die Sprache in diesem
Frame (passiert regelmäßig, seed- und stimmenabhängig), fehlt der Wortanfang — exakt
unser Symptom. Verifiziert: unser gepinnter Build-Commit `fab7972` (16.10.2026) enthält
`c53c1ff` (`git merge-base --is-ancestor`). Auch Chunk-Übergänge mitten im Satz sind
betroffen, deshalb mal früher, mal später im Audio.

Der Click ist real, kommt aber laut Kyutai vom frischen Decoder-State, nicht vom Frame
selbst. Kyutai hat dasselbe Problem in ihrer Python-Referenz durch
[#332](https://github.com/kyutai-labs/pocket-tts/pull/332)/[#335](https://github.com/kyutai-labs/pocket-tts/pull/335):
**ersten Frame behalten und nur die ersten 5 ms einfaden** (120 Samples), statt ihn zu
verwerfen.

## Ursache 2 (verstärkend): geklonte Stimmen ohne `end_on_pause`

Trainings-Prompts enden immer in einer Sprechpause. Endet ein Voice-Prompt mitten in
der Sprache (out-of-distribution), „setzt das Modell sie fort" → Bursts und
falsche/fehlende Anfangswörter. Kyutai behebt das an der Wurzel in
[#334](https://github.com/kyutai-labs/pocket-tts/pull/334) (`end_on_pause`:
trailing silence schneiden, letzte 20 ms ausfaden, 80 ms Stille anhängen;
Bursts 17/400 → 0/400, One-Word-Treffer 425/480 → 451/480).

`pt_voice_from_audio` in pockettts.cpp (unser Weg für `lucy` via
`POST /v1/audio/voices`) wendet `end_on_pause` **nicht** an. Messungen in
[pockettts.cpp#1](https://github.com/ServeurpersoCom/pockettts.cpp/pull/1):
mit vor-#334-State liegen Sprache in ~31 % der Clips (25/80) im Frame 0,
mit `end_on_pause`-State nur in ~8 %. Die State-Dateien unseres
`-voices.gguf` (juergen/vera) entsprechen ebenfalls dem Vor-#334-Schnitt.

## Status upstream

Der Fix für Ursache 1 existiert als
[pockettts.cpp#1 „Keep the first frame of every chunk, fade in its first 5 ms"](https://github.com/ServeurpersoCom/pockettts.cpp/pull/1)
(`wakamex`, 15.10.2026) — **seit über 5 Wochen Open, nicht gemerged**; die Commits auf
master bis 17.11.2026 sind nur ggml-Rebases und Mimi-Performance. `end_on_pause` für
`pt_voice_from_audio` wurde im PR nur angeboten, nicht implementiert.

## Warum wir nicht auf die Python-Referenz wechseln

Geschwindigkeit (eigene Benchmarks 29./30.10., german_24l):
Python 4.0.1 CPU-f32 ≈ **0,97× Realtime** (unter Realtime), pockettts.cpp CPU
4,5–4,7×, pockettts.cpp Vulkan + Gateway ~6,6×. Python verletzt die Anforderung
„5–10× schneller als Realtime" deutlich. Zusätzlich müssten April-Checkpoint-/
Tokenizer-Rätsel ([Eval 29.10.](2026-10-29%20Model%20Evaluation.md)) und GGUF-Bau
komplett neu gelöst werden. **Wechseln ist keine Option.**

## Unsere Maßnahmen

1. **PR-#1-Fix in unseren Backend-Build übernehmen** (Commit `11fc272`, patcht nur
   `src/pocket.cpp`, device-unabhängig, auf `fab7972` konfliktfrei geprüft):
   `onset-keep-first-frame.patch` im Gateway-Verzeichnis, angewandt im Dockerfile.
   Hinweis: Jeder Chunk wird 80 ms länger (der Frame bleibt erhalten); für den
   Gateway transparent, nur die Audiolänge pro Seed ändert sich.
2. **`end_on_pause` für `lucy` geprüft und NICHT übernommen** (Messung 22.11., s. u.):
   Die Vorverarbeitung (ffmpeg: trailing silence cut → 20 ms Fade-out → 80 ms Stille
   anhängen) zeigte seed-identisch keine Wirkung — `sample.wav` endet bereits nach
   ~133 ms Stille, also nahe einer Sprechpause, damit fehlt der Effekt aus #334.

## Ergebnis 2026-11-22: Deployment + STT-Messung

- **Patch deployed:** Image `local/pocket-tts-vulkan:fab7972-onset1` läuft. Seed-gleich
  ist jede Aufnahme exakt 80 ms länger; die verworfenen Frames enthielten hörbares
  Material (RMS ≈ −25 dB, keine Stille). A/B-Material + `listen.html`:
  `/tmp/opencode/tts-onset/` (tmpfs, überlebt keinen Reboot).
- **STT-Kontrolle** (whisper.cpp `small`, Image `ghcr.io/ggml-org/whisper.cpp:main-d1be6fde`,
  8 Seeds): Restfehler bleiben — „Es ist 13:05 …" wird in 2/8 Seeds zu „Das ist…"/fehlt,
  „Okay, los geht's" trifft „Okay" in 4/8 Seeds. Seed 4 produziert degenerate Ausgaben
  (whisper halluziniert „Copyright WDR 2020") über alle Voices/Temperaturen.
- **`end_on_pause`-Experiment:** `sample.wav` (44,1 kHz stereo) als `lucyfix` mit
  vorverarbeitetem Ende registriert → transkript-identisch zu `lucy` pro Seed, kein
  messbarer Nutzen. **Nicht übernommen**; `startup.py` bleibt unverändert.
- **Temperatur 0,4** vs. Standard: 5/8 vs. 4/8 „Okay" — bei n=8 kein clear winner.
- **Einordnung:** Die verbleibenden Anfangsfehler sind Modell-Lotterie bei kurzen
  Texten, kein Runtime-Bug mehr — Kyutai misst selbst nach allen Fixes (#334) noch
  ~6 % Fehlstarts bei Ein-Wort-Texten. Denkbare Gegenmittel wären Retry-Strategien
  (Output-Länge/ASR gegen den Input prüfen) oder längere Eingaben; das wäre Aufgabe
  einer Konsumenten-Schicht, nicht des Backends.

## Update (22.11., abends): Fehlerklassen, Sampler-Sweep, Verhältnis zu den Online-Demos

Zwei Fehlerklassen sauber trennen:

1. **Runtime-Bug (war pockettts.cpp, behoben):** konstantes Onset-Clipping durch den
   Frame-Drop (Ursache 1). Die Online-Demos liefen nie mit diesem Bug.
2. **Modell-Lotterie (nicht fixbar, nur abfederbar):** kurzes erstes Wort wird
   übersprungen/ersetzt. Zeigt sich in **allen** Runtimes: Kyutai misst nach allen
   Fixes noch ~6 % Fehlstarts (Ein-Wort-Texte), und unser eigener Python-4.0.1-Lauf
   vom 30.10. auf April-Gewichten verlor bei Seed 202 „Es ist" — ohne eine Zeile
   cpp-Code. wakamex belegte zudem Frame-Äquivalenz des Ports gegen F32-Referenz.

**Sampler-Sweep** (Voice lucy, gepatchter Build, whisper.cpp small, 8 Seeds):

| Einstellung | s1 „Es ist…" | s3 „Okay…" | Bemerkung |
|---|---|---|---|
| Standard | 6/8 | 4/8 | Referenz |
| + end_on_pause (lucyfix) | 5/8 | 4/8 | seed-identische Transkripte → kein Effekt |
| temperature 0,4 | — | 5/8 | kein clear winner |
| temperature 0,1 | 6/8 | 5/8 Onset | Satzmitte degeneriert („Okay, no skates") |
| temperature 0,0 | degenerate | degenerate | s1 bricht nach „Das ist 1305." ab → **greedy-Kollaps, vermutlich Port-Bug**, upstream meldbar |

Caveat: whisper small ist konservativ; „Das ist" kann sich korrekt anhören (Ende-Abschneiden
hören ist aber bestätigt).

**Warum die Online-Demos „perfect" wirken, obwohl Klasse 2 überall existiert:**
(1) kuratierte, nach-#334-regenerierte Voice-States statt Hausklon `lucy` und
Vor-#334-GGUF-States; (2) neuere/andere Modellpakete bzw. beim ONNX-Demo möglicherweise
anderes Sampler-/EOS-Verhalten (Hypothese 1 aus dem [Eval 29.10.](2026-10-29%20Model%20Evaluation.md));
(3) der Mensch drückt bei versemmelter Antwort einfach erneut Generate — genau die
Retry-Schicht, die uns im automatischen Betrieb fehlt; (4) Demo-Texte sind meist volle
Sätze, die Lotterie trifft vor allem Kurzantworten.

## Offene Experimente (Entscheidungshilfe Modellwechsel)

1. **`german_2026-09_24l` (Serveurperso-GGUF Q8_0, liegt unter
   `/srv/llama/models/pocket-tts/german_2026-09_24l/`) auf dem gepatchten Stack** mit den
   s1/s3-Seeds 1–8 + Hörtest — entscheidet „unser konkretes Modell?" und ist zugleich
   der im Benchmark-Doc vermerkte offene Gegenhörtest April vs. 2026-09. Aufwand ~10 min.
2. **Python-`main` (nach allen Fixes) + April-Weights + `sample.wav`-Klon + Seed** —
   entscheidet „Port?". Aufwand ~1 h, Assets vorhanden.
3. Optional: greedy-Kollaps bei temperature 0 als Issue an ServeurpersoCom/pockettts.cpp
   melden (mit Repro `t0.0-*.wav`).

## Entscheidung (22.11., Andreas)

Der gepatchte April-Stack läuft unverändert weiter; keine Verifikations-/Retry-Schicht
(ASR-Roundtrip + Seed-Retry wäre machbar, ~87–99 % Erfolg in 3 Versuchen, wurde aber
nicht gebaut). Wenn eh ein Modellwechsel ansteht, zuerst Experiment 1 fahren und
gegen den Zahlen-/Englisch-Nachteil der neueren Pakete abwägen; Class-2-Fehler
(„Okay" verschluckt) gelten bis dahin als hingenommene Modelleigenschaft.

## Nicht betroffen / separat

- **Gateway unschuldig:** reine Byte-Pipe (Backend-PCM → ffmpeg → HTTP-Chunk),
  kein Trimming, keine Stille-Logik. Ein „Stille-Polsterung"-Workaround (Benchmark
  30.10.) wurde nie implementiert und ist auch nicht nötig.
- **Ende-Abschneiden** ist voraussichtlich der separat dokumentierte
  Early-EOS-Effekt (~jeder 3. Lauf, in allen Runtimes; Seed-Lotterie bei
  temp/eos_threshold) — nicht durch diesen Patch behoben. Option: `eos_threshold`
  erhöhen oder Mindestausgabelänge prüfen.
