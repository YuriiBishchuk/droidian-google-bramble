#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Pixel 4a 5G (bramble) LineageOS 23.2 Flasher ==="

# Check fastboot availability
if ! command -v fastboot &>/dev/null; then
    echo "Помилка: fastboot не знайдено в PATH."
    exit 1
fi

echo "[1/4] Перевірка підключення пристрою в режимі Fastboot..."
DEVICE_STATE=$(fastboot devices | awk '{print $2}')

if [ -z "$DEVICE_STATE" ]; then
    echo "❌ Пристрій не знайдено у fastboot mode! Перевірте підключення кабелю."
    exit 1
elif [ "$DEVICE_STATE" = "no" ]; then
    echo "❌ Помилка прав доступу (no permissions)!"
    echo "Виконайте на хост-системі:"
    echo '  echo '\''SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666"'\'' | sudo tee /etc/udev/rules.d/51-android.rules && sudo udevadm control --reload-rules && sudo udevadm trigger'
    exit 1
fi

echo "✅ Пристрій знайдено: $(fastboot devices)"

echo "[2/4] Прошивка boot, dtbo та vendor_boot (LineageOS Recovery)..."
fastboot flash boot boot.img
fastboot flash dtbo dtbo.img
fastboot flash vendor_boot vendor_boot.img

echo "✅ Розділи ядра та рекавері успішно прошиті!"
echo ""
echo "[3/4] Перезавантаження в режим Recovery..."
echo "Перезавантажуємо в Recovery..."
fastboot reboot recovery || true

echo ""
echo "=================================================================="
echo "УВАГА: Зараз пристрій завантажується в LineageOS Recovery!"
echo "1. Якщо пристрій був у бутлупі, обов'язково зробіть скидання даних:"
echo "   -> Factory Reset -> Format data / factory reset"
echo "2. Після цього поверніться в головне меню та виберіть:"
echo "   -> Apply update -> Apply from ADB"
echo "3. Натисніть ENTER у цьому терміналі, коли телефон буде готовий до Sideload."
echo "=================================================================="
read -p "Натисніть ENTER для запуску 'adb sideload'..."

echo "[4/4] Завантаження повної системи LineageOS через ADB Sideload..."
adb wait-for-sideload
adb sideload lineage-23.2-20261010-nightly-bramble-signed.zip

echo "🎉 ГОТОВО! Виберіть 'Reboot system now' на екрані пристрою."
