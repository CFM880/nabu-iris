#!/bin/sh
set -eu

release_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
expected_kernel='6.14.11-nabu-iris1+'
expected_uki_hash='591e388018e911375391c6ce5ba19b6276d91d8d7088e54468b67f4d398d2926'
expected_module_hash='ee0701b2acdd1d9509ffc00f2304687a56021f22bee11661cc8fdfb200da6ccb'
expected_firmware_hash='9d4af65d7ede845e900f1b29ff425b7a8e2947056e695e246e58a2091445a085'
uki_src="${release_dir}/kernel/boot/6.14.11-nabu-iris1-v44-hwctrl-trigger-current.efi"
modules_src="${release_dir}/kernel/modules-root/lib/modules/${expected_kernel}"
modules_dst="/lib/modules/${expected_kernel}"
firmware_src="${release_dir}/firmware/venus.mbn"
firmware_dst='/lib/firmware/qcom/sm8150/xiaomi/nabu/venus.mbn'
esp_mount=${1:-}

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root and pass the mounted ESPNABU path:" >&2
    echo "  sudo ./install-kernel.sh /mnt/esp-nabu" >&2
    exit 1
fi

if [ -z "${esp_mount}" ] || ! mountpoint -q "${esp_mount}"; then
    echo "The first argument must be the mounted ESPNABU filesystem." >&2
    exit 1
fi

if [ "$(findmnt -nr -o FSTYPE --target "${esp_mount}")" != 'vfat' ]; then
    echo "Refusing to use a non-vfat ESP: ${esp_mount}" >&2
    exit 1
fi

case ",$(findmnt -nr -o OPTIONS --target "${esp_mount}")," in
    *,rw,*) ;;
    *)
        echo "The ESPNABU filesystem is not mounted read-write: ${esp_mount}" >&2
        exit 1
        ;;
esac

case "$(tr -d '\000' </proc/device-tree/model 2>/dev/null || true)" in
    *'Xiaomi Pad 5'*|*nabu*) ;;
    *)
        echo "This bundle is only for Xiaomi Pad 5 (nabu)." >&2
        exit 1
        ;;
esac

actual_uki_hash=$(sha256sum "${uki_src}" | cut -d ' ' -f 1)
actual_module_hash=$(sha256sum "${modules_src}/kernel/drivers/media/platform/qcom/iris/qcom-iris.ko" | cut -d ' ' -f 1)
actual_firmware_hash=$(sha256sum "${firmware_src}" | cut -d ' ' -f 1)
if [ "${actual_uki_hash}" != "${expected_uki_hash}" ]; then
    echo "UKI checksum mismatch: ${actual_uki_hash}" >&2
    exit 1
fi
if [ "${actual_module_hash}" != "${expected_module_hash}" ]; then
    echo "Iris module checksum mismatch: ${actual_module_hash}" >&2
    exit 1
fi
if [ "${actual_firmware_hash}" != "${expected_firmware_hash}" ]; then
    echo "VPU firmware checksum mismatch: ${actual_firmware_hash}" >&2
    exit 1
fi

case "$(modinfo -F vermagic "${modules_src}/kernel/drivers/media/platform/qcom/iris/qcom-iris.ko")" in
    "${expected_kernel} "*) ;;
    *)
        echo "Iris module vermagic does not match ${expected_kernel}" >&2
        exit 1
        ;;
esac

esp_ubuntu="${esp_mount}/EFI/ubuntu"
uki_dst="${esp_ubuntu}/6.14.11-nabu-iris1-v140-drmprime.efi"
if [ -e "${uki_dst}" ]; then
    installed_hash=$(sha256sum "${uki_dst}" | cut -d ' ' -f 1)
    if [ "${installed_hash}" != "${expected_uki_hash}" ]; then
        echo "Refusing to overwrite a different file: ${uki_dst}" >&2
        exit 1
    fi
fi

install -d -m 0755 "${modules_dst}"
old_module="${modules_dst}/kernel/drivers/media/platform/qcom/iris/qcom-iris.ko"
if [ -e "${old_module}" ]; then
    old_hash=$(sha256sum "${old_module}" | cut -d ' ' -f 1)
    old_short=$(printf '%s' "${old_hash}" | cut -c 1-8)
    backup="${old_module}.pre-v140-${old_short}"
    if [ "${old_hash}" != "${expected_module_hash}" ] && [ ! -e "${backup}" ]; then
        cp -a "${old_module}" "${backup}"
        echo "Backed up previous Iris module to ${backup}"
    fi
fi
cp -a "${modules_src}/." "${modules_dst}/"
depmod -a "${expected_kernel}"

if [ -e "${firmware_dst}" ]; then
    old_firmware_hash=$(sha256sum "${firmware_dst}" | cut -d ' ' -f 1)
    old_firmware_short=$(printf '%s' "${old_firmware_hash}" | cut -c 1-8)
    firmware_backup="${firmware_dst}.pre-nabu-iris-${old_firmware_short}"
    if [ "${old_firmware_hash}" != "${expected_firmware_hash}" ] && \
       [ ! -e "${firmware_backup}" ]; then
        cp -a "${firmware_dst}" "${firmware_backup}"
        echo "Backed up previous VPU firmware to ${firmware_backup}"
    fi
fi
install -D -m 0644 "${firmware_src}" "${firmware_dst}"

install -d -m 0755 "${esp_ubuntu}"
if [ -e "${uki_dst}" ]; then
    :
else
    install -m 0644 "${uki_src}" "${uki_dst}"
fi

install -m 0644 "${release_dir}/system/qcom-iris.conf" /etc/modprobe.d/qcom-iris.conf
install -m 0644 "${release_dir}/system/qcom-iris-autoload.service" \
    /etc/systemd/system/qcom-iris-autoload.service
systemctl daemon-reload
systemctl enable qcom-iris-autoload.service

sha256sum "${uki_dst}" "${old_module}" "${firmware_dst}"
echo "Installed a new rEFInd entry without replacing existing EFI files."
echo "Reboot, select 6.14.11-nabu-iris1-v140-drmprime.efi, then verify:"
echo "  uname -a"
echo "  sha256sum ${old_module}"
