#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# nabu-main install hook for nabu-iris.
#
# nabu-main copies the units declared in [provides].systemd but does not talk to
# systemd itself.  Reload it and enable the unit so a fresh install behaves the
# same as the older hand-enabled setup.
set -eu

[ "$(id -u)" -eq 0 ] || {
    echo "nabu-iris install hook must run as root" >&2
    exit 1
}

systemctl daemon-reload
unit=qcom-iris-autoload.service
if [ -f "/etc/systemd/system/$unit" ]; then
    systemctl enable "$unit" >/dev/null
    echo "nabu-iris: enabled $unit"
fi

# The iris-vaapi driver allocates Chrome's surface backings from the system
# DMA-heap, which the kernel exposes root-only by default (Chrome would then
# fall back to software decoding).  Reload the rule and open it up now so
# decoding works without a reboot.
if [ -e /etc/udev/rules.d/99-qcom-iris-dmaheap.rules ]; then
    udevadm control --reload >/dev/null 2>&1 || true
    udevadm trigger --subsystem-match=dma_heap >/dev/null 2>&1 || true
    chmod 0666 /dev/dma_heap/system 2>/dev/null || true
    echo "nabu-iris: installed the qcom-iris dma_heap rule"
fi
