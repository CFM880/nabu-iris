#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

if [ "$#" -ne 2 ]; then
	echo "usage: $0 /path/to/linux /path/to/output" >&2
	exit 2
fi

kernel_tree=$(CDPATH= cd -- "$1" && pwd)
mkdir -p "$2"
output_dir=$(CDPATH= cd -- "$2" && pwd)
dts_dir=$kernel_tree/arch/arm64/boot/dts/qcom

if [ ! -f "$dts_dir/sm8150-xiaomi-nabu-iris.dts" ]; then
	echo "Iris overlay is not installed; run scripts/apply-overlay.sh first" >&2
	exit 1
fi

if [ ! -f "$output_dir/.config" ]; then
	echo "missing configured kernel output: $output_dir/.config" >&2
	exit 1
fi

dtb=sm8150-xiaomi-nabu-iris.dtb
if [ -f "$dts_dir/sm8150-xiaomi-nabu-camera.dtsi" ]; then
	dtb=sm8150-xiaomi-nabu-iris-camera.dtb
fi

: "${ARCH:=arm64}"
: "${CROSS_COMPILE:=aarch64-linux-gnu-}"
export ARCH CROSS_COMPILE

make -C "$kernel_tree" O="$output_dir" olddefconfig
make -C "$kernel_tree" O="$output_dir" "qcom/$dtb"

output_dtb=$output_dir/arch/arm64/boot/dts/qcom/$dtb
test -f "$output_dtb"
echo "built $output_dtb"
