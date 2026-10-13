#!/bin/bash
# Epiphany (GNOME Web) launcher for Droidian on Pixel 4a (5G) - uses XWayland
# Usage: ./epiphany_xwayland.sh [URL]

set -e

CHROOT="/tmp/droidian"
URL="${1:-https://example.com}"

# Ensure Droidian is running
if ! mountpoint -q "$CHROOT"; then
    echo "Error: Droidian chroot not mounted at $CHROOT"
    echo "Run ./start_droidian_live.sh first"
    exit 1
fi

echo "Starting Epiphany via XWayland on DISPLAY=:0..."
echo "URL: $URL"

adb shell "chroot $CHROOT /bin/sh -c '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DISPLAY=:0
export GDK_BACKEND=x11
export LD_PRELOAD=\"/usr/lib/libfix_drm_formats.so /usr/lib/libfix_bionic_tls.so\"
export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu/libhybris-gl:/usr/lib/aarch64-linux-gnu/libhybris-egl:/usr/lib/aarch64-linux-gnu
export HYBRIS_LD_LIBRARY_PATH=/var/lib/hybris_libs:/vendor/lib64/egl:/vendor/lib64:/system/lib64:/apex/com.android.runtime/lib64/bionic
exec epiphany \"$URL\" 2>&1
'"