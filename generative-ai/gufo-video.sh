docker run --rm \
  --user 1000:1000 \
  --group-add render \
  --device /dev/kfd \
  --device /dev/dri \
  --ulimit memlock=-1 \
  -v /srv/llama/models/MiniMax-H3:/models/:ro \
  -v /tmp:/output \
  ghcr.io/gufo-org/toolboxes/gufo-runtime:20260924T104050 \
  gufo video \
  --model /models \
  --preset exact \
  --seed 42 \
  --output /output/output.mp4 \
  --profile \
  "A red fox walking through snow"
