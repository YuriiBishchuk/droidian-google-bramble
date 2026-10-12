### 🎯 Успіх! Компіляцію ядра повністю завершено без зависань

Усі захисні обмеження спрацювали ідеально: система жодного разу не зависла, вільної пам'яті залишалося стабільно від 4 до 10 ГБ, а робочий стіл залишався на 100% плавним.

---

### 1. Знайдена першопричина попереднього зависання (Root Cause)
1. **Full LTO (`CONFIG_LTO_CLANG=y` без ThinLTO):**  
   У стоковому ядрі Pixel 4a 5G увімкнено монолітне компонування. Лінкер завантажує IR-код усіх 2000+ файлів ядра в один спільний граф.
2. **Переповнення пам'яті:**  
   Без обмежень на 12 потоках процесор `ld.lld` вимагав **понад 25 ГБ RAM**. Це миттєво з'їло всі 16 ГБ RAM та 16 ГБ Swap, заблокувавши I/O ядра та викликавши апаратний «мертвий» freeze хост-системи.
3. **Як ми це вирішили:**  
   - Планувальник: `nice -n 19` (найнижчий пріоритет процесора для збірки, робочий стіл має абсолютний пріоритет).
   - Дисковий I/O: `ionice -c 3` (idle пріоритет, ніяких затримок диску).
   - Потоки Make: `-j4` (8 ядер вільні для системи).
   - Потоки LLD: `KBUILD_LDFLAGS="--threads=4"` (споживання пам'яті обмежено безпечним діапазоном).

---

### 2. Вирішено фінальний блокер стиснення (`lz4`)
- Під час створення фінального образу сталася помилка `lz4: not found (Exit 127)`.
- **Аналіз стокового образу:** Розпакувавши [stock_boot_a.img](file:///run/host/home/astellias/Projects/Pixel4a5G/backup/stock_boot_a.img), ми виявили, що завантажувач Pixel 4a 5G (Header v3) очікує ядро **суворо у форматі LZ4** (`LZ4 compressed data (v1.4+)`, розмір ~13.5 МБ).
- **Виправлення:** Встановили `lz4` у середовище Alpine, додали його в `makedepends` та прописали `export KERNEL_IMAGE_NAME="Image.lz4"` у `package()` файлу [APKBUILD](file:///home/astellias/DistroBox/FedoraDevBox/.local/var/pmbootstrap/cache_git/pmaports/device/downstream/linux-google-bramble/APKBUILD).

---

### 3. Отримані артефакти ядра:
У каталозі `out/arch/arm64/boot/` згенеровано повний комплект:
* **`vmlinux` (234 МБ)** — бінарник ядра з символами налагодження.
* **`Image` (26 МБ)** — чистий монолітний AArch64 бінарник.
* **`Image.lz4` (13 МБ)** — стиснуте ядро під завантажувач Pixel.
* **`Image.lz4-dtb` (14 МБ)** — ядро з підшитими деревами пристроїв DTB Bramble.
* **`dtbo_bramble.img` та `dtbo.img` (6.8 МБ)** — оверлеї заліза Pixel 4a 5G.
* **329 модулів `.ko`** (включаючи `msm_drm.ko`, `qcacld-3.0 wlan.ko`, USB DWC3, батарею, сенсори).

Усі висновки та таблицю блокерів оновлено у [PORTING_GUIDE.md](file:///run/host/home/astellias/Projects/Pixel4a5G/PORTING_GUIDE.md#L214).

---

### Наступний крок (Фаза I за промтом):
Зібрати офіційний пакет `linux-google-bramble` через `pmbootstrap` та підготувати завантажувальний образ для тесту через `fastboot boot`:
```bash
pmbootstrap build linux-google-bramble
pmbootstrap install --no-fde --ui=none
pmbootstrap flasher boot
```

Чи запускаємо пакетну збірку `pmbootstrap build` зараз?