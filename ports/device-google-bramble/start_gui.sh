#!/bin/sh
# ==============================================================================
# /usr/local/bin/start_gui.sh: Interactive Mobile GUI Launcher for Pixel 4a (5G)
# ==============================================================================
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TMPDIR=/tmp
export TEMP=/tmp
export TMP=/tmp
export XDG_RUNTIME_DIR=/tmp/run-user-0
export SEATD_VTBOUND=0
export SEATD_SOCK=/run/seatd.sock
export LD_PRELOAD=/usr/lib/libfix_drm_formats.so
export WLR_DRM_DEVICES=/dev/dri/card0
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER=pixman
export GDK_BACKEND=wayland
export NO_AT_BRIDGE=1
export XDG_CURRENT_DESKTOP=Phosh:GNOME
export DESKTOP_SESSION=phosh

mkdir -p /tmp/run-user-0 /run /dev/pts /dev/shm /data/local/tmp /tmp
chmod 700 /tmp/run-user-0
chmod 1777 /tmp /data/local/tmp
mountpoint -q /dev/shm || mount -t tmpfs tmpfs /dev/shm -o rw,nosuid,nodev,mode=1777

mkdir -p /run/dbus
pgrep -x dbus-daemon >/dev/null || dbus-daemon --system

killall -9 phoc phosh squeekboard weston seatd 2>/dev/null || true
rm -f /run/seatd.sock /tmp/seatd.log /tmp/phosh.log

echo "[start_gui] Starting seatd daemon..."
seatd -u root -g root -l debug >/tmp/seatd.log 2>&1 &

for i in $(seq 1 20); do
    if [ -S /run/seatd.sock ]; then
        echo "[start_gui] seatd.sock is ready!"
        chmod 0777 /run/seatd.sock
        break
    fi
    sleep 0.1
done

if [ ! -S /run/seatd.sock ]; then
    echo "[start_gui] Error: seatd failed to create socket!"
    cat /tmp/seatd.log
    exit 1
fi

# Ensure backlight is active
echo 1023 > /sys/class/backlight/panel0-backlight/brightness 2>/dev/null || true

case "$1" in
    weston)
        echo "[start_gui] Launching Weston desktop shell..."
        exec weston --backend=drm --renderer=pixman --drm-device=card0 --continue-without-input --log=/tmp/weston.log
        ;;
    *)
        echo "[start_gui] Launching Phoc + Phosh mobile environment..."
        cat << 'RUNNER' > /tmp/run_phosh_session.sh
#!/bin/sh
export TMPDIR=/tmp
export TEMP=/tmp
export TMP=/tmp
export WAYLAND_DISPLAY=wayland-0
export GDK_BACKEND=wayland
export XDG_RUNTIME_DIR=/tmp/run-user-0
export LD_PRELOAD=/usr/lib/libfix_drm_formats.so

(
    while [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do sleep 0.2; done
    sleep 1
    squeekboard &
) &

exec /usr/libexec/phosh -U
RUNNER
        chmod +x /tmp/run_phosh_session.sh
        exec dbus-run-session phoc -v -S -C /etc/phosh/phoc.ini -E /tmp/run_phosh_session.sh
        ;;
esac
