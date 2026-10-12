# 🚀 Звіт по завершенню Фази I (postmarketOS Bring-up для Pixel 4a 5G)
**Дата та час:** 11 жовтня 2026, 13:27  
**Цільовий пристрій:** Google Pixel 4a (5G) (`bramble`, SM7250 / Snapdragon 765G)  
**Базова ОС на пристрої:** LineageOS 23.2 (Android 16)  

---

## 1. Головні підсумки та досягнення

1. **Компіляція ядра пройшла на 100% без жодного зависання комп'ютера:**
   - Першопричину нічного зависання (Full LTO на 12 потоків без лімітів пам'яті, що викликало вичерпання 16 ГБ RAM + 16 ГБ Swap) усунуто.
   - Задіяно ліміти: `nice -n 19 ionice -c 3`, `make -j4`, `KBUILD_LDFLAGS="--threads=4"`. Вільна пам'ять трималася від 4 до 10 ГБ.
   - Усунуто відсутність `lz4` у збірковому середовищі.
   - Усі 329 модулів `.ko` Qualcomm (MSM DRM дисплей, DWC3 USB, Wi-Fi qcacld-3.0, батарея, сенсори) скомпільовано та слінковано.
2. **Вирішено блокери `boot-deploy` під час складання postmarketOS:**
   - Додано `android-tools` до `depends` пакета `device-google-bramble` для наявності `mkbootimg`.
   - Виправлено помилку `--dtb ""` для Boot Header v3: додано `deviceinfo_dtb="lito-v2"` та інтегровано бінарник `lito-v2.dtb` у пакет пристрою.
   - Забезпечено точну відповідність формату ядра: `KERNEL_IMAGE_NAME="Image.lz4"`.
3. **Генерація системи postmarketOS завершилася з кодом 0 (`DONE!`):**
   - Створено валідні образи Android Boot Header v3: `boot.img` (13 МБ) та `vendor_boot.img` (11 МБ).
   - Створено повноцінний образ файлової системи `google-bramble.img` (873 МБ) з увімкненим SSH-сервером та користувачем `user` (пароль: `1488`).

---

## 2. Локації збережених артефактів (нічого не втрачено)

| Категорія | Шлях до підпапки | Опис вмісту |
| :--- | :--- | :--- |
| **Фінальні образи** | [`saved_builds/pmos_bringup_20261011/`](file:///run/host/home/astellias/Projects/Pixel4a5G/saved_builds/pmos_bringup_20261011/) | `boot.img` (13M), `vendor_boot.img` (11M), `google-bramble.img` (873M), `initramfs` (9.4M), `vmlinux` (13M) |
| **Пакети APK** | [`packages/`](file:///run/host/home/astellias/Projects/Pixel4a5G/packages/) | `linux-google-bramble-4.19.325-r0.apk` (11M), `device-google-bramble-1-r2.apk` (143K), `APKINDEX.tar.gz` |
| **Страховий бекап** | [`backup/`](file:///run/host/home/astellias/Projects/Pixel4a5G/backup/) | Робочі образи LineageOS: `stock_boot_a.img` (96M), `stock_vendor_boot_a.img` (96M), `stock_dtbo_a.img` (16M) |
| **Документація** | [`PORTING_GUIDE.md`](file:///run/host/home/astellias/Projects/Pixel4a5G/PORTING_GUIDE.md) | Повний інженерний лог (розділи 1–12) з таблицями всіх 10 усунутих блокерів |
| **Скрипт запуску** | [`boot_pmos_ram.sh`](file:///run/host/home/astellias/Projects/Pixel4a5G/boot_pmos_ram.sh) | Однокліковий скрипт безпечного Fastboot Staging RAM Boot |

---

## 3. Як виконати завантаження та перевірку (Phase I Test)

Оскільки телефон підключено по USB, запуск виконується без жодної прошивки флеш-пам'яті:
```bash
/run/host/home/astellias/Projects/Pixel4a5G/boot_pmos_ram.sh
```

### Що відбувається під капотом:
1. `fastboot stage vendor_boot.img` — завантажує DTB Lito-v2 та ramdisk postmarketOS у буфер оперативної пам'яті завантажувача.
2. `fastboot boot boot.img` — передає ядро в RAM та ініціює завантаження.
3. Флеш-пам'ять смартфона залишається **100% незайманою**. Звичайне перезавантаження телефона кнопкою живлення повертає смартфон назад у LineageOS 23.2.
