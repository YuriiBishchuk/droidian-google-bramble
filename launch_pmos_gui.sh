#!/bin/bash
# ==============================================================================
# launch_pmos_gui.sh: Autonomous Weston GUI Launcher for Google Pixel 4a (5G)
# ==============================================================================
set -e

echo "[*] Ensuring Android runtime is stopped..."
adb shell "stop" 2>/dev/null || true

TARGET="/tmp/pmos"
echo "[*] Using target rootfs: $TARGET"

echo "[*] Ensuring chroot mount points (/dev/pts, /dev, /proc, /sys)..."
adb shell "
  mkdir -p $TARGET/dev/pts $TARGET/proc $TARGET/sys $TARGET/dev/shm $TARGET/run $TARGET/tmp/run-user-0 $TARGET/data/local/tmp $TARGET/tmp
  mountpoint -q $TARGET/proc || mount -t proc proc $TARGET/proc
  mountpoint -q $TARGET/sys || mount -t sysfs sys $TARGET/sys
  mountpoint -q $TARGET/dev || mount --bind /dev $TARGET/dev
  mountpoint -q $TARGET/dev/pts || mount -t devpts devpts $TARGET/dev/pts
  mountpoint -q $TARGET/dev/shm || mount -t tmpfs tmpfs $TARGET/dev/shm -o rw,nosuid,nodev,mode=1777
  chmod 700 $TARGET/tmp/run-user-0
  chmod 1777 $TARGET/tmp $TARGET/data/local/tmp
"

echo "[*] Starting Mobile GUI stack via /usr/bin/start_gui.sh..."
adb shell "toybox chroot $TARGET /bin/sh /usr/bin/start_gui.sh $@"
