# 📱 Google Pixel 4a (5G) (bramble) - Droidian Halium Hardware Audit & Notes

**Дата аудиту:** 12 жовтня 2026  
**Базова ОС:** Android 13 (API 33, `TQ3A.230901.001`)  
**Ядро:** `4.19.269-gdb4810fe97f0` (LineageOS 20 / AOSP 13)  
**Дистрибутив:** Droidian (Debian Trixie / Next, arm64)  
**Розміщення:** Фізичний диск UFS (`/data/halium-rootfs` на `/dev/block/sda19`, доступно ~98 ГБ)

---

## 1. Стан апаратних підсистем (Hardware Matrix)

| Компонент | Статус | Деталі та драйвери |
|---|---|---|
| **Дисплей (OLED 60Hz)** |  **ПРАЦЮЄ** | Роздільність `1080x2340`, DRM/KMS інтерфейс `DSI-1`, `/dev/dri/card0`. Працює з `libfix_drm_formats.so`. |
| **Сенсорний екран (Touch)** |  **ПРАЦЮЄ** | FocalTech FT5446 (`/dev/input/event2`). Працює через синтез udev (`/run/udev/data/c13:66`), точний мультитач. |
| **GPU (Adreno 620 3D)** |  **ПРАЦЮЄ** | Апаратний драйвер `libEGL_adreno.so` та `libGLESv2_adreno.so`. Падіння `SIGSEGV 0x820` подолано через `libfix_bionic_tls.so`. EGL розширення успішно виявляються. |
| **Акумулятор та живлення** |  **ПРАЦЮЄ** | Рідний драйвер ядра `google_battery` / `qpnp_smb5_charger`. Рівень заряду коректно читається (`/sys/class/power_supply/battery`). |
| **Кнопки живлення / гучності** |  **ПРАЦЮЄ** | `qpnp_pon` (Power key, `event0`) та `gpio-keys` (Volume Up/Down, `event1`). |
| **Яскравість (Backlight)** |  **ПРАЦЮЄ** | `/sys/class/backlight/panel0-backlight` (шкала 0–1023). |
| **Bluetooth** |  **ГОТОВО ДО СТАРТУ** | Виявляється через `rfkill` (`0: bt_power: Bluetooth`). Драйвер `bluetooth_power.ko` завантажений, очікує `rfkill unblock`. |
| **Wi-Fi** |  **В ПРОЦЕСІ** | Модуль `google_wlan_mac.ko` завантажений. Прошивки (`wlanmdsp.mbn`, `bdwlan-bramble.bin`) знаходяться у `/vendor/firmware/wlan`. Потребує запуску `rmt_storage` + `cnss-daemon` через binder. |
| **Аудіо (Динамік/Мікрофон)** |  **В ПРОЦЕСІ** | Встановлено `pulseaudio-modules-droid-hidl` та `pulseaudio-modules-droid-modern`. 334 модулі ядра (включаючи `snd-soc-cs35l41`, `wcd938x_dlkm`, `q6_dlkm`) розміщено в `/lib/modules/4.19.269-gdb4810fe97f0/`. Очікує запуск Android Audio HAL. |
| **Мобільний зв'язок (RIL / LTE / 5G)** |  **ГОТОВО В СИСТЕМІ** | Встановлено `ofono` + `ofono-binder-plugin` + `ofono2mm` (міст у ModemManager). Готово до роботи з `rild` вендора через `gbinder`. |
| **Датчики (Акселерометр, гіроскоп)** |  **ГОТОВО В СИСТЕМІ** | Встановлено `sensorfw-qt6` + `libssc2` (Qualcomm Snapdragon Sensor Core). |

---

## 2. Ключові відкриття та виправлені проблеми

### А. Розгортання файлів на диск (Відмова від `rootfs.img`)
- **Проблема**: Спочатку образ лежав як `rootfs.img` всередині `/data` і монтувався через loop-пристрій.
- **Діагностика**: У логах `dmesg` виявлено `audit: denied { read } for comm="loop0" ... scontext=u:r:kernel:s0`. SELinux Android забороняв ядру читати loop-файли.
- **Рішення**: Розпаковано корінь Droidian безпосередньо у теку `/data/halium-rootfs/` на UFS-пам'ять (`sda19`).
- **Результат**: Швидкість роботи зросла в рази (прямий UFS 2.1), доступні всі 98 ГБ пам'яті, немає блокувань loop.

### Б. Виправлення Bionic TLS Crash (`SIGSEGV 0x820`)
- **Проблема**: У Bionic libc Android 13 покажчик потоку звертається за адресою `[tpidr_el0 - 8]`, очікуючи структуру TLS Bionic. Під Linux glibc за цією адресою був NULL, що викликало миттєвий краш програми при завантаженні драйвера Adreno.
- **Рішення**: Створено легку C-бібліотеку `libfix_bionic_tls.so`, яка виділяє сторінку пам'яті та записує правильний покажчик у `[tpidr_el0 - 8]`. Додано у `/etc/ld.so.preload`.
- **Результат**: 0 падінь, Qualcomm Adreno 620 та драйвери вендора вантажаться бездоганно.

### В. Динамічні розділи Android (`super` partition)
- **Проблема**: Старий Halium очікував окремі файли `system.img` та `vendor.img`. У Pixel 4a (5G) вони запаковані в LP (Logical Partitions) усередині `sda18` (`super`).
- **Схема прив'язки**:
  - `/dev/block/dm-0` -> `system_a` (System-as-root, монтується `/system`)
  - `/dev/block/dm-3` -> `vendor_a` (Qualcomm HAL, драйвери, прошивки)
  - `/dev/block/dm-1` -> `product_a`
  - `/dev/block/dm-2` -> `system_ext_a`
  - `/data/apex_runtime/apex_payload.img` -> Bionic libc runtimes

### Г. Чому зависав Standalone Boot (на логотипі Google):
1. **Пропущено `boot=halium`**: Без цього прапорця Debian initramfs виконував ПК-скрипт `scripts/local` і чекав невідомий `root=`.
2. **Пропущено `androidboot.boot_devices=soc/1d84000.ufshc`**: Ядро не прив'язувало UFS-накопичувач на старті.
3. **Loop-образ SELinux**: Ядро блокувалося на ранній стадії через перевірки безпеки образу.

### Д. Гібридна графічна архітектура (Phoc DRM + Mesa Turnip Vulkan 1.3)
1. **Робочий стіл Phoc / Phosh**:
   - Працює нативно на Linux DRM KMS (`/dev/dri/card0`, DSI-1, 1080x2340@61.6Hz).
   - Повністю усунено збій виділення буферів (`wlr_drm_dumb_allocator_create` у `libfix_drm_formats.so`).
   - Відфільтровано віртуальний роз'єм `Virtual-1` (Miracast/WFD), що запобігає зайвим запитам режимів.
   - Створено `/data/local/tmp` для кешу іконок GTK4/Glycin.
   - Графічна оболонка Phosh повністю піднята й підтверджена скріншотом (`phosh_live_fresh.png`).
2. **Апаратне 3D та Ігри (Mesa Turnip Vulkan 1.3)**:
   - GPU: Qualcomm Adreno 620.
   - Драйвер: `Mesa 26.3.0-devel (git-98f3d6229d)`, Vulkan API 1.3.359.
   - Доступ: Напряму через вузол ядра `/dev/kgsl-3d0` (`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json`, `TU_DEBUG=kgsl`).
   - Будь-які важкі 3D-додатки, емулятори, ігри та браузери виконують рендеринг безпосередньо на GPU через Turnip.
3. **Android Display HAL (HWC2/HIDL)**:
   - Успішно піднято та перевірено всі 3 ключові демони: `hwservicemanager`, `vndservicemanager`, `vendor.qti.hardware.display.composer-service`.
   - Подолано переривання `ProcessState::setThreadPoolMaxThreadCount` за допомогою `libfix_binder_threadpool.so`.

---

## 3. Файли порту, збережені для повної прошивки (Flashable Firmware):
1. **[`adaptation-google-bramble/sparse/etc/phosh/phoc.ini`](file:///run/host/home/astellias/Projects/Pixel4a5G/ports/droidian-halium/adaptation-google-bramble/sparse/etc/phosh/phoc.ini)**:
   - Масштаб `scale = 2.75` для екрану 1080x2340.
   - `enable = false` для віртуального дисплея `Virtual-1`.
   - `xwayland = true` для сумісності з X11/Vulkan/GL додатками.
2. **[`adaptation-google-bramble/sparse/etc/environment`](file:///run/host/home/astellias/Projects/Pixel4a5G/ports/droidian-halium/adaptation-google-bramble/sparse/etc/environment)**:
   - Глобальна конфігурація `VK_ICD_FILENAMES`, `TU_DEBUG=kgsl` та `WLR_RENDERER=vulkan` для апаратного прискорення всього десктопу через Turnip Adreno 620.
3. **[`adaptation-google-bramble/sparse/usr/lib/`](file:///run/host/home/astellias/Projects/Pixel4a5G/ports/droidian-halium/adaptation-google-bramble/sparse/usr/lib/)**:
   - `libfix_drm_formats.so` — авто-рефреш OLED, захист від дублікатів форматів, ін'єкція DRM properties (226, 0) для Vulkan physical device match, фільтрація Virtual-1 та версіювання dmabuf v1.
   - `libfix_bionic_tls.so` — запобігання падінням Bionic libc TLS (`[tpidr_el0 - 8]`).
4. **[`start_droidian_live.sh`](file:///run/host/home/astellias/Projects/Pixel4a5G/ports/droidian-halium/start_droidian_live.sh)**:
   - Автоматичний скрипт швидкого підйому живої сесії в один клік з повноцінним GPU Vulkan рендерингом (Phoc + Phosh на Adreno 620).
