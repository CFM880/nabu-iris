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
