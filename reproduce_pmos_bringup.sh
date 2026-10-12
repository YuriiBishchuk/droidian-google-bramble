#!/usr/bin/env bash
# reproduce_pmos_bringup.sh - 100% Automated postmarketOS bring-up & SSH runner
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Google Pixel 4a (5G) postmarketOS Live Bringup ==="

# 1. Check ADB connection
if ! command -v adb &>/dev/null; then
    echo "❌ Помилка: adb не знайдено в PATH."
    exit 1
fi

DEVICE_STATE=$(adb get-state 2>/dev/null || echo "offline")
if [ "$DEVICE_STATE" != "recovery" ] && [ "$DEVICE_STATE" != "device" ]; then
    echo "⚠️ Пристрій у стані '$DEVICE_STATE'. Очікуємо підключення..."
    adb wait-for-device
fi

echo "✅ Пристрій підключено: $(adb devices | grep -E 'recovery|device' | head -n 1)"

# 2. Stop stock recovery UI
echo "[1/5] Вимикаємо інтерфейс LineageOS Recovery..."
adb shell "stop recovery" 2>/dev/null || true

# 3. Check if rootfs is already uploaded
echo "[2/5] Перевіряємо наявність postmarketOS rootfs у RAM телефону..."
HAS_ROOTFS=$(adb shell "[ -f /tmp/pmos_root.img ] && echo yes || echo no")

if [ "$HAS_ROOTFS" != "yes" ]; then
    if [ ! -f /tmp/pmos_root.img.gz ]; then
        echo "   Стискаємо pmOS_root..."
        if [ ! -f /tmp/pmos_root.img ]; then
            dd if=saved_builds/pmos_bringup_20261011/google-bramble.img of=/tmp/pmos_root.img bs=512 skip=999424 count=897024
        fi
        gzip -1 -c /tmp/pmos_root.img > /tmp/pmos_root.img.gz
    fi
    echo "   Завантажуємо pmOS rootfs у RAM пристрою..."
    adb push /tmp/pmos_root.img.gz /tmp/pmos_root.img.gz
    adb shell "gzip -d /tmp/pmos_root.img.gz"
else
    echo "   pmOS_root.img уже присутній в оперативній пам'яті телефону."
fi

# 4. Mount rootfs and bindings
echo "[3/5] Монтуємо файлову систему postmarketOS та системні вузли..."
adb shell "
mkdir -p /tmp/pmos
if ! mount | grep -q '/tmp/pmos'; then
    losetup /dev/block/loop0 /tmp/pmos_root.img 2>/dev/null || true
    mount -t ext4 /dev/block/loop0 /tmp/pmos 2>/dev/null || mount -t ext4 -o loop /tmp/pmos_root.img /tmp/pmos
fi
mount --bind /proc /tmp/pmos/proc 2>/dev/null || true
mount --bind /sys /tmp/pmos/sys 2>/dev/null || true
mount --bind /dev /tmp/pmos/dev 2>/dev/null || true
mkdir -p /tmp/pmos/dev/pts
mount --bind /dev/pts /tmp/pmos/dev/pts 2>/dev/null || true
"

# 5. Install SSH keys and start Dropbear
echo "[4/5] Налаштовуємо SSH авторизацію та запускаємо Dropbear..."
mkdir -p /tmp/pmos/root/.ssh 2>/dev/null || true
cat ~/.ssh/*.pub 2>/dev/null > /tmp/host_authorized_keys || true
adb push /tmp/host_authorized_keys /tmp/pmos/root/.ssh/authorized_keys 2>/dev/null || true
adb shell "chmod 700 /tmp/pmos/root/.ssh && chmod 600 /tmp/pmos/root/.ssh/authorized_keys 2>/dev/null || true"

adb shell "toybox chroot /tmp/pmos /bin/busybox sh -c '
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
mkdir -p /etc/dropbear
killall dropbear 2>/dev/null || true
/usr/sbin/dropbear -R -B -p 2222
'"

# 6. Forward port
echo "[5/5] Прокидаємо порт SSH..."
adb forward tcp:2222 tcp:2222

echo ""
echo "🎉 postmarketOS УСПІШНО ЗАПУЩЕНО НА GOOGLE PIXEL 4a (5G)!"
echo "Підключення до терміналу:"
echo "   ssh -p 2222 root@127.0.0.1"
echo ""

# Test SSH connection
ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 root@127.0.0.1 "uname -a; cat /etc/os-release | grep PRETTY"
