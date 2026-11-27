# AI: Gufo and model weights

[Project overview](../README.md). AI/Full install a manually started, localhost-only Gufo service; weights are optional
during installation and are not part of the installed system's package closure.

## Service

```bash
sudo systemctl start gufo
sudo journalctl -u gufo -f
sudo systemctl stop gufo
```

The service does not start at boot and is not exposed on the LAN. Its OpenAI-compatible API is
`http://127.0.0.1:8080/v1`, with model name `flash-next`. Configuration uses one session, 32,768-token context and MTP;
the image projector is automatically located beside the model. Stop the service before demanding games to release
GPU/model memory. Run `gufo diagnose` on actual target hardware.

The lock-selected Gufo build uses a ROCm `gfx1151` backend. Other GPUs need a suitable backend/build, and memory/context settings
must fit the actual device. Installation or `gufo --version` is not inference evidence; real hardware or passthrough
testing remains [open](issues/2026-11-25_gufo-hardware-backend-validation.md).

## Files and integrity

[`modules/generative-ai/models.lock.json`](../modules/generative-ai/models.lock.json) pins six Qwen3.8-Flash-Next files,
including the Q8_0 MTP sidecar and BF16 image projector. The Flake checks exact equality with the lock-selected Gufo
manifest. AI/Full ISO builds download roughly 115 GB (107 GiB) and verify pinned SHA-256 checksums; copying needs no
network. No automatic model-update timer exists. Flake/package updates do not update the manifest or installed weights.

The accepted strategy is pinned download checksums plus successful copying, without another checksum pass on the target.
Copy progress measures bytes, not checksums or durable writes. Manifest trust and model licenses are separate concerns.
See [model-deployment ADR](decisions/0004-model-deployment.md).

## Directory layout

`generative-ai.models.directory` defaults to `/var/lib/generative-ai/models` and is shared by Gufo, directory rules and
installer copying. Original Hugging Face filenames are preserved:

```text
/var/lib/generative-ai/models/
└── text-generation/Qwen3.8-Flash-Next/
    ├── UD-Q4_K_XL/    # Four GGUF shards
    ├── MTP/          # MTP sidecar
    └── …             # Image projector directly in the Qwen directory
```

`generative-ai.models.text-generation.directory` derives from the model root;
`generative-ai.models.text-generation.qwen38FlashNext.directory` derives from it. Paths must be canonical absolute
paths without spaces, with each child inside its parent. Gufo uses the explicit first GGUF shard and MTP file paths,
not a model alias. Changing options does **not** move existing weights; relocate them and preserve permissions.

If copying was declined, provide the pinned file set in this layout before starting inference. Downloading the six
manifest files separately is possible; verify checksums. `gufo model install flash-next-q4` uses Gufo's alias-based
layout and does not directly replace this procedure. Independent local/alternative build-time sourcing is future work.
For interrupted installer copying, follow [safe recovery](troubleshooting.md#retry-model-copying-without-reinstalling).
