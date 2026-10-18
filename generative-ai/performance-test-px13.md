# Power-Profile vs. LLM-Inferenz – ASUS ProArt PX13

**Datum:** 2026-09-26 · **Gerät:** ASUS ProArt PX13 (HN7306EAC), AMD Ryzen AI Max+ 395
(Radeon 8060S), 128 GB unified memory, `gfx1151`, CachyOS
**Engine:** gufo v0.2.0 · Qwen3.8-Flash-Next `UD-Q4_K_XL` + shared-Q8_0-MTP-Sidecar, adaptives MTP,
Prefix-Cache im RAM · Session-Kontext wuchs während der Messungen von ~20k auf ~66k Tokens

## Methodik

- **Power:** `power1_average` des `amdgpu`-hwmon (Package Power = CPU+GPU+NPU+MC),
  30 Samples/1 s während einer ~1000-Token-Generierung.
- **Durchsatz:** `decode_tps`, `prefill_tps`, `ttft_ms`, `draft_accepted/proposed` aus den
  gufo-HTTP-Logs.
- **MTP-Bereinigung:** `Pässe = generierte Tokens − akzeptierte Draft-Tokens`;
  Pässe/s ist die akzeptanzunabhängige Rohrate.
- Profile via `platform_profile` (asus_wmi); Profile wurden manuell gewechselt.

## Hauptergebnis

| Profil | PPT Idle | PPT Decode | Cap? | Pässe/s (norm.\*) | relativ | Prefill tok/s¹ | Generation tok/s² | J/PASS | J/Token |
|---|---|---|---|---|---|---|---|---|---|
| `quiet` | 13 W | **40 W** | ja (flach) | ~12.7 | 89 % | ~536 | 25.3 | **3.09** | **1.58** |
| `balanced` | 15 W | **50 W** | ja (flach) | ~13.4 | 94 % | ~702 | 29.1 | 3.70 | 1.72 |
| `performance` | 52 W | **55 W** | nein (Demand) | 14.3 | 100 % | ~800–970 | 27.8–31.3 | 3.85 | 1.98 |

\*) normiert auf ~63k Kontext gemäß AR-Benchmarktabelle (2–5 % Kontext-Penalty)
¹) große Prefill-Chunks (~1.3–5k neue Tokens); kleine Chunks sind ineffizient und nicht vergleichbar
²) lange Antworten; **stark von der MTP-Akzeptanz abhängig (60–67 % hier) – nur bedingt vergleichbar!**

## Rohdaten (lange Antworten, Profile direkt verglichen)

| Req | Profil | Kontext | Tokens | Akzeptanz | decode_tps | Pässe/s | prefill_tps | TTFT |
|---|---|---|---|---|---|---|---|---|
| r99 | quiet | 50.3k | 1090 | 65.6 % | 25.3 | 12.95 | 536 | 2.76 s |
| r105 | balanced | 58.6k | 1091 | 66.7 % | 29.1 | 13.51 | 702 | 2.07 s |
| r108 | performance | 63.3k | 1129 | 60.3 % | 27.8 | 14.31 | (kleiner Chunk) | 0.81 s |
| r110 | performance | 66.1k | 1935 | 60.9 % | 29.2 | 13.78 | 803 | 1.84 s |

## Erkenntnisse

1. **TDP der Linux-Profile (PX13):** `quiet` ≈ 40 W, `balanced` ≈ 50 W, `performance` = 70 W SPL.
   Die ersten beiden Werte waren so nirgends dokumentiert (Kernel/PMF exponieren keine Zielwerte);
   Reviews nennen nur 55/70/95 W für die Windows-Presets.
2. **Die 70 W werden beim Decoding nie erreicht:** Demand-Limit ~55 W. Idle allein zieht in
   `performance` schon 52 W (Takt fixiert) → Last kostet nur +3 W, der Verbrauch ist statisch dominiert.
3. **Decode ist weitgehend power-immun:** 89 → 100 % Rohrate bei +38 % Watt.
   MTP macht Decoding nur leicht compute-abhängig; reines AR wäre vermutlich komplett immun.
4. **Prefill skaliert fast linear mit den Watt** (~536 → 702 → 800–970 tok/s) und landet
   vollständig auf dem TTFT – das ist im Alltag der spürbarste Profil-Unterschied.
5. **Effizienz-Monotonie:** J/PASS und J/Token werden mit jedem aggressiveren Profil schlechter.
   `quiet` ist der Effizienzsieger (~25 % weniger J/PASS als performance), `balanced` für
   LLM-Workloads der objektiv schlechteste Punkt der Kurve.
6. **Akzeptanzrate ist Text-abhängig:** kurze formelhafte Antworten trafen 79–89 %
   (→ 42–44 tok/s!), lange freie Texte nur 60–67 %. Rohe decode_tps-Werte sind ohne
   Akzeptanzangabe wertlos.

## Empfehlung

- **Netzteil / interaktiv:** `performance` (TTFT-Vorteil, Idle-Watt irrelevant)
- **Akkubetrieb:** `quiet` (81 % Tempo bei 72 % Decode-Watt und 13 statt 52 W Idle)
- **`balanced`:** vermeiden für LLMs

## Quellen & Grenzen

- Review-Werte (55/70/95 W): [Ultrabookreview, ProArt PX13 2026](https://www.ultrabookreview.com/74980-asus-proart-px13-gopro-review)
- Referenz-Benchmarks (120-W-Desktop, greedy, tg128): [gufo BENCHMARKS.md](https://github.com/gufo-org/gufo/blob/main/docs/models/qwen3.8-flash-next/BENCHMARKS.md) – dort ist **kein TDP dokumentiert** (Doku-Lücke)
- Grenzen: n=1 pro Profil, gemischter Chat-Text statt standardisierter Korpora, Kontext wuchs
  über die Session, hwmon-Mittelung ~1 s, decode_tps MTP-abhängig (siehe Tabelle)