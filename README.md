# Xiaomi Pad 5 Iris v154 + FFmpeg DRM PRIME v11

This bundle targets the Xiaomi Pad 5 (`nabu`, SM8150) running Ubuntu with
kernel `6.14.11-nabu-iris1+` and the distribution mpv 0.41 / FFmpeg 8 ABI.
The directory and private userspace install root retain the historical
`nabu-iris-v140-drmprime-v11` name so existing installations continue to work;
the supplied Iris driver itself is v154.

It contains the complete matching kernel stack and the patched userspace:

- A bootable ARM64 UKI copied from the validated tablet's active rEFInd v44
  entry. Its embedded kernel is exactly `6.14.11-nabu-iris1+ #2`, and its
  embedded Image and nabu DTB match the separately supplied files byte for
  byte.
- The complete 762-module tree for that kernel, with the Iris v154 driver.
  Iris v154 preserves the kernel-only in-place seek handling, stabilizes
  concurrent legacy VPU5 decoding, and rejects aggregate loads above the
  SM8150 4K120 decode budget before firmware buffer allocation.
- The exact Qualcomm Venus VPU firmware used by the validated tablet,
  installed as `/lib/firmware/qcom/sm8150/xiaomi/nabu/venus.mbn`.
- Patched FFmpeg `libavcodec.so.62.11.100`: exports V4L2 decoder CAPTURE
  buffers with `VIDIOC_EXPBUF` and exposes them as `AV_PIX_FMT_DRM_PRIME`.
  It intentionally contains no V4L2 decoder flush/reopen callback; seek is
  handled by the kernel driver.

The patched library is installed privately and is selected only by the
provided `mpv-iris` wrapper. It does not overwrite files under `/usr/lib`.

## Compatibility

- Hardware: Xiaomi Pad 5 (`nabu`, SM8150 / Iris1).
- Kernel: supplied bootable `6.14.11-nabu-iris1+ #2` UKI, Image, nabu DTB,
  config, System.map, and complete matching module tree.
- Userspace ABI: FFmpeg 8 with `libavcodec.so.62.11.100`, mpv 0.41.
- Tested codecs in the launcher: H.264, HEVC, and VP9 Profile 0, NV12 output.
- Display: Wayland compositor supporting Linux DMA-BUF and linear NV12.
- VPU firmware SHA-256:
  `9d4af65d7ede845e900f1b29ff425b7a8e2947056e695e246e58a2091445a085`.

Do not install the binary kernel module on a different kernel. The exact source
base and complete patch order are documented below.

## Kernel source base and commit chain

The supplied kernel and modules are based on the `v6.14.11-sm8150` nabu tree:

```text
repository: https://gitlab.com/andrewgigena/sm8150-mainline.git
base tag:   v6.14.11-sm8150
base commit: 5181e1358ddd6ea8028e841d928942373e6aebc8
```

Apply the ten patches under `kernel/complete-patch-series/` in filename
order. They correspond to this exact commit chain:

```text
1282863aa  WIP: bring up Iris1 hardware video decode on nabu
24ea16525  WIP: advance Iris1 VP9 output buffer setup
60bab4f40  media: iris: keep legacy VPU5 runtime active
f72250318  media: iris: stabilize legacy VPU5 H.264 playback
aff8f1924  media: iris: fix legacy VP9 output extradata pointer
dbddec388  media: iris: release stopped-session internal buffers
02801cb5b  media: iris: add hardware encoding support
d11d0332a  media: iris: harden session reuse and legacy seeks
138265716  media: iris: stabilize concurrent legacy VPU5 decoding
a88b5d6f4  media: iris: bound legacy VPU5 aggregate load
```

The precise driver source state is commit
`a88b5d6f47e73df7d819b2661745bc1c854560e2`. For a tree already at
`d11d0332abe3dd4613a173523b8b26442ce051a3`, the equivalent cumulative update
is `kernel/iris-v154.patch`. The UKI embeds the validated `#2` kernel Image;
Iris is a separately installed module built from the v154 source state.

Rebuild from source with:

```sh
git clone https://gitlab.com/andrewgigena/sm8150-mainline.git
cd sm8150-mainline
git checkout 5181e1358ddd6ea8028e841d928942373e6aebc8
git am /path/to/kernel/complete-patch-series/*.patch
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=out-iris1 -j8 modules
```

`kernel/base-patches/` contains the last six historical milestone patches for
reference; it is not the complete series and should not be used alone to
reconstruct the driver.

## Install on a tablet already running the matching kernel

Install the driver first:

```sh
sudo ./install-driver.sh
```

Then install the private FFmpeg library and desktop launcher as the desktop
user, without `sudo`:

```sh
./install-user.sh
```

Start from the application menu as `MPV (Iris hardware decoding)`, or run:

```sh
~/.local/bin/mpv-iris VIDEO_FILE
```

## Install the supplied kernel on another nabu tablet

First mount the tablet's `ESPNABU` partition read-write. On the validated
layout it is `/dev/sda31`:

```sh
sudo mkdir -p /mnt/esp-nabu
sudo mount /dev/disk/by-label/ESPNABU /mnt/esp-nabu
sudo ./install-kernel.sh /mnt/esp-nabu
```

The script installs the complete module tree, the validated `venus.mbn`, and adds
`EFI/ubuntu/6.14.11-nabu-iris1-v154-drmprime.efi`. It does not overwrite the
existing v38/v44 UKIs and does not change rEFInd's default selection. Reboot,
select the new entry, and verify the reported kernel and Iris hash before
installing the per-user FFmpeg component:

```sh
uname -a
sha256sum /lib/modules/6.14.11-nabu-iris1+/kernel/drivers/media/platform/qcom/iris/qcom-iris.ko
./install-user.sh
```

Expected Iris SHA-256:
`406f6da1283d3f8ff4e406c1c9a9116dbea8c70a17f3e0bb716d452152009230`.
Keep the old rEFInd entry as the recovery path until the new entry has been
validated. See `kernel/boot/ORIGIN.md` for exact UKI provenance and hashes.
The firmware is copied unmodified from `xiaomi-nabu-firmware 1.0`; see
`firmware/NOTICE.md` for its provenance and redistribution notice.

## Verify

The decoder log should contain all of the following:

```text
V4L2 decoder output: DRM PRIME (exported DMA-BUF)
Using device /dev/video0
Using hardware decoding (v4l2m2m)
Decoder format: ... drm_prime[nv12]
VO: [dmabuf-wayland] ... drm_prime[nv12]
```

It must not contain `reopening V4L2 decoder for flush`.

## Validation status and known limits

This is an experimental bring-up bundle, not a general Ubuntu kernel. On the
validated tablet, H.264, HEVC, and VP9 used the Iris V4L2 decoder, exited
cleanly, left kernel taint at zero, and produced no firmware fatal, SMMU fault,
VB2 warning, RCU stall, or suspend failure during the recorded runs.

- HEVC 3840x2160p60: 10 seconds of media completed in 10.54 seconds.
- H.264 3840x2160p60: improved substantially over the copy path, but 10 seconds
  of media still took 12.60 seconds (roughly 47-54 capture QBUFs/s). This does
  not yet qualify as a fully smooth 60 fps result.
- Five in-place H.264 seeks reached all requested targets without FFmpeg
  flush/reopen. With DRM PRIME display retention, mpv still reported two
  old/new-epoch invalid timestamp transitions. Kernel-only seek with the
  ordinary copy path remains cleaner than this zero-copy seek case.
- VP9 Profile 0 1920x1080p30 completed through `vp9_v4l2m2m`, exported DRM
  PRIME DMA-BUF frames, displayed with `dmabuf-wayland`, and exited at EOF.
  The compositor reported presentation copies, so this validates hardware
  decode and DMA-BUF export but not end-to-end scanout without copies.
- Two repeated four-way HEVC 3840x2160p60 admission tests accepted two streams
  and cleanly rejected two with `-ENOMEM`, matching the SM8150 4K120 aggregate
  limit. All four accepted sessions completed 600/600 frames with zero decode
  errors, and no request reached the known firmware VBUF exhaustion path.
- The persistent v154 module also booted through the enabled
  `qcom-iris-autoload.service`; the boot serial log is included for recovery
  and startup-order review.

The corresponding player, harness, kernel, and serial logs are included under
`validation/`.
Do not remove the recovery boot entry or deploy broadly until the remaining
H.264 throughput and zero-copy seek ordering issues are resolved.

## Remove the per-user components

```sh
./uninstall-user.sh
```

This intentionally leaves the kernel driver untouched. A driver rollback
must use the backup path printed by `install-driver.sh`, followed by `depmod`
and a reboot.

## Rebuilding the patched FFmpeg library

The patch is based on FFmpeg tag `n8.0.1`, commit `894da5c`.

```sh
git checkout 894da5c
git apply ffmpeg/ffmpeg-8.0.1-v11-drmprime.patch
mkdir build && cd build
../configure \
  --arch=aarch64 --target-os=linux \
  --cross-prefix=aarch64-linux-gnu- --enable-cross-compile \
  --enable-shared --disable-static --disable-programs \
  --disable-autodetect --enable-v4l2-m2m \
  --disable-doc --disable-debug
make -j8
```

The FFmpeg component is LGPLv2.1-or-later under the terms described in
`licenses/LICENSE.md`; the corresponding license text and complete source
patch are included.
