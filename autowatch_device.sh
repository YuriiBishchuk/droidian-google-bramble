#!/usr/bin/env bash
# autowatch_device.sh - Monitors for Pixel 4a (5G) connection in ADB or Fastboot
set -euo pipefail

echo "=== Pixel 4a 5G (bramble) Connection Monitor ==="
echo "Очікування підключення пристрою (ADB або Fastboot)..."

while true; do
    # Check ADB
    ADB_DEV=$(adb devices 2>/dev/null | grep -E "device$|recovery$|sideload$" | awk '{print $1}' || true)
    if [ -n "$ADB_DEV" ]; then
        echo "[$(date '+%H:%M:%S')] ✅ Пристрій знайдено в ADB ($ADB_DEV)!"
        echo "Стан: $(adb get-state 2>/dev/null || echo 'unknown')"
        adb devices -l
        break
    fi

    # Check Fastboot
    FB_DEV=$(fastboot devices 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$FB_DEV" ]; then
        echo "[$(date '+%H:%M:%S')] ✅ Пристрій знайдено в Fastboot ($FB_DEV)!"
        fastboot devices
        break
    fi

    sleep 2
done
