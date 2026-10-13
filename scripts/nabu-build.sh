#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# nabu-main build hook for nabu-iris.
#
# The kernel module and the product UKI are built by nabu-main itself.  This
# hook additionally builds the iris-vaapi VA-API userspace driver (the sibling
# iris-vaapi repository) into out/userspace/root, so that `make install` only
# copies a prebuilt vpu_drv_video.so and needs no compiler toolchain or network.
#
# The cross build reuses the toolchain nabu-main uses for the kernel
# (NABU_CROSS_COMPILE: aarch64-linux-gnu- on x86_64, empty/native on arm64).
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname -- "$script_dir")
module_dir=${NABU_MODULE_DIR:-$project_dir}

# iris-vaapi is a sibling repository in the workspace; override with
# NABU_IRIS_VAAPI_DIR if it lives elsewhere.
workspace=$(dirname -- "$module_dir")
vaapi=${NABU_IRIS_VAAPI_DIR:-$workspace/iris-vaapi}
[ -f "$vaapi/Makefile" ] || {
	echo "nabu-iris: iris-vaapi not found at $vaapi (set NABU_IRIS_VAAPI_DIR)" >&2
	exit 1
}

stage=$module_dir/out/userspace/root
driverdir=/usr/lib/aarch64-linux-gnu/dri
rm -rf -- "$stage$driverdir"
install -d -m0755 "$stage$driverdir"

cross=${NABU_CROSS_COMPILE:-aarch64-linux-gnu-}
target=$("${cross}gcc" -dumpmachine 2>/dev/null || true)
host=$(cc -dumpmachine 2>/dev/null || true)

cc=${cross}gcc
ldflags=
if [ -z "$target" ] || [ "$target" = "$host" ]; then
	# Native build (the tablet or an arm64 build host).
	cc=cc
else
	# Cross build: point pkg-config at the target .pc files and let the linker
	# find the target libva in the multiarch directory.
	PKG_CONFIG_LIBDIR=${NABU_PKG_CONFIG_LIBDIR:-/usr/lib/$target/pkgconfig:/usr/share/pkgconfig}
	export PKG_CONFIG_LIBDIR
	ldflags="-L/usr/lib/$target"
fi

# iris-vaapi's Makefile takes CC/LDFLAGS/DESTDIR/DRIVERDIR from the command
# line; DRIVERDIR pins the libva driver directory so a host pkg-config cannot
# leak the wrong multiarch path into the staging tree.
make -C "$vaapi" \
	CC="$cc" LDFLAGS="$ldflags" \
	DESTDIR="$stage" DRIVERDIR="$driverdir" \
	-j"${NABU_JOBS:-$(nproc)}" install

[ -s "$stage$driverdir/vpu_drv_video.so" ] || {
	echo "nabu-iris: iris-vaapi did not produce $stage$driverdir/vpu_drv_video.so" >&2
	exit 1
}
echo "built iris-vaapi VA-API driver: $stage$driverdir/vpu_drv_video.so"
