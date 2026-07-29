#!/bin/sh
set -eu

release_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
install_root="${HOME}/.local/opt/nabu-iris-v140-drmprime-v11"
bin_dir="${HOME}/.local/bin"
desktop_dir="${HOME}/.local/share/applications"
desktop_file="${desktop_dir}/mpv-iris.desktop"
desktop_backup="${desktop_file}.pre-v11"

case "${HOME}" in
    *'|'*|*'&'*)
        echo "HOME contains a character unsupported by the desktop template: ${HOME}" >&2
        exit 1
        ;;
esac

mkdir -p "${install_root}" "${bin_dir}" "${desktop_dir}"
rm -rf "${install_root}/ffmpeg.new"
cp -a "${release_dir}/ffmpeg" "${install_root}/ffmpeg.new"
rm -rf "${install_root}/ffmpeg"
mv "${install_root}/ffmpeg.new" "${install_root}/ffmpeg"
install -m 0755 "${release_dir}/bin/mpv-iris" "${bin_dir}/mpv-iris"

if [ -e "${desktop_file}" ] && [ ! -e "${desktop_backup}" ]; then
    cp -a "${desktop_file}" "${desktop_backup}"
fi

sed "s|@HOME@|${HOME}|g" \
    "${release_dir}/desktop/mpv-iris.desktop.in" > "${desktop_file}.new"
chmod 0644 "${desktop_file}.new"
mv "${desktop_file}.new" "${desktop_file}"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${desktop_dir}" || true
fi

echo "Installed patched FFmpeg under ${install_root}"
echo "Installed launcher ${bin_dir}/mpv-iris"
echo "Installed desktop entry ${desktop_file}"
echo "Run: ${bin_dir}/mpv-iris VIDEO.mp4"
