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

if [ ! -f "$kernel_tree/Makefile" ]; then
    echo "not a Linux source tree: $kernel_tree" >&2
    exit 1
fi

if [ ! -f "$output_dir/.config" ]; then
    echo "missing configured kernel output: $output_dir/.config" >&2
    exit 1
fi

: "${ARCH:=arm64}"
: "${CROSS_COMPILE:=aarch64-linux-gnu-}"
export ARCH CROSS_COMPILE

make -C "$kernel_tree" O="$output_dir" olddefconfig
module_output="$output_dir/drivers/media/platform/qcom/iris"
mkdir -p "$module_output"
make -C "$kernel_tree" O="$output_dir" \
    M=drivers/media/platform/qcom/iris MO="$module_output" modules

module="$output_dir/drivers/media/platform/qcom/iris/qcom-iris.ko"
test -f "$module"
echo "built $module"
