#!/bin/sh
set -eu

install_root="${HOME}/.local/opt/nabu-iris-v140-drmprime-v11"
launcher="${HOME}/.local/bin/mpv-iris"
desktop_file="${HOME}/.local/share/applications/mpv-iris.desktop"
desktop_backup="${desktop_file}.pre-v11"

rm -f "${launcher}"
rm -rf "${install_root}"

if [ -e "${desktop_backup}" ]; then
    mv "${desktop_backup}" "${desktop_file}"
else
    rm -f "${desktop_file}"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${HOME}/.local/share/applications" || true
fi

echo "Removed the per-user FFmpeg and mpv launcher."
echo "The kernel driver was not changed."
