#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Temporarily load an external Iris module; keep the installed module intact.
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: sudo $0 /path/to/qcom-iris.ko" >&2
    exit 2
fi
if [ "$(id -u)" -ne 0 ]; then
    echo "root is required to reload the kernel module" >&2
    exit 1
fi
module=$(realpath "$1")
release=$(uname -r)
case "$(modinfo -F vermagic "$module")" in
    "$release "*) ;;
    *) echo "module does not match running kernel $release" >&2; exit 1 ;;
esac
dependencies=$(modinfo -F depends "$module" | tr ',' ' ')
restore() {
    echo "candidate load failed; restoring installed qcom_iris" >&2
    modprobe qcom_iris || true
}
if [ -d /sys/module/qcom_iris ]; then
    modprobe -r qcom_iris
fi
# modprobe -r may remove unused dependencies; insmod does not reload them.
for dependency in $dependencies; do
    if ! modprobe "$dependency"; then
        restore
        exit 1
    fi
done
if ! insmod "$module" allow_fw_boot=1 cached_capture=1; then
    restore
    exit 1
fi
echo "Loaded candidate $module (not installed on disk)"
