#!/bin/bash
# ==============================================================================
# run_app.sh: Launch a graphical Wayland app inside postmarketOS on device
# Usage: ./run_app.sh <app_name> [args]
# ==============================================================================
set -e

APP="${1:-weston-terminal}"
shift || true

echo "[*] Launching '$APP $@' on Pixel 4a (5G) screen..."
adb shell "toybox chroot /tmp/pmos /bin/busybox sh -c '
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  export XDG_RUNTIME_DIR=/tmp/run-user-0
  export WAYLAND_DISPLAY=wayland-0
  export LD_PRELOAD=/usr/lib/libfix_drm_formats.so
  export GDK_BACKEND=wayland
  export NO_AT_BRIDGE=1
  nohup $APP $@ >/tmp/app.log 2>&1 &
'"
sleep 1
adb shell "ps -ef | grep $APP"
echo "[+] Application '$APP' is running on display!"
