# nabu-iris

[English](README.md) | **中文**

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
| 源码文件 | 62 个，位于 `kernel-overlay/` |
| 解码格式 | H.264；HEVC Main/Main10；VP9 Profile 0/Profile 2 |

源码快照包含 decode-order 输出、DMA-BUF reservation fence、HFI Gen1
TP10-UBWC/P010 10-bit 输出、legacy VP9 有效 DROP_FRAME CAPTURE 回收，以及
H.264/HEVC/VP9 共用的 `cached_capture` 模块参数。
详细来源见 [SOURCE.md](SOURCE.md)。

## 目录

```text
kernel-overlay/   按 Linux 源码路径组织的直接源码
config/           可合并到现有 .config 的 Iris Kconfig fragment
scripts/          运行时辅助脚本（模块加载）
system/           可选的 modprobe 与 systemd 配置
firmware/         已验证的 Venus 固件及来源说明
LICENSES/         覆盖层中 SPDX 标识对应的许可证文本
```

## 统一构建（nabu-main）

本仓库不再自带覆盖层安装、配置合并或模块构建脚本。跨仓的统一构建由同级的
`nabu-main` 负责：它 reset 到基线内核、应用本仓 `kernel-overlay`、生成组合 DTS、
合并 `config/nabu-iris.config` 并构建模块，全部通过根目录的 `nabu-module.toml`
声明：

```toml
[provides]
overlay = "kernel-overlay"
dtsi    = ["arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu-iris.dtsi"]
config  = ["config/nabu-iris.config"]

[build]
kernel_targets = ["drivers/media/platform/qcom/iris/qcom-iris.ko"]
```

在内核基线 `5181e1358ddd6ea8028e841d928942373e6aebc8` 上，于 `nabu-main` 运行：

```sh
make apply      # reset linux，应用 overlay/patch
make compose    # 由各模块 dtsi 生成组合 DTS
make config     # 合并 fragment 并固定统一 release
make build      # 构建 Image、模块与 DTB
make collect    # 收集产物到 artifacts/<product>/
```

## 设备树

仓库不再覆盖 `sm8150.dtsi`，也不修改原始 `sm8150-xiaomi-nabu.dts`，只提供
`arch/arm64/boot/dts/qcom/sm8150-xiaomi-nabu-iris.dtsi` 片段。组合 DTB 不再手写，
由 `nabu-main compose` 按产品顺序自动生成：

```dts
#include "sm8150-xiaomi-nabu.dts"
#include "sm8150-xiaomi-nabu-iris.dtsi"
...
```

启动时使用 `nabu-main` 生成的组合 DTB，原始 nabu DTB 不包含这些追加节点。

SM8150 v2 的 Iris 时钟 OPP 必须与 Qualcomm 下游 VideoCC 电压表逐档对应：

```text
200 MHz  MIN_SVS
240 MHz  LOW_SVS
338 MHz  SVS
365 MHz  SVS_L1
444 MHz  NOM
533 MHz  TURBO
```

不能省略 338 MHz 后再把更高频率整体映射到较低电压。例如 533 MHz 只投票到
`NOM` 时，VCODEC0 GDSC 会报告上电成功，但 `VIDEO_CC_MVS0_CORE_CLK` 的 OFF
状态位无法清除。派生 DTB 中的 `venus_opp_table` 已按上述硬件电压表修正。

## 配置

仓库使用 `config/nabu-iris.config` 保存 Iris 所需选项，不覆盖主
`arch/arm64/configs/sm8150.config`。`nabu-main config` 会把它与其它模块的
fragment 一起合并进统一的内核 `.config`，顺序不会改变最终配置。

## 构建 Iris 模块

`nabu-main build` 在统一的 `out/` 中构建
`drivers/media/platform/qcom/iris/qcom-iris.ko`，并保证它与其它 nabu 模块共用同一
kernel release；产物由 `nabu-main collect` 收集到 `nabu-main/artifacts/<product>/`。

仅当该模块与正在运行的内核版本、配置及符号完全匹配时，才可以安装它。完整内核
和 DTB 的构建、签名、启动配置因发行版而异，不由本仓库自动修改。

## 运行配置

`system/qcom-iris.conf` 同时启用固件启动和 H.264/HEVC/VP9 cacheable CAPTURE：

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
