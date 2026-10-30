# Pocket-TTS German model files

Everything under `/srv/llama/models/pocket-tts/` (not in git, like the other
model stores). Convention: **each GGUF lives next to the source weights it was
converted from.**

| Directory | Contents |
|---|---|
| `german/` | April 2026 6l checkpoint (gated `kyutai/pocket-tts`) + self-converted `pocket-tts-german_april-Q8_0.gguf` / `-voices.gguf` + `spm2json.py` |
| `german_24l/` | April 2026 24l checkpoint + self-converted `pocket-tts-german_24l_april-Q8_0.gguf` / `-voices.gguf` |
| `german_2026-09/` | Current public 6l pack + Serveurperso GGUFs |
| `german_2026-09_24l/` | Current public 24l pack + Serveurperso GGUFs |

Production consumes the April 24l GGUFs via
[`../pockettts-gateway/`](../pockettts-gateway/); quality/speed comparison of
all packs: [`../2026-10-30-benchmark.md`](../2026-10-30-benchmark.md).

## Why the April GGUFs are self-converted

The ungated mirror of the April release (`ServeurpersoCom/kyutai-pocket-tts-april`)
ships with **all `mimi.encoder.*` tensors zeroed** — voice cloning does not work
with it. The encoder cannot be grafted from a newer checkpoint either: the Mimi
codec was fully retrained since April (all 45 non-encoder codec tensors differ).

So the April weights were downloaded from the gated `kyutai/pocket-tts` repo at
commit `e041936c` (needs an HF token) and verified bit-identical to the mirror
except for the encoder (42/42 encoder tensors non-null there).

## Build recipe (6l shown; 24l is identical with `german_24l`)

1. Build pockettts.cpp at the pin used by the gateway image:

   ```sh
   git clone https://github.com/ServeurpersoCom/pockettts.cpp && cd pockettts.cpp
   git checkout fab7972
   cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j
   ```

   Arch build deps (same list as `../pockettts-gateway/Dockerfile`):
   `base-devel cmake git pkgconf python glslang spirv-headers spirv-tools
   vulkan-headers vulkan-icd-loader shaderc`. This also builds `build/quantize`.

2. Materialise the checkpoint layout convert.py expects
   (`checkpoints/pocket-tts/languages/german/` for the 6l pack, `german_24l`
   for the 24l pack — the language rules resolve via the `_`-prefix):

   ```text
   languages/german/model.safetensors     (gated download, commit e041936c)
   languages/german/tokenizer.json        (April ships only tokenizer.model:
                                            python spm2json.py tokenizer.model tokenizer.json)
   languages/german/embeddings/*.safetensors   (predefined voices: juergen, vera)
   ```

   `spm2json.py` needs the `sentencepiece` package; it refuses to run if
   `byte_fallback` is off (convert.py would assert on such a tokenizer).

3. Convert and quantize (convert.py needs `numpy` + `gguf`, no arguments):

   ```sh
   python convert.py                     # -> models/pocket-tts-german-F32.gguf + -voices.gguf
   ./build/quantize models/pocket-tts-german-F32.gguf \
       models/pocket-tts-german_april-Q8_0.gguf Q8_0
   ```

4. Move the two GGUFs next to the weights under `/srv` (see table above) and
   restart the gateway container.

Note: the GGUFs carry `pocket.gen.frames_after_eos = -1` (auto, from the text)
and `pocket.gen.temperature = 0.3` — identical to Serveurperso's official
packs, i.e. no hidden generation defaults were changed.
