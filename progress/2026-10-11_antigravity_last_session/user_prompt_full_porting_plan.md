можна продовжити з якимось обмеженнями щоб смсиема знову не зависла? і я щераз тобі нагадаю промт з яким ти працював в минілій сесії (# АРХІТЕКТУРНИЙ ПЛАН-ЗАВДАННЯ: ПОЕТАПНИЙ BRING-UP LINUX ТА HALIUM/DROIDIAN НА GOOGLE PIXEL 4A (5G)

Ти — спеціаліст із Embedded Linux, розробник портів для postmarketOS та систем на базі Halium/libhybris. Твоє завдання — реалізувати покроковий запуск Linux на смартфоні Google Pixel 4a (5G), спираючись на вже встановлену на пристрої LineageOS та виключаючи «сліпе» налагодження на етапі логотипа завантажувача.

---

## 1. КЛЮЧОВІ ВИСНОВКИ ТА ВХІДНІ ДАНІ (ARCHITECTURAL CONTEXT)

1. **Апаратна ієрархія:**
   - Модель: Google Pixel 4a (5G) (кодове ім'я `bramble`, у pmOS: `google-bramble`).
   - Спільна платформа материнської плати: Qualcomm Snapdragon 765G / SM7250 (`redbull` / `lito`).
   - Ядро: спільне для Pixel 4a 5G та Pixel 5 (`android_kernel_google_redbull`).
2. **Поточний стан смартфона (LineageOS On-Board):**
   - На телефоні вже встановлена та стабільно функціонує LineageOS.
   - Розділи `vendor_boot`, `dtbo`, `vendor`, `super` та завантажувач `abl` уже налаштовані й працездатні.
   - **Правило 100% сумісності:** гілка вихідників ядра **МАЄ СТРОГО ЗБІГАТИСЯ** з версією поточної LineageOS на телефоні (наприклад, `lineage-21.0` для Android 14 або `lineage-20.0` для Android 13). Звірити: `adb shell getprop ro.lineage.build.version`.
3. **Чому кастомні образи зависали на логотипі Google (Root Causes):**
   - **Boot Image Header Version 3:** Завантажувач Pixel вимагає суворо Header v3. `boot.img` містить лише ядро та generic ramdisk; дерево пристроїв (DTB) і службові параметри виносяться у `vendor_boot`.
   - **Залежність від модулів:** У стоці ключові драйвери (дисплей DRM, шини, регулятори живлення) зібрані як модулі `.ko` у `vendor_boot`. Якщо ядро стартує без них — воно зависає. Рішення: скомпілювати їх монолітно в ядро (`=y`).
   - **Вимкнений екранний лог:** Консоль за замовчуванням спрямована в апаратно закритий UART (`ttyMSM0`). Рішення: примусово увімкнути екранний фреймбуфер (`CONFIG_VT=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y`, `console=tty0`).
4. **Стратегія Bring-up («Розділяй і володарюй»):**
   - **Фаза I (postmarketOS Downstream):** Отримати чистий старт ядра, логи на екрані та доступ по SSH через USB за 1–2 дні (без важких контейнерів Android, без systemd, без libhybris).
   - **Фаза II (Апаратний аудит):** Прямо з живої SSH-сесії зняти точну розмітку пам'яті UFS та структуру `/vendor` від LineageOS.
   - **Фаза III (Адаптація ядра):** Додати в це ж робоче ядро вимоги Halium (`CONFIG_ANDROID_BINDER_IPC`, `cgroups`, `namespaces`).
   - **Фаза IV (Halium / Droidian):** Запустити Android-контейнер з наявним `/vendor`, протестувати `libhybris` (рідний 3D-прискорювач Adreno 620) та підняти Phosh.

---

## 2. ОФІЦІЙНІ РЕСУРСИ ТА ДЖЕРЕЛА КОДУ

- **Документація postmarketOS:**
  - Керівництво зі створення Downstream-ядер: https://wiki.nura.eco/wiki/Porting_to_a_new_device/Kernel_package/Downstream (дзеркало: https://wiki.postmarketos.org/wiki/Porting_to_a_new_device/Kernel_package/Downstream)
  - Профіль пристрою Bramble: https://wiki.postmarketos.org/wiki/Google_Pixel_4a_(5G)_(google-bramble)
  - Документація pmbootstrap: https://wiki.postmarketos.org/wiki/Pmbootstrap
- **Документація Halium та Droidian:**
  - Документація Halium: https://docs.halium.org/
  - Скрипт валідації ядра: https://github.com/Halium/halium-devices/blob/halium-9.0/check-kernel-config
  - Посібник із портування Droidian: https://docs.droidian.org/porting-guide/
- **Репозиторії LineageOS & TheMuppets:**
  - Ядро та DTB: https://github.com/LineageOS/android_kernel_google_redbull
  - Дерево пристрою: https://github.com/LineageOS/android_device_google_bramble
  - Базова платформа: https://github.com/LineageOS/android_device_google_redbull
  - Вендорні блоби: https://github.com/TheMuppets/proprietary_vendor_google_bramble та https://github.com/TheMuppets/proprietary_vendor_google_redbull

---

## 3. ПОКРОКОВИЙ ПЛАН РЕАЛІЗАЦІЇ

### КРОК 0. Фіксація версії та страховий бекап
1. Визначити точну версію встановленої LineageOS:
   ```bash
   adb shell getprop ro.lineage.build.version
   ```
2. Зняти бекап поточних робочих завантажувальних розділів:
   ```bash
   adb shell su -c "dd if=/dev/block/by-name/boot_a of=/sdcard/stock_boot_a.img"
   adb shell su -c "dd if=/dev/block/by-name/vendor_boot_a of=/sdcard/stock_vendor_boot_a.img"
   adb pull /sdcard/stock_boot_a.img .
   adb pull /sdcard/stock_vendor_boot_a.img .
   ```

---

### ФАЗА I. DOWNSTREAM BRING-UP (Прорив через логотип завантажувача)
**Мета:** Отримати живий вивід `dmesg` на екран та робочий доступ по SSH по USB.

1. **Ініціалізація середовища `pmbootstrap`:**
   ```bash
   pip install --user pmbootstrap
   pmbootstrap init
   ```
   *(Канал `edge`, виробник `google`, назва `bramble`)*.
2. **Створення пакета `device-google-bramble`:**
   У `device/testing/device-google-bramble/deviceinfo`:
   ```sh
   deviceinfo_format_version="0"
   deviceinfo_name="Google Pixel 4a (5G)"
   deviceinfo_manufacturer="Google"
   deviceinfo_codename="google-bramble"
   deviceinfo_arch="aarch64"
   
   # Суворо downstream
   deviceinfo_kernel_source="downstream"
   
   # Завантажувач Pixel Header v3 (КРИТИЧНО)
   deviceinfo_boot_img_header_version="3"
   deviceinfo_flash_method="fastboot"
   deviceinfo_kernel_cmdline="console=tty0 androidboot.selinux=permissive"
   deviceinfo_screen_width="1080"
   deviceinfo_screen_height="2340"
   ```
3. **Пакет ядра `linux-google-bramble` (суворо за гайдом Kernel_package/Downstream):**
   - Вихідники: `LineageOS/android_kernel_google_redbull` (гілка збігається з версією LineageOS на телефоні).
   - Компілятор: Android Clang (LLVM).
   - Базовий дефконфіг: `arch/arm64/configs/redbull_defconfig`.
   - **Обов'язкові зміни в конфігурації:**
     - Монолітні драйвери замість модулів:
       `CONFIG_DRM_MSM=y`, `CONFIG_I2C=y`, `CONFIG_SPMI=y`, `CONFIG_REGULATOR=y`
     - Екранні логи:
       `CONFIG_VT=y`, `CONFIG_VT_CONSOLE=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y`, `CONFIG_FB_SIMPLE=y`
     - Мережа по USB:
       `CONFIG_USB_GADGET=y`, `CONFIG_USB_CONFIGFS=y`, `CONFIG_USB_CONFIGFS_RNDIS=y`
4. **Збірка та безпечне завантаження в RAM (без прошивки флешу):**
   ```bash
   pmbootstrap build linux-google-bramble
   pmbootstrap install --no-fde --ui=none
   pmbootstrap flasher boot
   ```
   *Критерій успіху Фази I:* Рядки логів біжать на екрані телефона; є відповідь на `ping 172.16.42.1`; успішний вхід по `telnet 172.16.42.1` або `ssh user@172.16.42.1`.

---

### ФАЗА II. АПАРАТНИЙ АУДИТ З ЖИВОЇ СИСТЕМИ
**Мета:** Зняти всі параметри заліза через SSH перед переходом до Halium.

Підключившись через SSH до працюючого телефона:
1. **Зняти точну карту розділів пам'яті UFS:**
   ```bash
   ls -l /dev/block/by-name/
   ```
   *(Зафіксувати точні шляхи до `super`, `userdata`, `vendor`)*.
2. **Змонтувати розділ `/vendor` від наявної LineageOS:**
   ```bash
   mkdir -p /mnt/vendor
   mount -o ro /dev/block/by-name/vendor /mnt/vendor
   ls -la /mnt/vendor/lib64/hw/
   ```
   *(Перевірити назви бібліотек Adreno `libGLES_adreno.so` та версії Audio HAL)*.
3. **Перевірити роботу тачскріна:**
   ```bash
   evtest /dev/input/event*
   ```

---

### ФАЗА III. АДАПТАЦІЯ ЯДРА ПІД HALIUM
**Мета:** Додати в робоче ядро підтримку контейнерів та Android IPC.

1. **Додати опції в конфігурацію ядра:**
   ```kconfig
   # Вимоги systemd
   CONFIG_DEVTMPFS=y
   CONFIG_DEVTMPFS_MOUNT=y
   CONFIG_CGROUPS=y
   CONFIG_NAMESPACES=y
   CONFIG_AUTOFS4_FS=y

   # Вимоги Halium / Android IPC
   CONFIG_ANDROID_BINDER_IPC=y
   CONFIG_ANDROID_BINDERFS=y
   CONFIG_ASHMEM=y
   ```
2. **Верифікація конфігурації:**
   Перевірити конфіг через скрипт `check-kernel-config` від Halium.

---

### ФАЗА IV. РОЗГОРТАННЯ DROIDIAN ТА ЗАПУСК LIBHYBRIS
**Мета:** Отримати повноцінний інтерфейс Phosh з апаратним 3D-прискоренням Adreno.

1. **Розгортання системи:**
   - Розгорнути generic ARM64 rootfs Droidian у розділ даних.
   - Залишити розділ `/vendor` від поточної LineageOS недоторканим.
2. **Запуск та перевірка контейнера:**
   - Переконатися, що служба `droid-hal-init` / LXC стартувала і створила ноди:
     ```bash
     ls -l /dev/binder /dev/hwbinder /dev/vndbinder
     ```
3. **Тестування драйверів `libhybris`:**
   - Виконати перевірку графічного пайплайна:
     ```bash
     test_egl
     test_glesv2
     ```
4. **Старт графічної оболонки:**
   ```bash
   systemctl start phosh
   ```

---

Почни з **Кроку 0** (уточни версію встановленої LineageOS) та переходь до реалізації **Фази I** згідно з інструкціями https://wiki.nura.eco/wiki/Porting_to_a_new_device/Kernel_package/Downstream.)