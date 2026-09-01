#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

if [ "$#" -ne 2 ]; then
	echo "usage: $0 /path/to/linux /path/to/output" >&2
	exit 2
fi

kernel_tree=$(CDPATH= cd -- "$1" && pwd)
output_dir=$(CDPATH= cd -- "$2" && pwd)
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fragment=$(dirname -- "$script_dir")/config/nabu-iris.config

if [ ! -x "$kernel_tree/scripts/kconfig/merge_config.sh" ]; then
	echo "missing kernel merge_config.sh: $kernel_tree" >&2
	exit 1
fi

if [ ! -f "$output_dir/.config" ]; then
	echo "missing configured kernel output: $output_dir/.config" >&2
	exit 1
fi

if [ ! -f "$kernel_tree/drivers/media/platform/qcom/iris/Kconfig" ]; then
	echo "Iris overlay is not installed; run scripts/apply-overlay.sh first" >&2
	exit 1
fi

(
	cd "$kernel_tree"
	scripts/kconfig/merge_config.sh -m -O "$output_dir" \
		"$output_dir/.config" "$fragment"
)

echo "merged $fragment into $output_dir/.config"
