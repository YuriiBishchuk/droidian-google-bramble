#!/bin/bash
# Firefox launcher for Droidian on Pixel 4a (5G) - uses XWayland for stability
# Usage: ./firefox_xwayland.sh [URL]

set -e

CHROOT="/tmp/droidian"
PROFILE_DIR="/tmp/firefox_xwayland_profile"
URL="${1:-https://example.com}"

# Ensure Droidian is running
if ! mountpoint -q "$CHROOT"; then
    echo "Error: Droidian chroot not mounted at $CHROOT"
    echo "Run ./start_droidian_live.sh first"
    exit 1
fi

# Create clean profile if needed
mkdir -p "$CHROOT$PROFILE_DIR"
if [ ! -f "$CHROOT$PROFILE_DIR/user.js" ]; then
    cat > "$CHROOT$PROFILE_DIR/user.js" << 'EOF'
user_pref("gfx.webrender.all", false);
user_pref("gfx.webrender.enabled", false);
user_pref("layers.gpu-process.enabled", false);
user_pref("dom.ipc.processCount.web", 1);
user_pref("browser.tabs.remote.autostart", false);
user_pref("browser.tabs.remote.autostart.2", false);
user_pref("widget.wayland-drm-atomic.enabled", false);
user_pref("widget.wayland-drm-atomic.async", false);
user_pref("widget.wayland-drm-atomic.explicit-sync", false);
user_pref("widget.wayland-egl.enabled", false);
EOF
fi

echo "Starting Firefox via XWayland on DISPLAY=:0..."
echo "Profile: $PROFILE_DIR"
echo "URL: $URL"

adb shell "chroot $CHROOT /bin/sh -c '
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DISPLAY=:0
export GDK_BACKEND=x11
export MOZ_ENABLE_WAYLAND=0
export MOZ_DISABLE_WAYLAND=1
export LD_PRELOAD=\"/usr/lib/libfix_drm_formats.so /usr/lib/libfix_bionic_tls.so\"
export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu/libhybris-gl:/usr/lib/aarch64-linux-gnu/libhybris-egl:/usr/lib/aarch64-linux-gnu
export HYBRIS_LD_LIBRARY_PATH=/var/lib/hybris_libs:/vendor/lib64/egl:/vendor/lib64:/system/lib64:/apex/com.android.runtime/lib64/bionic
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
export TU_DEBUG=kgsl
export MOZ_CRASHREPORTER=1
exec firefox --profile $PROFILE_DIR \"$URL\" 2>&1
'"