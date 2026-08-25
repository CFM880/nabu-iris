# Source provenance

`kernel-overlay/` was synchronized from the clean Linux worktree at:

```text
repository: https://gitlab.postmarketos.org/soc/qualcomm-sm8150/linux.git
branch:     sm8150/6.14.11
base:       5181e1358ddd6ea8028e841d928942373e6aebc8
snapshot:   8cb100324c8bfff19938cd855e9a5a2276d582a4
date:       2026-08-25
```

The overlay contains every added or modified file between `base` and `snapshot`:

- nabu and SM8150 device-tree integration;
- SM8150 video clock changes;
- media Kconfig/Makefile integration;
- the complete `drivers/media/platform/qcom/iris/` source directory;
- legacy Venus coordination needed by Iris1;
- decode-order output, session recovery and aggregate-load handling;
- DMA-BUF reservation fences and generation-safe capture reuse;
- the unified `cached_capture` option for H.264 and HEVC.

No generated patch files or build artifacts are part of the current source layout.
To update the snapshot, update the Linux source worktree first and then resynchronize all
changed files as one coherent overlay; do not hand-maintain a second patch series.
