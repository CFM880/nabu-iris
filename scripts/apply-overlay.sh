#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu

expected_base=5181e1358ddd6ea8028e841d928942373e6aebc8

if [ "$#" -ne 1 ]; then
    echo "usage: $0 /path/to/linux" >&2
    exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
overlay_dir=$(dirname -- "$script_dir")/kernel-overlay
kernel_tree=$1

if [ ! -f "$kernel_tree/Makefile" ] || [ ! -d "$kernel_tree/.git" ]; then
    echo "not a Linux Git worktree: $kernel_tree" >&2
    exit 1
fi

current=$(git -C "$kernel_tree" rev-parse HEAD)
if [ "$current" != "$expected_base" ]; then
    echo "expected base $expected_base, found $current" >&2
    exit 1
fi

if ! git -C "$kernel_tree" diff --quiet ||
   ! git -C "$kernel_tree" diff --cached --quiet ||
   [ -n "$(git -C "$kernel_tree" ls-files --others --exclude-standard)" ]; then
    echo "target worktree is not clean: $kernel_tree" >&2
    exit 1
fi

cp -a "$overlay_dir/." "$kernel_tree/"
echo "installed nabu-iris source overlay into $kernel_tree"
git -C "$kernel_tree" status --short
