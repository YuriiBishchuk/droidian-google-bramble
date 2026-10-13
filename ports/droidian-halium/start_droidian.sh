#!/bin/bash
# ==============================================================================
# start_droidian.sh: Complete Droidian Phoc + Phosh Mobile Launcher with Touch
# ==============================================================================
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TMPDIR=/tmp
export TEMP=/tmp
export TMP=/tmp
export XDG_RUNTIME_DIR=/tmp/run-user-0
export SEATD_VTBOUND=0
export LIBSEAT_BACKEND=builtin
export LD_PRELOAD=/usr/lib/libfix_drm_formats.so
export WLR_DRM_DEVICES=/dev/dri/card0
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER=pixman
export GDK_BACKEND=wayland
export NO_AT_BRIDGE=1
export XDG_CURRENT_DESKTOP=Phosh:GNOME
export DESKTOP_SESSION=phosh
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export GSK_RENDERER=cairo

# Performance boost
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$g" 2>/dev/null || true
done

mkdir -p /tmp/run-user-0 /run/udev/data /run/dbus /dev/shm
chmod 700 /tmp/run-user-0
chmod 1777 /dev/shm 2>/dev/null || true
mountpoint -q /dev/shm || mount -t tmpfs tmpfs /dev/shm -o rw,nosuid,nodev,mode=1777 2>/dev/null || true

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

# Backlight on
echo 1023 > /sys/class/backlight/panel0-backlight/brightness 2>/dev/null || true

# DBus
pgrep -x dbus-daemon >/dev/null || dbus-daemon --system --fork 2>/dev/null || true

killall -9 phoc phosh squeekboard 2>/dev/null || true

echo "[start_droidian] Launching Phoc + Phosh..."

echo '#!/bin/sh' > /tmp/run_phosh_session.sh
echo 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' >> /tmp/run_phosh_session.sh
echo 'export WAYLAND_DISPLAY=wayland-0' >> /tmp/run_phosh_session.sh
echo 'export GDK_BACKEND=wayland' >> /tmp/run_phosh_session.sh
echo 'export XDG_RUNTIME_DIR=/tmp/run-user-0' >> /tmp/run_phosh_session.sh
echo 'export LD_PRELOAD=/usr/lib/libfix_drm_formats.so' >> /tmp/run_phosh_session.sh
echo 'export LIBGL_ALWAYS_SOFTWARE=1' >> /tmp/run_phosh_session.sh
echo 'export GALLIUM_DRIVER=llvmpipe' >> /tmp/run_phosh_session.sh
echo 'export GSK_RENDERER=cairo' >> /tmp/run_phosh_session.sh
echo '(' >> /tmp/run_phosh_session.sh
echo '    while [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do sleep 0.2; done' >> /tmp/run_phosh_session.sh
echo '    sleep 1' >> /tmp/run_phosh_session.sh
echo '    squeekboard &' >> /tmp/run_phosh_session.sh
echo ') &' >> /tmp/run_phosh_session.sh
echo 'exec /usr/libexec/phosh -U' >> /tmp/run_phosh_session.sh
chmod +x /tmp/run_phosh_session.sh

exec dbus-run-session phoc -v -S -C /etc/phosh/phoc.ini -E /tmp/run_phosh_session.sh
