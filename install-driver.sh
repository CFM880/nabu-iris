#!/bin/sh
set -eu

release_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
expected_kernel='6.14.11-nabu-iris1+'
expected_hash='406f6da1283d3f8ff4e406c1c9a9116dbea8c70a17f3e0bb716d452152009230'
module_src="${release_dir}/kernel/qcom-iris.ko"
module_dir="/lib/modules/${expected_kernel}/kernel/drivers/media/platform/qcom/iris"
module_dst="${module_dir}/qcom-iris.ko"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root: sudo ./install-driver.sh" >&2
    exit 1
fi

if [ "$(uname -r)" != "${expected_kernel}" ]; then
    echo "Unsupported running kernel: $(uname -r)" >&2
    echo "This binary module requires ${expected_kernel}" >&2
    exit 1
fi

actual_hash=$(sha256sum "${module_src}" | cut -d ' ' -f 1)
if [ "${actual_hash}" != "${expected_hash}" ]; then
    echo "Driver checksum mismatch: ${actual_hash}" >&2
    exit 1
fi

case "$(modinfo -F vermagic "${module_src}")" in
    "${expected_kernel} "*) ;;
    *)
        echo "Driver vermagic does not match ${expected_kernel}" >&2
        exit 1
        ;;
esac

mkdir -p "${module_dir}"
if [ -e "${module_dst}" ]; then
    old_hash=$(sha256sum "${module_dst}" | cut -d ' ' -f 1)
    old_short=$(printf '%s' "${old_hash}" | cut -c 1-8)
    backup="${module_dst}.pre-v154-${old_short}"
    if [ "${old_hash}" != "${expected_hash}" ] && [ ! -e "${backup}" ]; then
        cp -a "${module_dst}" "${backup}"
        echo "Backed up previous module to ${backup}"
    fi
fi

install -m 0644 "${module_src}" "${module_dst}"
install -m 0644 "${release_dir}/system/qcom-iris.conf" /etc/modprobe.d/qcom-iris.conf
install -m 0644 "${release_dir}/system/qcom-iris-autoload.service" \
    /etc/systemd/system/qcom-iris-autoload.service
depmod -a "${expected_kernel}"
systemctl daemon-reload
systemctl enable qcom-iris-autoload.service

if [ ! -d /sys/module/qcom_iris ]; then
    systemctl start qcom-iris-autoload.service
else
    echo "qcom_iris is already loaded; the new persistent module will be used after reboot."
fi

sha256sum "${module_dst}"
systemctl is-enabled qcom-iris-autoload.service
systemctl is-active qcom-iris-autoload.service || true
