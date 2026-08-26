# nabu-iris

Xiaomi Pad 5（`nabu`、SM8150）上的实验性 Qualcomm Iris1/Venus 内核支持。

本仓库直接保存内核源码覆盖层，不再发布或要求应用 patch series。源码文件保留
Linux 内核中的原始相对路径，可以复制到指定的内核基线后直接审查、修改和构建。

> 这是实验性代码。刷写内核或替换模块可能导致系统无法启动，请准备可用的恢复方式。

## 仓库分工

- `nabu-iris`：nabu 的设备树、视频时钟、Iris/Venus 内核源码和运行配置。
- [`iris-vaapi`](https://github.com/CFM880/iris-vaapi)：Chrome/FFmpeg 使用的 VA-API 用户态驱动。
- 预编译 UKI、完整模块树和测试日志不进入源码仓库；需要发布时应作为
  GitHub Release 资产单独提供。已验证的 Venus 固件作为设备配套文件保留。

## 当前源码

| 项目 | 值 |
|---|---|
| 已验证设备 | Xiaomi Pad 5 (`nabu`) |
| SoC / VPU | SM8150 / Iris1 (legacy VPU5) |
| 内核基线 | `5181e1358ddd6ea8028e841d928942373e6aebc8` |
| 源码快照 | `8cb100324c8bfff19938cd855e9a5a2276d582a4` |
| 源码文件 | 65 个，位于 `kernel-overlay/` |
| 解码格式 | H.264；HEVC Main/Main10；VP9 Profile 0/Profile 2 |

源码快照包含 decode-order 输出、DMA-BUF reservation fence、HFI Gen1
TP10-UBWC/P010 10-bit 输出，以及 H.264/HEVC/VP9 共用的 `cached_capture` 模块参数。
详细来源见 [SOURCE.md](SOURCE.md)。

## 目录

```text
kernel-overlay/   按 Linux 源码路径组织的直接源码
scripts/          覆盖层安装与模块构建辅助脚本
system/           可选的 modprobe 与 systemd 配置
firmware/         已验证的 Venus 固件及来源说明
LICENSES/         覆盖层中 SPDX 标识对应的许可证文本
```

## 放入内核树

准备一个位于精确基线、且工作树干净的 Linux 源码树：

```sh
git clone https://gitlab.postmarketos.org/soc/qualcomm-sm8150/linux.git linux
git -C linux checkout 5181e1358ddd6ea8028e841d928942373e6aebc8
./scripts/apply-overlay.sh ./linux
```

脚本只是复制直接源码文件，不执行 `git apply`。为避免误覆盖其他工作，它会验证
目标提交和工作树状态。复制完成后可以用普通 Git diff 审查全部变化：

```sh
git -C linux status --short
git -C linux diff --stat
```

## 构建 Iris 模块

目标内核树需要已有可工作的 `.config`，并启用：

```text
CONFIG_MEDIA_SUPPORT=y
CONFIG_VIDEO_DEV=y
CONFIG_VIDEO_QCOM_IRIS=m
```

然后运行：

```sh
./scripts/build-module.sh ./linux ./linux/out
```

生成物位于：

```text
linux/out/drivers/media/platform/qcom/iris/qcom-iris.ko
```

仅当该模块与正在运行的内核版本、配置及符号完全匹配时，才可以安装它。完整内核
和 DTB 的构建、签名、启动配置因发行版而异，不由本仓库自动修改。

## 运行配置

`system/qcom-iris.conf` 同时启用固件启动和 H.264/HEVC cacheable CAPTURE：

```sh
sudo install -m 0644 system/qcom-iris.conf /etc/modprobe.d/qcom-iris.conf
sudo modprobe -r qcom_iris
sudo modprobe qcom_iris
cat /sys/module/qcom_iris/parameters/cached_capture
```

最后一条应输出 `Y`。Chrome 的用户态驱动安装和验证请转到 `iris-vaapi` 仓库。

## 固件

仓库保留了已验证的 `firmware/venus.mbn`，其安装路径、来源和 SHA-256 记录在
`firmware/NOTICE.md`。固件权利归属与内核源码许可证不同，重新分发前请自行确认
适用条款。

## 旧版 bundle

`v140-drmprime-v11` tag 和 Git 历史仍保留旧二进制 bundle，便于复现旧测试；它
不代表当前源码布局，也不建议继续作为安装方式。

## 许可证

每个内核源码文件以其 SPDX 标识为准。本仓库保留 Linux `COPYING`，并在
`LICENSES/preferred/` 中提供本快照涉及的 GPL-2.0-only 与 BSD-3-Clause 文本。
`firmware/venus.mbn` 不适用上述内核源码许可证，详见其 NOTICE。
