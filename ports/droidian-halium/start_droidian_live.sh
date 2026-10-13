#!/bin/bash
# ==============================================================================
# start_droidian_live.sh: One-Click Bringup of Droidian (API 33 / Android 13) on Bramble
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 📱 Google Pixel 4a (5G) - Droidian Halium Live Launcher (API 33)"

# Check ADB
if ! adb get-state >/dev/null 2>&1; then
    echo "❌ Error: Device not found in ADB!"
    exit 1
fi

echo "==> [1/5] Stopping recovery UI..."
adb shell 'stop recovery 2>/dev/null || true; killall -9 recovery 2>/dev/null || true'

echo "==> [2/5] Ensuring storage, dynamic partitions and rootfs mounts..."
adb shell '
    # 1. Mount userdata
    mountpoint -q /data || mount -t ext4 /dev/block/sda19 /data

    # 2. Mount direct rootfs directory (no loop image)
    mkdir -p /tmp/droidian
    mountpoint -q /tmp/droidian || mount --bind /data/halium-rootfs /tmp/droidian

    # 3. Parse dynamic partitions if dm devices do not exist
    if [ ! -b /dev/dm-0 ]; then
        export PATH=/sbin:/usr/sbin:/bin:/usr/bin
        OLD_IFS="$IFS"
        IFS=";"
        for part in $(chroot /tmp/droidian /usr/sbin/parse-android-dynparts /dev/block/sda18); do
            IFS=","
            set -- $part
            pname="$1"
            ptable="$5"
            if [ -n "$pname" ] && [ -n "$ptable" ]; then
                chroot /tmp/droidian dmsetup create "$pname" --table "$ptable" --readonly 2>/dev/null || true
            fi
        done
        IFS="$OLD_IFS"

        # Create device nodes
        mknod /dev/dm-0 b 253 0 2>/dev/null || true
        mknod /dev/dm-1 b 253 1 2>/dev/null || true
        mknod /dev/dm-2 b 253 2 2>/dev/null || true
    fi

    # 4. Bind mounts
    for d in dev proc sys dev/pts dev/shm; do
        mkdir -p /tmp/droidian/$d
        mountpoint -q /tmp/droidian/$d || mount --bind /$d /tmp/droidian/$d
    done
    mountpoint -q /tmp/droidian/sys/fs/cgroup || mount --bind /sys/fs/cgroup /tmp/droidian/sys/fs/cgroup 2>/dev/null || true

    # 5. Vendor, System & Runtime mounts
    mkdir -p /tmp/droidian/android/vendor /tmp/droidian/android/system /tmp/droidian/android/product /tmp/droidian/android/system_ext /tmp/droidian/android/apex/com.android.runtime
    mkdir -p /tmp/sysroot_mount
    mountpoint -q /tmp/sysroot_mount || mount -t ext4 -o ro /dev/block/dm-0 /tmp/sysroot_mount 2>/dev/null || true
    mountpoint -q /tmp/droidian/android/system || mount --bind /tmp/sysroot_mount/system /tmp/droidian/android/system 2>/dev/null || true
    mountpoint -q /tmp/droidian/android/vendor || mount -t ext4 -o ro /dev/block/dm-3 /tmp/droidian/android/vendor 2>/dev/null || true
    mountpoint -q /tmp/droidian/android/product || mount -t ext4 -o ro /dev/block/dm-1 /tmp/droidian/android/product 2>/dev/null || true
    mountpoint -q /tmp/droidian/android/system_ext || mount -t ext4 -o ro /dev/block/dm-2 /tmp/droidian/android/system_ext 2>/dev/null || true

    # Extract APEX payload if needed
    if [ ! -f /data/apex_runtime/apex_payload.img ] && [ -f /tmp/droidian/android/system/apex/com.android.runtime.apex ]; then
        mkdir -p /data/apex_runtime
        unzip -o /tmp/droidian/android/system/apex/com.android.runtime.apex apex_payload.img -d /data/apex_runtime 2>/dev/null || true
    fi
    if [ -f /data/apex_runtime/apex_payload.img ]; then
        mountpoint -q /tmp/droidian/android/apex/com.android.runtime || mount -t ext4 -o loop,ro /data/apex_runtime/apex_payload.img /tmp/droidian/android/apex/com.android.runtime 2>/dev/null || true
    fi

    # Writable hybris libs
    mkdir -p /tmp/droidian/var/lib/hybris_libs
    [ -e /tmp/droidian/android/system/lib64/libui.so ] && ln -sf /system/lib64/libui.so /tmp/droidian/var/lib/hybris_libs/libui_compat_layer.so 2>/dev/null || true

    # Permissions
    chmod 666 /dev/kgsl-3d0 2>/dev/null || true
    chmod 666 /dev/dri/* 2>/dev/null || true
'

echo "==> [3/5] Injecting hardware fixes (DRM autorefresh, Bionic TLS fix)..."
adb push /run/host/home/astellias/Projects/Pixel4a5G/ports/pmos-downstream/device-google-bramble/libfix_drm_formats.so /tmp/droidian/usr/lib/libfix_drm_formats.so >/dev/null 2>&1 || true
adb push /tmp/libfix_bionic_tls.so /tmp/droidian/usr/lib/libfix_bionic_tls.so >/dev/null 2>&1 || true

# Global preload for Bionic TLS fix
adb shell "echo '/usr/lib/libfix_bionic_tls.so' > /tmp/droidian/etc/ld.so.preload"

echo "==> [4/5] Updating launcher configuration inside Droidian..."
adb shell '
mkdir -p /tmp/droidian/etc/phosh
cat << "EOF" > /tmp/droidian/etc/phosh/phoc.ini
[core]
xwayland = true

[output:DSI-1]
scale = 2.75

[output:Virtual-1]
enable = false
EOF

cat << "EOF" > /tmp/droidian/usr/bin/start_droidian.sh
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TMPDIR=/tmp
export TEMP=/tmp
export TMP=/tmp
export XDG_RUNTIME_DIR=/tmp/run-user-0
export SEATD_VTBOUND=0
export LIBSEAT_BACKEND=builtin
export LD_PRELOAD="/usr/lib/libfix_drm_formats.so /usr/lib/libfix_bionic_tls.so"
export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu/libhybris-gl:/usr/lib/aarch64-linux-gnu/libhybris-egl:/usr/lib/aarch64-linux-gnu
export HYBRIS_LD_LIBRARY_PATH=/var/lib/hybris_libs:/vendor/lib64/egl:/vendor/lib64:/system/lib64:/apex/com.android.runtime/lib64/bionic
export WLR_DRM_DEVICES=/dev/dri/card0
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER=vulkan
export GDK_BACKEND=wayland
export GSK_RENDERER=ngl
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
export TU_DEBUG=kgsl
export NO_AT_BRIDGE=1
export XDG_CURRENT_DESKTOP=Phosh:GNOME
export DESKTOP_SESSION=phosh

# Performance boost
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$g" 2>/dev/null || true
done

mkdir -p /tmp/run-user-0 /run/udev/data /run/dbus /dev/shm /data/local/tmp /tmp
chmod 700 /tmp/run-user-0
chmod 1777 /dev/shm /data/local/tmp /tmp 2>/dev/null || true
mountpoint -q /dev/shm || mount -t tmpfs tmpfs /dev/shm -o rw,nosuid,nodev,mode=1777 2>/dev/null || true

# System & Session DBus
pgrep -x dbus-daemon >/dev/null || dbus-daemon --system --fork 2>/dev/null || true

# Session bus on standard socket
rm -f /tmp/run-user-0/bus
dbus-daemon --session --address=unix:path=/tmp/run-user-0/bus --fork --nopidfile 2>/dev/null || true
export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/run-user-0/bus

# Global environment for desktop apps
cat << "EENV" > /etc/environment
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
WAYLAND_DISPLAY="wayland-0"
XDG_RUNTIME_DIR="/tmp/run-user-0"
DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/run-user-0/bus"
GDK_BACKEND="wayland"
VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json"
TU_DEBUG="kgsl"
EENV

# Udev entry for Focaltech FT5446 Touchscreen
echo "I:1000" > /run/udev/data/c13:66
echo "E:SUBSYSTEM=input" >> /run/udev/data/c13:66
echo "E:DEVNAME=/dev/input/event2" >> /run/udev/data/c13:66
echo "E:ID_INPUT=1" >> /run/udev/data/c13:66
echo "E:ID_INPUT_TOUCHSCREEN=1" >> /run/udev/data/c13:66
echo "E:ID_INPUT_WIDTH_MM=66" >> /run/udev/data/c13:66
echo "E:ID_INPUT_HEIGHT_MM=144" >> /run/udev/data/c13:66
echo "E:WL_OUTPUT=DSI-1" >> /run/udev/data/c13:66
echo "G:seat" >> /run/udev/data/c13:66
echo "Q:seat" >> /run/udev/data/c13:66
echo "V:1" >> /run/udev/data/c13:66

# Backlight full on
echo 1023 > /sys/class/backlight/panel0-backlight/brightness 2>/dev/null || true

killall -9 phoc phosh squeekboard 2>/dev/null || true

echo "[start_droidian] Launching Phoc + Phosh..."

cat << "EOSH" > /tmp/run_phosh_session.sh
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export WAYLAND_DISPLAY=wayland-0
export GDK_BACKEND=wayland
export GSK_RENDERER=cairo
export XDG_RUNTIME_DIR=/tmp/run-user-0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/run-user-0/bus
export TMPDIR=/tmp
export LD_PRELOAD="/usr/lib/libfix_drm_formats.so /usr/lib/libfix_bionic_tls.so"

while [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do
    sleep 0.2
done
sleep 1.5

(
    sleep 2
    which squeekboard >/dev/null 2>&1 && squeekboard &
) &

exec /usr/libexec/phosh -U
EOSH
chmod +x /tmp/run_phosh_session.sh

exec phoc -v -S -C /etc/phosh/phoc.ini -E /tmp/run_phosh_session.sh
EOF
chmod +x /tmp/droidian/usr/bin/start_droidian.sh
'

echo "==> [5/5] Restarting Phoc + Phosh stack with global DBus and TLS fixes..."
adb shell 'setsid chroot /tmp/droidian /bin/bash /usr/bin/start_droidian.sh </dev/null >/tmp/phosh_daemon.log 2>&1 &' &

echo "==> 🎉 Droidian Phosh updated and running live!"
