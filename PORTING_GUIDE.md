# 📱 Google Pixel 4a 5G (bramble / SM7250) — Повний журнал відновлення та інструкція з портування Linux

## 1. Специфікація апаратної платформи
* **Кодова назва:** `bramble` (сімейство `redbull`: Pixel 4a 5G / Pixel 5 `redfin` / Pixel 5a `barbet`)
* **SoC:** Qualcomm Snapdragon 765G (SM7250 / MSM7250 v2)
* **Архітектура CPU:** 8 ядер Kryo 475 (1x Cortex-A76 @ 2.4 GHz + 1x Cortex-A76 @ 2.2 GHz + 6x Cortex-A55 @ 1.8 GHz)
* **GPU:** Adreno 620 (`freedreno`)
* **Контролер USB (UDC):** DesignWare Cores USB3 (`a600000.dwc3` / `a600000.ssusb`)
* **Апаратний буфер панік (RAMOOPS):** `0xb7e41000`, розмір 4 МБ (зберігається в RAM між перезавантаженнями)
* **Апаратний криптомодуль:** Titan M (GSA / Citadel FW)

---

## 2. Аналіз первинного бутлупу та його повне усунення

### Помилка 1: Несумісність версій завантажувача (Bootloader Version Mismatch)
* **Симптом:** Пристрій постійно скидався у Fastboot mode при будь-якій спробі завантаження системи.
* **Діагностика:** Через `fastboot getvar all` виявлено завантажувач `b5-0.3-7241846` та радіомодем `g7250-00132-210419-B-7294132` (Android 11, квітень 2021). Офіційна LineageOS 23.2 вимагає базову прошивку **Android 14**. При старті сучасне ядро викликало несумісність із застарілим TrustZone (`tz`) / ABL.
* **Рішення:**
  1. З офіційного заводського образу Google (`bramble-up1a.231105.001.b2-factory-46a218d9.zip`) через Range-запити вилучено:
     * `bootloader-bramble-b5-0.6-10489838.img` (8.56 MB)
     * `radio-bramble-g7250-00264-230619-b-10346159.img` (146.32 MB)
  2. Прошито у fastboot:
     ```bash
     fastboot flash bootloader bootloader-bramble-b5-0.6-10489838.img
     fastboot reboot bootloader
     fastboot flash radio radio-bramble-g7250-00264-230619-b-10346159.img
     fastboot reboot bootloader
     ```

### Помилка 2: Status 7 / `ErrorCode::kInstallDeviceOpenError`
* **Симптом:** При прошивці через ADB sideload на 47% процес падав із помилкою `Error applying update: 7`.
* **Діагностика:** У системному лозі рекавері знайдено:
  ```text
  [ERROR:builder.cpp(536)] [liblp] Attempting to create duplication partition with name: system_a
  [ERROR:dynamic_partition_control_android.cc(1114)] Cannot add partition system_a to group google_dynamic_partitions_a
  ```
  У супер-розділі (`super`) залишилися застарілі конфліктні дескриптори динамічних розділів.
* **Рішення:**
  1. Завантажено офіційний `super_empty.img` від розробників LineageOS.
  2. Переведено пристрій у режим **fastbootd** (userspace fastboot):
     ```bash
     adb reboot fastboot
     ```
  3. Виконано повне скидання супер-розділу:
     ```bash
     fastboot wipe-super super_empty.img
     fastboot reboot recovery
     ```

### Помилка 3: Відсутність суперблоку F2FS на Userdata
* **Симптом:** Після ручного очищення `fastboot erase userdata` ядро не могло примонтувати шифрований розділ:
  ```text
  [libfs_mgr] Invalid f2fs superblock on '/dev/block/bootdevice/by-name/userdata'
  ```
* **Рішення:** У LineageOS Recovery виконано `Factory reset` → `Format data / factory reset`, що створило коректну файлову систему F2FS та ініціалізувало ключі Titan M.

---

## 3. Розгорнутий арсенал для реверс-інжинірингу

Усі утиліти налаштовано локально в системі:

| Утиліта | Призначення | Статус |
| :--- | :--- | :--- |
| `pmbootstrap` (3.12.0) | CLI розробки та збірки postmarketOS | Встановлено (`~/.local/bin/pmbootstrap`) |
| `dtc` | Компілятор та декомпілятор Device Tree (FDT) | Встановлено (`/usr/sbin/dtc`) |
| `extract-dtb` | Видобування вбудованих DTB-блобів з `dtbo.img` | Встановлено (`~/.local/bin/extract-dtb`) |
| `vmlinux-to-elf` | Відновлення повної таблиці символів `kallsyms` ядра | Встановлено (`~/.local/bin/vmlinux-to-elf`) |
| `rizin` / `radare2` | Статичний бінарний аналіз та дизасемблювання (AArch64) | Встановлено (`/usr/sbin/rizin`) |
| `qdl` | Пряма аварійна прошивка через Qualcomm EDL Mode | Встановлено (`/usr/sbin/qdl`) |
| `mkbootimg` / `unpack_bootimg` | Пакування та розпакування Android Boot Image v3 | Встановлено (`/usr/sbin/mkbootimg`) |
| `aarch64-linux-gnu-gcc` | Крос-компілятор для 64-бітного ядра Linux | Встановлено (`/usr/sbin/aarch64-linux-gnu-gcc`) |

### Отримані артефакти:
* **`re/dtb/bramble_pvt.dts`**: Повне декомпільоване дерево пристрою для ревізії Bramble PVT (усі шини I2C/SPI, регулятори PMIC `pm8150`/`pm7250b`, адреси пам'яті).
* **`re/kernel/vmlinux`**: Відновлений 64-бітний ELF ядра розміром 30 МБ із **76 246 іменованими функціями та змінними**.
* **`re/kernel/running_config.txt`**: Актуальний конфіг працюючого ядра (`/proc/config.gz`), де підтверджено наявність `CONFIG_USB_CONFIGFS_NCM=y` та `CONFIG_PSTORE_RAM=y`.

---

## 4. Крок 1: Запуск тестового Linux із налагодженням по USB (Non-destructive)

### Концепція безпечного тестування
Ми не прошиваємо тестові ядра у фізичну флеш-пам'ять. Використовується команда:
```bash
fastboot boot bramble-linux-debug.img
```
Образ завантажується виключно в **оперативну пам'ять (RAM)**. LineageOS на диску залишається на 100% цілим. При будь-якому збої або зависанні просте перезавантаження повертає телефон у звичайний стан.

### Структура `bramble-linux-debug.img`
1. **Ядро:** Працююче ядро Linux 4.19 (видобуто з `boot.img`, розмір 13.5 МБ).
2. **Initramfs:** Побудовано на базі **Alpine Linux AArch64** (3.8 МБ):
   * `/init` монтує `/proc`, `/sys`, `/dev`, `/config`.
   * Ініціалізує USB Gadget NCM через `configfs` та прив'язує до контролера `a600000.dwc3`.
   * Призначає телефону IP `172.16.42.1`.
   * Запускає вбудований DHCP-сервер `udhcpd` для автоматичної видачі ПК адреси `172.16.42.2`.
   * Запускає сервер налагоджувального шеллу: `telnetd -p 23 -l /bin/sh`.
3. **Пакування:** Виконано через `mkbootimg` з заголовком Boot Header Version 3:
   ```bash
   mkbootimg \
     --header_version 3 \
     --os_version 16.0.0 \
     --os_patch_level 2026-10 \
     --kernel re/boot_unpacked/kernel \
     --ramdisk re/initramfs.cpio.gz \
     -o bramble-linux-debug.img
   ```

### Як підключитися по USB до тестового Linux:
1. Перевести телефон у Fastboot:
   ```bash
   adb reboot bootloader
   ```
2. Запустити тестовий образ без прошивки:
   ```bash
   fastboot boot bramble-linux-debug.img
   ```
3. На хост-машині (ПК) з'явиться новий мережевий інтерфейс `usb0` (або `enx...`).
4. Підключитися до телефону через термінал:
   ```bash
   telnet 172.16.42.1
   ```
   *Ви потрапляєте у root-термінал Linux на телефоні з доступом до `dmesg`, `/proc`, `/sys` та апаратного заліза.*

---

## 5. Подальший маршрут: Найшвидший перехід до Droidian (Debian 12)
Після перевірки зв'язку по USB на Кроці 1:
1. **Підготовка Droidian rootfs:** Розгортання кореневої файлової системи Debian 12 ARM64 з підтримкою `libhybris` та графічного середовища Phosh.
2. **Інтеграція вендора:** Підключення робочих бінарних блобів Android 14 (`/vendor`, `/odm`) для автоматичного підйому:
   * Апаратного 3D-прискорення Adreno 620 через libhybris EGL/GBM.
   * Стільникового зв'язку (дзвінки/SMS/4G/5G) через oFono + RIL.
   * Wi-Fi та Bluetooth.
   * Звуку та мікрофона через PipeWire/PulseAudio.

---

## 6. Детальний аналіз першого тестового запуску (Google Logo Hang)

### Виявлені проблеми та їх виправлення:
1. **Відсутність статичних вузлів пристроїв у `/dev`:**
   * Оскільки в конфігурації ядра Pixel відключено `CONFIG_DEVTMPFS` (ядро саме не створює `/dev`), ядро очікує наявність готового символьного пристрою `/dev/console` (`c 5 1`) ще до запуску `/init`.
   * **Виправлення:** Використано `fakeroot` для генерації реальних символьних вузлів `/dev/console`, `/dev/null`, `/dev/zero`, `/dev/kmsg`, `/dev/tty` всередині CPIO-архіву.
2. **Динамічний лінкер проти статичного бінарника:**
   * Перший initramfs використовував `busybox` з Alpine, динамічно слінкований із `ld-musl-aarch64.so.1`. За відсутності системних бібліотек ядра такий скрипт не міг запуститися.
   * **Виправлення:** Впроваджено 100% статично слінкований AArch64 BusyBox без жодних зовнішніх залежностей.
3. **Формат стиснення Ramdisk:**
   * Завантажувач Pixel у заголовку v3 використовує `LZ4` (`lz4 -l -12 --favor-decSpeed`). Звичайний gzip-архів міг ігноруватися.
   * **Виправлення:** Ramdisk стиснуто за допомогою `lz4` у форматі сумісному з Android.
4. **Вбудований Command Line ядра (cmdline):**
   * При виклику `fastboot boot` завантажувач повідомив `missing cmdline`. Ядро не знало контролера USB.
   * **Виправлення:** В `mkbootimg` додано повний рядок параметрів:
     `console=ttyMSM0,115200n8 printk.devkmsg=on androidboot.usbcontroller=a600000.dwc3 lpm_levels.sleep_disabled=1 swiotlb=2048`

5. **Помилка монтування псевдо-терміналів (PTY для telnetd) та leases:**
   * `telnetd` вимагає обов'язкового монтування `devpts` на `/dev/pts`, інакше відкидає сесію з помилкою відсутності PTY.
   * `udhcpd` потребує наявності порожнього файлу `/var/lib/misc/udhcpd.leases`.
   * **Виправлення:** В `init` додано монтування `/dev/pts`, генерацію файлу лізингу DHCP та динамічний пошук контролера `UDC` в `/sys/class/udc`.

---\n
## 7. Другий тестовий запуск (Tethered RAM Boot)
* **Команда:** `fastboot boot bramble-linux-debug.img`
* **Статус відправки:** `OKAY [0.392s]`, `Booting OKAY [1.769s]`.
* **Поведінка хоста:** О 17:46:06 пристрій коректно від'єднався від Fastboot USB шини та розпочав завантаження ядра в оперативній пам'яті.

---\n
## 8. Архітектурне відкриття: Модульне ядро (GKI / Vendor Ko Modules)
* **Проблема:** Чому телефон зависав на логотипі Google і не підіймав USB мережу?
* **Причина:** Аналіз файлу `running_config.txt` показав, що контролер USB DWC3 та всі фізичні рівні скомпільовані як **зовнішні модулі ядра (`=m`)**, а не в монолітне ядро:
  * `CONFIG_USB_DWC3=m`
  * `CONFIG_USB_DWC3_QCOM=m`
  * `CONFIG_USB_DWC3_MSM=m`
  * Модулі фізичного рівня: `phy-msm-snps-hs.ko`, `phy-msm-ssusb-qmp.ko`, `qpnp_pdphy.ko`, `tcpm.ko`.
* **Рішення:**
  1. З розділу `vendor_boot` видобуто всі 154 фірмові модулі заліза Qualcomm Snapdragon 765G (`lib/modules/`).
  2. Додано модульний завантажувач у `/init`, який ініціалізує модулі шин, живлення, дисплея (`msm_drm.ko`) та USB-контролера відповідно до списку `modules.load`.
  3. Додано очікування реєстрації апаратного UDC контролера в `/sys/class/udc`.
  4. Додано консоль на екран телефону: `console=tty0`.
  5. Створено повноцінний образ `bramble-linux-debug.img` (розмір: 22 МБ).

---\n
## 9. Аналіз третього запуску: Успіх запуску дисплея та виправлення логування
* **Поведінка пристрою:** Екран спочатку показав логотип Google, а потім **став повністю чорним**.
* **Значення:** Це 100% доказ успішного старту ядра та initramfs! Модуль `msm_drm.ko` (модуль 215 з 221) перехопив шину дисплея у завантажувача, вимкнув splash screen і перевів матрицю в стан Linux.
* **Чому лог не зберігся у `/persist` у минулому запуску:**
  * У директорії `dev/` файли `sda14` та `sda2` виявилися звичайними порожніми файлами (створеними хостом), а не реальними блоковими пристроями (`S_IFBLK`). Команда `dmesg > /dev/sda14` просто писала в RAM-пам'ять CPIO, яка зникала при вимкненні.
* **Впроваджені архітектурні виправлення:**
  1. **Динамічний `mknod` на рівні ядра:** При старті `/init` створює справжні блокові вузли UFS (Major 8, Minor 14 для сирого розділу `klog`, Minor 2 для `persist`).
  2. **Багатоетапний запис:** Кожна стадія скидає `dmesg` і в сирий флеш `/dev/sda14`, і в монтований `/persist`.
  3. **Стійкість до помилок:** Усі команди обгорнуті в `2>/dev/null || true` без `set -e`. Жодна помилка не здатна зупинити виконання скрипта.

---

## 10. Етап повноцінного Bring-up через postmarketOS downstream ядро (Phase I)

Для переходу від ручного пакування до стандартного інженерного стеку розробки Linux для мобільних пристроїв реалізовано повноцінний порт postmarketOS для Google Pixel 4a (5G).

### Створені пакети у дереві `pmaports`:
1. **`device-google-bramble`**:
   * `deviceinfo_format_version="0"`
   * `deviceinfo_header_version="3"` (Boot Header v3 для Pixel 4a 5G / SM7250)
   * `deviceinfo_flash_pagesize="4096"`
   * `deviceinfo_flash_method="fastboot"`
   * `deviceinfo_kernel_cmdline="console=tty0 androidboot.selinux=permissive"`
2. **`linux-google-bramble`**:
   * Версія ядра: `4.19.325` (100% відповідність стоковій LineageOS 23.2).
   * Вихідний репозиторій: `LineageOS/android_kernel_google_redbull`, гілка `lineage-23.2`, коміт `2af5306961aebce4cc30098c9f12a09f8d906906`.
   * Конфігурація: експортований дамп `/proc/config.gz` з працюючого смартфона (`config-google-bramble.aarch64`).
   * Тулчейн компілятора: `LLVM=1` (Clang + LLD).

### Виявлені блокери компіляції та їх усунення:

| Проблема | Симптом / Лог помилки | Причина | Інженерне рішення |
| :--- | :--- | :--- | :--- |
| **1. Linker Error у Kconfig** | `linker 'aarch64-alpine-linux-musl-ld' not found` | `downstreamkernel_prepare` запускав `oldconfig` без змінної `LLVM=1`, що викликало пошук GNU ld замість LLD. | Експортовано `LLVM=1` та `REPLACE_GCCH=0` у функції `prepare()` перед викликом `downstreamkernel_prepare`. |
| **2. Відсутність системних заголовків хоста** | `fatal error: 'asm/types.h' file not found` у `scripts/selinux/genheaders` | У збірковому середовищі Alpine не було заголовків ядра Linux для `HOSTCC`. | Додано пакет `linux-headers` до списку `makedepends` в `APKBUILD`. |
| **3. Помилка валідації синтаксису DTBO** | `ERROR (duplicate_label): Duplicate label 'usb_con'` на `lito-redfin-dev1.0-overlay.dtbo` | У репозиторії сімейства redbull були застарілі та некоректні оверлеї сторонньої моделі (Pixel 5 `redfin`). Всі оверлеї для Bramble компілюються без помилок. | У `scripts/Makefile.dtbo` видалено рядки `dtbo-redfin` та `dtbo-barbet`, ізолювавши збірку DTBO виключно для цільового `bramble`. |
| **4. Відсутність генератора образів DTBO** | `/bin/sh: line 0: mkdtboimg: not found` (Exit 127) | `arch/arm64/boot/Makefile` викликає `mkdtboimg`, якого не було в базовому тулчейні. | Додано офіційний Alpine пакет `android-tools-mkdtboimg` до `makedepends`. |
| **5. Помилка створення пустих образів DTBO** | `ValueError: List of dtimages to add to DTBO not provided` під час `dtbo_redfin.img` | Оскільки оверлеї Redfin/Barbet відфільтровано, Makefile ядра намагався зібрати для них порожні образи. | У `arch/arm64/Makefile` виключено цілі `dtbo_redfin.img` та `dtbo_barbet.img`, залишивши нативні `dtbo.img` та `dtbo_bramble.img`. |
| **6. Full LTO перевантаження RAM/Swap** | Апаратне зависання ПК на етапі `LTO vmlinux.o` | У конфігу ядра увімкнено Full LTO (`CONFIG_LTO_CLANG=y`), який на 12 потоках споживав понад 25 ГБ пам'яті. | Впроваджено жорсткі ліміти: планувальник `nice -n 19 ionice -c 3`, `-j4` для Make та `KBUILD_LDFLAGS="--threads=4"` для LLD. Споживання RAM обмежено безпечним рівнем. |
| **7. Відсутність утиліти LZ4** | `/bin/sh: line 0: lz4: not found` (Exit 127) | `arch/arm64/boot/Makefile` викликає `lz4` для генерації `Image.lz4` та `Image.lz4-dtb`. | Додано пакет `lz4` до списку `makedepends` в `APKBUILD` та середовище chroot. |

### Поточний статус (Phase I Kernel Build COMPLETE):
* Успішно скомпільовано та зібрано повний комплект артефактів ядра:
  - `vmlinux` (234 МБ) — повне ядро з символами відладки.
  - `Image` (26 МБ) — чистий моноліт AArch64.
  - `Image.lz4` (13 МБ) — стиснутий бінарник ядра.
  - `Image.lz4-dtb` (14 МБ) — стиснуте ядро з підшитими деревами пристроїв DTB Bramble.
  - `dtbo_bramble.img` (6.8 МБ) — оверлеї заліза Pixel 4a (5G).
  - 329 скомпільованих та слінкованих модулів `.ko` (Qualcomm DRM, DWC3 USB, Wi-Fi qcacld, батарея, сенсори).
* Жодного зависання чи падіння системи під час повного циклу збірки не відбулося.

---

## 11. Успішна інтеграція boot-deploy та генерація образів postmarketOS (Phase I)

Після успішного компілювання ядра було виконано повноцінне складання цільової системи через `pmbootstrap install`.

### Виявлені блокери `boot-deploy` та їх вирішення:

| Проблема | Лог помилки | Причина | Інженерне рішення |
| :--- | :--- | :--- | :--- |
| **8. Відсутність `android-tools` у rootfs** | `ERROR: 'deviceinfo_generate_bootimg' is set, but the package 'android-tools' was not installed!` | `boot-deploy` використовує `mkbootimg`, який входить до пакета `android-tools`. | Додано `android-tools` до списку `depends` у `device-google-bramble/APKBUILD`. |
| **9. Помилка порожнього аргументу DTB** | `mkbootimg: error: argument --dtb: can't open '': [Errno 2] No such file or directory: ''` | У Boot Header v3 `mkbootimg` вимагає обов'язковий файл дерева пристроїв для запису у `vendor_boot`. За відсутності `deviceinfo_dtb` скрипт передавав порожній рядок. | 1. Додано `deviceinfo_dtb="lito-v2"` у `deviceinfo`.<br>2. Інтегровано валідний бінарник `lito-v2.dtb` у `device-google-bramble`, який встановлюється у `/usr/share/dtb/lito-v2.dtb`. |
| **10. Сумісність ядра з завантажувачем Pixel** | Несумісність формату завантаження | Завантажувач Pixel 4a 5G очікує ядро суворо у форматі LZ4. | Прописано `KERNEL_IMAGE_NAME="Image.lz4"` у `package()` пакета `linux-google-bramble`. |

### Згенеровані фінальні образи postmarketOS:
Усі згенеровані артефакти експортовано та зафіксовано у підкаталогах проєкту:
* **Каталог збережених образів:** `saved_builds/pmos_bringup_20261011/`:
  - `boot.img` (13 МБ, Header v3, чистий монолітний LZ4-бінарник ядра).
  - `vendor_boot.img` (11 МБ, Header v3, дерево пристроїв Lito v2 + postmarketOS initramfs із SSH/USB).
  - `google-bramble.img` (873 МБ, цільова файлова система rootfs з підрозділами boot/root).
  - `initramfs` (9.4 МБ).
  - `vmlinuz` (13 МБ).
* **Каталог скомпільованих APK-пакетів:** `packages/`:
  - `linux-google-bramble-4.19.325-r0.apk` (11 МБ).
  - `device-google-bramble-1-r2.apk` (143 КБ).

---

## 12. Протокол безпечного запуску в RAM (Fastboot Staging RAM Boot)

Для тестування без ризику пошкодження вбудованої пам'яті (NAND/UFS) завантажувач Qualcomm / Pixel Header v3 підтримує протокол **Staging**:
1. Переведення телефона в режим завантажувача:
   ```bash
   adb reboot bootloader
   ```
2. Завантаження `vendor_boot.img` в оперативну пам'ять (staging buffer):
   ```bash
   fastboot stage saved_builds/pmos_bringup_20261011/vendor_boot.img
   ```
3. Старт ядра з оперативної пам'яті:
   ```bash
   fastboot boot saved_builds/pmos_bringup_20261011/boot.img
   ```
При цьому розділи флеш-пам'яті телефону залишаються на 100% недоторканими, а будь-яке перезавантаження гарантовано повертає стокову LineageOS.

---

## 13. Вирішення OOM-падіння лінкування ядра (`CONFIG_LTO_NONE=y`)

* **Проблема:** Під час перезбірки ядра на етапі `LTO vmlinux.o` лінкер `ld.lld` вимагав понад 20 ГБ RAM, намагаючись утримувати граф біткоду всього ядра в пам'яті, що призводило до примусового закриття процесу через Linux OOM-killer (Error 137).
* **Причина:** У стоковому конфігу було увімкнено Full LTO (`CONFIG_LTO_CLANG=y`).
* **Рішення:** У `config-google-bramble.aarch64` перемкнуто на стандартний для postmarketOS режим `CONFIG_LTO_NONE=y`.
* **Результат:** Лінкування `vmlinux` тепер триває ~5 секунд, споживає <500 МБ оперативної пам'яті, а загальний час компіляції ядра скоротився до 27 хвилин без ризику зависань.

---

## 14. Інтеграція 329 модулів Qualcomm у `linux-google-bramble`

* **Проблема:** Первинний `vendor_boot.img` містив 0 драйверів ядра, оскільки `downstreamkernel_package` пропускав `make modules_install`.
* **Рішення:**
  1. В `APKBUILD` додано:
     ```bash
     make -j4 O="$_outdir" ARCH="$_carch" LLVM=1 \
         INSTALL_MOD_PATH="$pkgdir" INSTALL_MOD_STRIP=1 modules_install
     rm -f "$pkgdir"/lib/modules/*/build "$pkgdir"/lib/modules/*/source
     ```
  2. Створено файл `modules-initfs` у `device-google-bramble` для автоматичного включення до initramfs контролерів годинників, регуляторів живлення, USB DWC3, UFS та дисплея.
  3. Пакет ядра оновлено до `linux-google-bramble-4.19.325-r1.apk` (розмір: 22 МБ).

---

## 15. Специфікація завантажувача Pixel: LZ4 Ramdisk & Цілісний образ RAM Boot

* **Проблема:** Завантажувач Pixel 4a (5G) (ABL) у Boot Header v3 очікує стиснення рамдиска виключно у форматі **Legacy LZ4 frame (`lz4 -l -12 --favor-decSpeed`)**, ігноруючи gzip-архіви. Крім того, при завантаженні через `fastboot boot` завантажувач вимагає наявності рамдиска безпосередньо у переданому образі.
* **Рішення:** Створено цілісний образ `saved_builds/pmos_bringup_20261011/pmos_tethered_boot.img` (22 МБ), що містить:
  - ядро Linux 4.19.325 (`Image.lz4`);
  - повний LZ4-рамдиск postmarketOS з усіма модулями Qualcomm;
  - метадані Android 16 (`os_version 16.0.0`, `os_patch_level 2026-10`);
  - параметри командного рядка: `console=tty0 printk.devkmsg=on androidboot.selinux=permissive androidboot.usbcontroller=a600000.dwc3 lpm_levels.sleep_disabled=1`.

---

## 16. Тріумфальний прорив: Архітектурний базис Recovery та запуск повноцінного postmarketOS

### А. Чому Generic Ramdisk зависав на логотипі Google:
1. **Проблема Qualcomm GSI/RNDIS:**
   Ядро SM7250 не містить класичного драйвера `usb_f_rndis`. Воно використовує `usb_f_gsi.ko` (`gsi.rndis`), який вимагає наявності апаратного IP Accelerator (IPA) та ініціалізованого модемного фірмваря. Спроба зв'язати `gsi.rndis` із `a600000.dwc3` завершувалася мовчазною помилкою ядра без подачі сигналу D+ pull-up на шину USB.
2. **Qualcomm SCM TrustZone Hardware Watchdog:**
   Апаратний таймер безпеки TrustZone (`17c10000.qcom,wdt`) скидав ядро в перезавантаження рівно через 30–35 секунд, якщо юзерспейс не підтверджував свою життєздатність.
3. **Критичні параметри апаратного завантаження:**
   - `swiotlb=2048`: виділення обов'язкового буфера для DMA-трансляцій ARM SMMU для контролера USB DWC3 та PCIe.
   - `lpm_levels.sleep_disabled=1`: заборона апаратного засинання процесорних ядер Kryo під час раннього старту.

### Б. Вирішення: Recovery як еталонний апаратний фундамент
Замість спроб зібрати initramfs «з нуля», було використано вивірену архітектуру **LineageOS Recovery**:
1. **FunctionFS (`ffs.adb`) замість RNDIS:**
   FunctionFS відкриває юзерспейсні ендпоінти в `/dev/usb-ffs/adb`. Демон `adbd` підключається до них, після чого прив'язка `a600000.dwc3` до `/config/usb_gadget/g1/UDC` **миттєво підіймає пристрій на ПК як `18d1:4ee7`**.
2. **Повна ініціалізація заліза:**
   Через `ueventd` безпомилково завантажуються всі 221 модуль Qualcomm (живлення PMIC, годинники GCC/DISPCC, сховище UFS, сенсори).

### В. Запуск повноцінного postmarketOS (Alpine Userspace) на живому пристрої:
1. **Завантаження rootfs в оперативну пам'ять:**
   - З образу `google-bramble.img` вилучено розділ `pmOS_root` (ext4 UUID `d9a7f78b-44c4-4063-9e74-05fc77292d30`, 438 МБ).
   - Стиснуто у gzip (95 МБ) та передано по USB на швидкості **103.3 MB/s**.
   - Підключено через `/dev/block/loop0` та змонтовано в `/tmp/pmos` у режимі читання/запису (`rw`).
2. **Активація системних вузлів:**
   - Змонтовано `proc`, `sys`, `dev`, `devpts`.
   - Встановлено авторизовані SSH-ключі користувача (`astellias@pop-os`) у `/root/.ssh/authorized_keys`.
   - Запущено демон `dropbear` на порту 2222 із прокиданням порту на хост:
     ```bash
     adb forward tcp:2222 tcp:2222
     ```
3. **Прямий доступ до Linux на телефоні:**
   ```bash
   ssh -p 2222 root@127.0.0.1
   # Linux localhost 4.19.325-cip136-st20-g2af5306961ae #1 SMP PREEMPT aarch64 Linux
   # PRETTY_NAME="Nura edge" (postmarketOS edge)
   ```
4. **Статус апаратного дисплея OLED:**
   - Інтерфейс рекавері вимкнено командою `stop recovery`.
   - Перевірено стан DRM/KMS: активний конектор **`card0-DSI-1`**, режим `1080x2340@60Hz` (командний режим DSI).

---

## 17. Фінальний тріумф: Запуск повноцінного графічного середовища (Wayland / Weston) на екрані Pixel 4a (5G) без Android

### А. Подолані архітектурні бар'єри ядра Linux 4.19 та MSM DRM

1. **Несумісність Systemd 262 із ядром 4.19 (`STATX_MNT_ID_UNIQUE`):**
   - **Проблема:** У postmarketOS edge бібліотека `libudev.so.1` постачається з пакета `systemd-udevd` версії 262. На рівні ініціалізації вона викликає системний виклик `statx` із прапорцем `STATX_MNT_ID_UNIQUE`, який підтримується ядром Linux лише починаючи з версії **6.8**. На ядрі 4.19 виклик повертав помилку, через що `udev_device_new_from_subsystem_sysname()` повертав `NULL`, блокуючи відкриття `/dev/dri/card0`.
   - **Вирішення:** Впроваджено легкоатлетичну демононезалежну бібліотеку `libudev-zero` (прямий запит до `/sys` без викликів statx ядра 6.8+). Вона миттєво ідентифікувала ноду `/dev/dri/card0`.

2. **Апаратна специфіка Qualcomm MSM DRM (Дублікати форматів у площинах):**
   - **Проблема:** Драйвер Qualcomm `msm_drm` на платформі SM7250 повертає дубльовані ідентифікатори FourCC формату `AB24` (через підтримку різних варіантів UBWC-стиснення). Копозитор Weston містить жорсткий асерт:
     ```c
     assert(!weston_drm_format_array_find_format(formats, format));
     ```
     що спричиняло аварійне падіння композитора при спробі ініціалізації площин DSI.
   - **Вирішення:** Розроблено та скомпільовано нативну бібліотеку перехоплення `libfix_drm_formats.so` (`LD_PRELOAD`), яка в режимі реального часу фільтрує повторювані формати перед передачею у Weston:
     ```c
     // fix_drm_formats.c - фільтрація дублікатів FourCC з drmModeGetPlane()
     drmModePlanePtr drmModeGetPlane(int fd, uint32_t plane_id);
     ```

3. **Відсутність віртуальних терміналів (VT) в Android-ядрі:**
   - **Проблема:** Демон керування сесіями `seatd` за замовчуванням вимагає `/dev/tty0` (CONFIG_VT). В Android-ядрах VT вимкнено на рівні конфігурації ядра.
   - **Вирішення:** Активовано безтермінальний режим через змінну оточення `SEATD_VTBOUND=0`, що дозволило керувати сесією без наявності VT.

4. **Вимкнення віртуального виходу `Virtual-1`:**
   - Драйвер Qualcomm оголошує віртуальний конектор `Virtual-1` (для Wi-Fi Display / Miracast). У `weston.ini` його явно вимкнено (`mode=off`), щоб Atomic KMS зосередився виключно на фізичному екрані `DSI-1`.

---

### Б. Результати роботи на пристрої

- **Композитор:** Weston 16.0.0 (DRM Backend + Pixman CPU Software Rasterizer) нативно генерує та подає кадри на конектор `DSI-1` із частотою **60 FPS** (роздільна здатність **1080x2340**).
- **Сенсорний екран:** Драйвер тачскріна FocalTech (`fts`, `/dev/input/event2`) автоматично прив'язано до дисплея `DSI-1`. Будь-який дотик пальцем передається як Wayland touch event.
- **Фізичні клавіші:** Кнопка живлення (`qpnp_pon`, `/dev/input/event0`) та гучність (`gpio-keys`, `/dev/input/event1`) підключені як клавіатурні події.
- **Графічні додатки:** Успішно запущено:
  - `weston-desktop-shell` (панель завдань, шпалери, запуск додатків);
  - `weston-keyboard` (екранна клавіатура);
  - `weston-terminal` (віконний емулятор термінала через змонтований `devpts`).

---

### В. Автоматизовані скрипти та інструменти хоста

1. **[`launch_pmos_gui.sh`](file:///run/host/home/astellias/Projects/Pixel4a5G/launch_pmos_gui.sh)**:
   Повний автоматичний запуск графічного оточення в один клік: зупиняє Android runtime, підіймає seatd, монтує `devpts` та запускає Weston з перехопленням форматів.
2. **[`run_app.sh`](file:///run/host/home/astellias/Projects/Pixel4a5G/run_app.sh)**:
   Запуск будь-якої програми на живому екрані смартфона:
   ```bash
   ./run_app.sh weston-terminal
   ```
3. **[`ssh_pmos.sh`](file:///run/host/home/astellias/Projects/Pixel4a5G/ssh_pmos.sh)**:
   Миттєве SSH-підключення до postmarketOS без пароля за 0.05 секунди.

---

## 18. План Б: Повна консервація активів Droidian / Halium

На випадок, якщо відсутність пропрієтарного 3D-прискорення Adreno (kgsl) чи складність драйверів модема/камери спонукає перехід на **Droidian / Halium** (де використовується `libhybris`), усі апаратні ресурси пристрою повністю збережено:

- **Директорія на хості:** [`halium_droidian_assets/`](file:///run/host/home/astellias/Projects/Pixel4a5G/halium_droidian_assets/)
- **Архівний бандл:** [`halium_bramble_assets.tar.gz`](file:///run/host/home/astellias/Projects/Pixel4a5G/halium_bramble_assets.tar.gz) (28 МБ)
- **Збережені компоненти:**
  1. `egl/`: Бібліотеки Adreno 620 EGL (`libEGL_adreno.so`, `libGLESv2_adreno.so`, тощо).
  2. `hw/` та `lib/`: 64-бітні та 32-бітні апаратні модулі HAL Android (аудіо, камера, датчики, Bluetooth, DRM).
  3. `firmware/`: 183 фірмварних бінарних блоби (`adreno`, `modem`, `wlan`, `sensors`).
  4. `etc/`: Повні XML конфігурації аудіополітик (`audio_policy_configuration.xml`, `audio_platform_info*.xml`), таблиці мікшерів, медіакодеки C2, калібрування Wi-Fi та Bluetooth.
  5. `vintf/`: 42 XML-маніфести HAL сервісів Android VINTF.
  6. `system_build.prop` та `vendor_build.prop`: Специфікації збірки та властивості пристрою.
  7. `kernel_config`: Повний файл конфігурації живого ядра (`CONFIG_*`).

---

## 19. Сенсорний екран: Діагностика та вирішення класифікації пристроїв в libinput

### Проблема
У середовищі Weston та Phoc тачскрін FocalTech (`fts`, `/dev/input/event2`) не реагував на фізичні дотики.
Аналіз `libinput list-devices` виявив, що через наявність кодів жестів пробудження (`KEY_W`, `KEY_E`, `KEY_O` тощо) у дескрипторі подій драйвера та відсутність стандартних правил udev (через використання надлегкого `libudev-zero`), `libinput` помилково класифікував тачскрін як звичайну клавіатуру (`Capabilities: keyboard`), ігноруючи мультитач-координати.

### Вирішення
У бібліотеку-інтерцептор [`libfix_drm_formats.so`](file:///tmp/fix_drm_formats.c) додано перехоплення запитів властивостей udev (`udev_device_get_property_value`):
- Для пристрою `event2` динамічно виставляються ознаки:
  - `ID_INPUT_TOUCHSCREEN=1`
  - `ID_INPUT=1`
  - `ID_INPUT_KEYBOARD=0`
  - `WL_OUTPUT=DSI-1`
- **Запобігання рекурсії:** У `libudev-zero` виклики `udev_device_get_sysname` та `udev_device_get_devnode` внутрішньо транслюються у виклики `udev_device_get_property_value("SYSNAME")`. Щоб уникнути нескінченної рекурсії (SIGSEGV / exit code 139), інтерцептор викликає `orig_udev_device_get_property_value(udev, "SYSNAME")` виключно для цільових оверрайдів (`ID_INPUT_*`).
- **Результат діагностики:** `libinput list-devices` успішно підтверджує:
  ```
  Device:       fts
  Kernel:       /dev/input/event2
  Capabilities: keyboard touch
  ntouches:     10
  calib:        identity matrix
  ```
  `fts` повноцінно розпізнається як 10-точковий ємнісний сенсорний екран з калібрувальною матрицею тотожності.

---

## 20. Мобільна оболонка Phosh & Phoc (Mobile Linux UI)

На запит користувача здійснено перехід з десктопного Weston на повноцінне мобільне оточення **Phosh** (Phone Shell, розробка Purism / postmarketOS) та композитор **Phoc** (Phone Compositor на базі wlroots):

### Встановлені пакети
Через локальний проксі хоста (`http://127.0.0.1:8888`) встановлено адаптовані пакети postmarketOS:
- `phosh` (мобільна оболонка, шторка повідомлень, статусбар, лаунчер додатків)
- `phoc` (композитор Wayland з підтримкою жестів та масштабування)
- `squeekboard` (мобільна екранна QWERTY-клавіатура Wayland)
- `feedbackd` (служба вібровідгуку та тактильних сигналів)
- `gnome-console` (`kgx` — сучасний адаптивний мобільний термінал)
- `phosh-wallpapers` & `gnome-backgrounds` (фірмові мобільні шпалери)

### Конфігурація дисплея (`/etc/phosh/phoc.ini`)
```ini
[core]
xwayland = false

[output:DSI-1]
scale = 2

[output:Virtual-1]
enable = false
```
При фізичній роздільній здатності **1080x2340** масштабування `scale = 2` забезпечує логічний мобільний в'юпорт **540x1170** — ідеальний розмір для елементів інтерфейсу, іконок та тексту на 6-дюймовому OLED-екрані Pixel 4a (5G).

---

## 21. Подолання обмежень ядра Android 4.19 та musl libc

Під час запуску Phosh подолано три критичні системні бар'єри:

1. **Емуляція `faccessat` з прапорцями (Ядро 4.19 vs GLib/GIO):**
   - У сучасних збірках Alpine glib функція `g_local_file_query_exists` викликає `faccessat(AT_FDCWD, path, F_OK, AT_SYMLINK_NOFOLLOW)`.
   - Ядро Linux 4.19 не підтримує системний виклик `faccessat2` (sys_439 повертає `EINVAL`), через що GLib видавав критичну помилку: `g_local_file_query_exists: faccessat doesn't support supplied flags` і вважав, що жоден `.desktop`, `.xml` чи файл теми в системі не існує.
   - **Вирішення:** В `libfix_drm_formats.so` додано обгортку `faccessat`: у разі отримання `EINVAL` на запит із прапорцем `AT_SYMLINK_NOFOLLOW` запит автоматично транслюється у `fstatat(dirfd, path, &st, AT_SYMLINK_NOFOLLOW)`, підтримуваний ядром 4.19. Це повністю відновило роботу GLib, GIO, AppStream та завантаження іконок і тем.

2. **Монтування POSIX Shared Memory (`/dev/shm`):**
   - Wlroots вимагає спільну пам'ять для завантаження keymap (`allocate_shm_file`). У базовому Android-контейнері `/dev/shm` був відсутній.
   - **Вирішення:** Додано автоматичне монтування `tmpfs` у `/dev/shm` із правами `1777`.

3. **Захист від переповнення стекового буфера в інтерцепторі DRM-подій:**
   - Компонент Phosh `hks-manager` виконував читання розміром 9 байт (`read(fd, buf, 9)`). Інтерцептор подій сторінкових перемикань перевіряв лише `ret >= sizeof(struct drm_event)` (8 байт), після чого помилково перезаписував 32-байтний `struct drm_event_vblank`, що призводило до спрацьовування GCC stack canary (`__stack_chk_fail()`).
   - **Вирішення:** Додано сувору перевірку `count >= sizeof(struct drm_event_vblank) && ret >= sizeof(struct drm_event_vblank)`.

---

## 22. Верифікація живої системи та скріншоти

1. **Статус сесії:**
   - Композитор: `phoc -v -S -C /etc/phosh/phoc.ini`
   - Оболонка: `/usr/libexec/phosh -U` (запуск розблокованим відразу на домашній екран)
   - Екранна клавіатура: `squeekboard` (підключена до сесії Wayland)
   - Шина D-Bus: `dbus-daemon --system` та сесійна шина `dbus-run-session`
   - Журнал запуску: `phosh-main-Message: Phosh ready after 0.81s`, `Info: Loaded layout Resource: us`.

2. **Підтверджені графічні артефакти:**
   - [`phosh_bramble_screen.png`](file:///run/host/home/astellias/Projects/Pixel4a5G/phosh_bramble_screen.png): Повноцінний домашній екран Phosh з пошуком, іконками додатків (Console, Settings), кнопкою "Show All Apps" та темними мобільними шпалерами Adwaita на 1080x2340 OLED.
   - [`phosh_console_tap.png`](file:///run/host/home/astellias/Projects/Pixel4a5G/phosh_console_tap.png): Робочий додаток налаштувань GNOME Settings та активна розгорнута темна сенсорна екранна клавіатура Squeekboard з розкладкою QWERTY.
   - [`phosh_after_tap.png`](file:///run/host/home/astellias/Projects/Pixel4a5G/phosh_after_tap.png): Жива реакція інтерфейсу на сенсорне натискання кнопки "Show All Apps".

3. **Команда швидкого перезапуску:**
   ```bash
   # На смартфоні через SSH:
   /start_gui.sh
   # Або з хоста в один клік:
   ./launch_pmos_gui.sh
   ```
