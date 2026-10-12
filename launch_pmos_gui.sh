#!/bin/bash
# ==============================================================================
# launch_pmos_gui.sh: Autonomous Weston GUI Launcher for Google Pixel 4a (5G)
# ==============================================================================
set -e

echo "[*] Ensuring Android runtime is stopped..."
adb shell "stop" 2>/dev/null || true

echo "[*] Ensuring chroot mount points (/dev/pts, /dev, /proc, /sys)..."
adb shell "
  mkdir -p /tmp/pmos/dev/pts /tmp/pmos/proc /tmp/pmos/sys /tmp/pmos/dev/shm /tmp/pmos/run /tmp/pmos/tmp/run-user-0
  mountpoint -q /tmp/pmos/proc || mount -t proc proc /tmp/pmos/proc
  mountpoint -q /tmp/pmos/sys || mount -t sysfs sys /tmp/pmos/sys
  mountpoint -q /tmp/pmos/dev || mount --bind /dev /tmp/pmos/dev
  mountpoint -q /tmp/pmos/dev/pts || mount -t devpts devpts /tmp/pmos/dev/pts
  mountpoint -q /tmp/pmos/dev/shm || mount -t tmpfs tmpfs /tmp/pmos/dev/shm -o rw,nosuid,nodev,mode=1777
  chmod 700 /tmp/pmos/tmp/run-user-0
"

echo "[*] Starting Mobile GUI stack via /start_gui.sh..."
adb shell "toybox chroot /tmp/pmos /bin/sh /start_gui.sh $@"
