# 🚀 Звіт: Повний запуск мобільного середовища Phosh на Pixel 4a (5G) (bramble)

**Дата:** 12 жовтня 2026  
**Ціль:** Заміна робочого столу Weston на повноцінне мобільне оточення (Phosh / GNOME Mobile) та налагодження роботи сенсорного екрана (touchscreen).  
**Статус:** 🟢 **УСПІШНО ВИКОНАНО НА 100%**

---

## 1. Короткий огляд досягнутого

1. **Мобільна оболонка Phosh запущена та активна на живому OLED-екрані (1080x2340):**
   - Композитор: `phoc` (Phone Compositor на базі wlroots) з коефіцієнтом масштабування `scale = 2` (логічна роздільна здатність **540x1170**).
   - Оболонка: `phosh` (Phone Shell) з панеллю додатків, пошуком, швидкими перемикачами та статусбаром.
   - Екранна клавіатура: `squeekboard` (темна сенсорна QWERTY-клавіатура Wayland).
   - Мобільний термінал: `gnome-console` (`kgx`).

2. **Сенсорний екран (FocalTech `fts`, `/dev/input/event2`) повністю налагоджено:**
   - Виправлено хибну класифікацію `libinput` (пристрій раніше сприймався як клавіатура через наявність жестів пробудження `KEY_W`, `KEY_E`).
   - Через `libfix_drm_formats.so` додано атрибути `ID_INPUT_TOUCHSCREEN=1`, `ID_INPUT=1`, `WL_OUTPUT=DSI-1`.
   - `libinput` розпізнає тачскрін як `cap:kt ntouches 10 calib`.
   - Фізичні та синтетичні дотики успішно відкривають додатки, викликають меню та друкують на віртуальній клавіатурі.

3. **Подолано обмеження Android-ядра 4.19:**
   - **`faccessat` flags bug:** Сучасний GLib викликав `faccessat(AT_FDCWD, path, F_OK, AT_SYMLINK_NOFOLLOW)`, на що ядро 4.19 повертало `EINVAL`, ламаючи виявлення всіх `.desktop`, `.xml` та іконок у системі. Реалізовано перехоплення та трансляцію в `fstatat()`.
   - **`/dev/shm` tmpfs:** Змонтовано POSIX спільну пам'ять, необхідну для Wayland keymap buffers.
   - **Stack canary guard:** Виправлено перевірку довжини подій сторінкових перемикань у `read()` інтерцепторі для захисту GCC canary.

---

## 2. Графічні скріншоти живої системи

- [`phosh_bramble_screen.png`](file:///run/host/home/astellias/Projects/Pixel4a5G/phosh_bramble_screen.png): Домашній екран Phosh з пошуком, іконками додатків та шпалерами Adwaita на дисплеї Pixel 4a (5G).
- [`phosh_console_tap.png`](file:///run/host/home/astellias/Projects/Pixel4a5G/phosh_console_tap.png): Розгорнутий додаток GNOME Settings та активна темна сенсорна клавіатура Squeekboard.
- [`phosh_after_tap.png`](file:///run/host/home/astellias/Projects/Pixel4a5G/phosh_after_tap.png): Реакція на сенсорний дотик по кнопці "Show All Apps".

---

## 3. Корисні скрипти на хості

- `./launch_pmos_gui.sh` — запуск Phosh на телефоні в один клік з комп'ютера.
- `./ssh_pmos.sh` — миттєвий доступ до консолі pmOS по SSH без пароля за 0.05с.
- `./run_app.sh <назва>` — запуск додатків у сесії Wayland.
