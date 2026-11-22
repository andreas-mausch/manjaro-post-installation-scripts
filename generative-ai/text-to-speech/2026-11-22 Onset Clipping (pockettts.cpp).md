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
2. **`end_on_pause` für `lucy` prüfen** (offen): Vorverarbeitung von `sample.wav`
   reicht ohne C++-Änderung aus (ffmpeg: trailing silence cut → 20 ms Fade-out →
   80 ms Stille anhängen), z. B. in `startup.py` vor der Registrierung oder einmalig
   an der Referenz. Nach Maßnahme 1 nicht mehr gegen Clipping nötig, aber gegen
   Fortsetzungs-Bursts/falsche erste Wörter; erst nach Hörtest des gepatchten Builds
   entscheiden.

## Nicht betroffen / separat

- **Gateway unschuldig:** reine Byte-Pipe (Backend-PCM → ffmpeg → HTTP-Chunk),
  kein Trimming, keine Stille-Logik. Ein „Stille-Polsterung"-Workaround (Benchmark
  30.10.) wurde nie implementiert und ist auch nicht nötig.
- **Ende-Abschneiden** ist voraussichtlich der separat dokumentierte
  Early-EOS-Effekt (~jeder 3. Lauf, in allen Runtimes; Seed-Lotterie bei
  temp/eos_threshold) — nicht durch diesen Patch behoben. Option: `eos_threshold`
  erhöhen oder Mindestausgabelänge prüfen.
