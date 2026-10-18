docker run --rm \
  --user 1000:1000 \
  --group-add render \
  --device /dev/kfd \
  --device /dev/dri \
  --ulimit memlock=-1 \
  -p 8080:8080 \
  -v /srv/llama/models/Qwen3.8-Flash-Next-125B-A6B:/models/:ro \
  ghcr.io/gufo-org/toolboxes/gufo-runtime:0.17.0 \
  gufo serve llm \
  --model /models/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf \
  --speculative mtp \
  --mtp-model /models/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf \
  --mmproj /models/mmproj-BF16.gguf \
  --context 262144 \
  --max-tokens 8192 \
  --temperature 1.0 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0.0 \
  --presence-penalty 0.0 \
  --host 0.0.0.0 \
  --port 8080
