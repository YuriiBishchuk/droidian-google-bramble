# 🤖 Droidian (Halium 11) Porting Architecture for Google Pixel 4a (5G) (bramble)

## 1. Концепція та цілі
Мета проєкту — перетворити Google Pixel 4a (5G) на щоденний швидкий мобільний Linux-смартфон завдяки використанню **Droidian** (Debian GNU/Linux для мобільних) у тандемі з **Halium 11 GSI** через контейнер вендора та бібліотеку `libhybris` для Android HAL сервісів, а також **нативний Mesa Turnip Vulkan** для GPU прискорення десктопу.

### Що це вирішує:
1. **Нативне апаратне прискорення GPU Adreno 620 (НОВЕ — 2026-10-12):**
   - Wayland-композитор `phoc` (wlroots) рендериться **напряму через Mesa Turnip Vulkan 1.3** на `/dev/kgsl-3d0` (Qualcomm KGSL).
   - **Результат:** 60 FPS анімації, плавний скролінг, CPU load ~1–4%, жодного Libhybris/EGL прослойки для десктопу.
2. **Android HAL сервіси через Halium / libhybris:**
   - `hwservicemanager`, `vndservicemanager`, `vendor.qti.hardware.display.composer-service` (HWC2) — працюють в контейнері Android vendor.
   - Використовуються для Hardware Composer 2 (HWC2), Sensors, Audio — НЕ для GPU рендерингу десктопу.
3. **Датчики (Sensors):**
   - Робота через `sensorfw` та плагін `hybris-sensor` (очікує запуску).
   - Автоповорот екрана, регулювання яскравості, датчик наближення.
4. **Аудіо:**
   - Використання `pulseaudio-modules-droid` або `pipewire-module-spa-droid` для взаємодії з рідним Android Audio HAL (`audio.primary.lito.so`).
5. **Мобільний зв'язок (Модем / RIL):**
   - Дзвінки, SMS та 4G мобільний інтернет через `ofono` + `ofono-binder-plugin` через рідний сервіс `rild`.

---

## 2. Структура адаптації Droidian
```
ports/droidian-halium/
├── boot/                        # Генератор boot.img та vendor_boot.img (Halium initramfs)
│   ├── build_boot.sh            # Скрипт збірки образів завантажувача
│   └── cmdline.txt              # Аргументи ядра для Droidian
├── adaptation-google-bramble/   # Пакет адаптації пристрою
│   ├── sparse/                  # Оверлей файлової системи для кореневого розділу
│   │   ├── etc/
│   │   │   ├── droidian/        # Конфігурація Droidian (модель, архітектура, вендор)
│   │   │   ├── environment      # Глобальні змінні: VK_ICD_FILENAMES, TU_DEBUG, WLR_RENDERER=vulkan
│   │   │   ├── phosh/phoc.ini   # Конфігурація композитора (scale=2.75, xwayland=true)
│   │   │   └── udev/rules.d/    # Правила udev для пристроїв Android
│   │   └── usr/lib/
│   │       ├── libfix_drm_formats.so   # DRM/Vulkan fix: autorefresh, format mods, VK_EXT_physical_device_drm
│   │       └── libfix_bionic_tls.so    # Bionic TLS fix: SIGSEGV 0x820 prevention
│   └── README.md
```

---

## 3. Компоненти системи
1. **Ядро та дерево пристроїв:**
   - Наше перевірене ядро `android_kernel_google_redbull` (LineageOS 23.2, Linux 4.19.325).
   - Готовий конфіг `config-google-bramble.aarch64` з увімкненими опціями для Halium (`CONFIG_ANDROID_BINDER_IPC=y`, cgroups, namespace).
2. **Образи для прошивки:**
   - **Boot / Vendor Boot:** Header v3 з `halium-boot` ramdisk.
   - **System:** `droidian-rootfs-api30-arm64.tar.xz` (Debian rootfs).
   - **Vendor:** Рідний розділ вендора Pixel 4a (5G) (Android 13, API 33).

---

## 4. Покроковий план реалізації
- [x] **Крок 1:** Створення `droidian-device-google-bramble` адаптації (ручне налаштування sparse overlay).
- [x] **Крок 2:** Адаптація `halium-boot` ramdisk під Boot Header v3 (інтеграція з `mkbootimg`).
- [x] **Крок 3:** Нативний Vulkan через Mesa Turnip на KGSL (`/dev/kgsl-3d0`) — **ВИКОНАНО**.
- [x] **Крок 4:** Phoc + Phosh на wlroots Vulkan рендерері — **ВИКОНАНО**.
- [ ] **Крок 5:** Інтеграція сенсорів через `sensorfw` та аудіо через PipeWire/PulseAudio droid-модулі.
- [ ] **Крок 6:** Модем (oFono + ModemManager) та Bluetooth.
- [ ] **Крок 7:** Збірка повної прошивки (flashable ZIP / fastboot images).

---

## 5. Поточний статус (13 жовтня 2026)
- ✅ Phoc + Phosh на 60 FPS через Turnip Vulkan (Adreno 620)
- ✅ Touchscreen, Backlight, Battery, Buttons
- ✅ Android HWC2 сервіси (hwservicemanager, vndservicemanager, composer-service)
- ⚠️ Firefox крашиться через Glycin (GTK4 Wayland compositor library)
- ⚠️ Audio, Sensors, Modem, Wi-Fi, Bluetooth — в процесі інтеграції