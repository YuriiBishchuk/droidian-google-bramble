# 📖 Заготовка для офіційної Wiki postmarketOS

Цей каталог містить готову заготовку сторінки для офіційної [postmarketOS Wiki: Google Pixel 4a (5G) (google-bramble)](https://wiki.postmarketos.org/wiki/Google_Pixel_4a_(5G)_(google-bramble)).

Наразі у вікі пристрій зазначений як **«Not booting»** через відсутність публічної документації про подолання багів DRM та відключення TrustZone watchdog. Ця сторінка повністю оновлює статус пристрою до **робочого мобільного оточення з графікою та тачскріном**.

---

## Файли в цьому каталозі:

1. **[`Google_Pixel_4a_(5G)_(google-bramble).wiki`](file:///run/host/home/astellias/Projects/Pixel4a5G/wiki/Google_Pixel_4a_%285G%29_%28google-bramble%29.wiki)**:
   Повний синтаксис MediaWiki з шаблоном `{{Infobox device}}`, таблицею працездатності, інструкціями з інсталяції через `pmbootstrap`, описом унікальних апаратних нюансів та посиланнями на скріншоти. Готовий до копіювання та вставки у вікі.

2. **Скріншоти для завантаження у Wiki:**
   - [`phosh_bramble_screen.png`](file:///run/host/home/astellias/Projects/Pixel4a5G/phosh_bramble_screen.png) -> завантажується як `Phosh_bramble_homescreen.png`
   - [`phosh_console_tap.png`](file:///run/host/home/astellias/Projects/Pixel4a5G/phosh_console_tap.png) -> завантажується як `Phosh_bramble_settings_keyboard.png`

---

## 🟢 Оновлена таблиця можливостей (Feature Matrix):

| Компонент | Статус | Примітки |
|---|---|---|
| **Завантаження (Booting)** | ✅ Працює | `pmbootstrap flasher boot` або через `fastboot boot` з Header v3 |
| **Екран (Display)** | ✅ Працює | 1080x2340 @ 60Hz AMOLED (`DSI-1`), MSM DRM + Pixman |
| **Тачскрін (Touchscreen)** | ✅ Працює | FocalTech FT5446 (`fts`, `/dev/input/event2`), 10-точковий мультитач |
| **Мобільний UI** | ✅ Працює | **Phosh** (Phone Shell, scale 2.75, ~392x850) та **Weston** |
| **Екранна клавіатура** | ✅ Працює | **Squeekboard** Wayland Virtual Keyboard |
| **Wi-Fi** | ✅ Працює | 2.4/5 GHz сканування, підключення WPA2/WPA3, DHCP та інтернет через NetworkManager |
| **Мережа USB / SSH** | ✅ Працює | NCM Gadget на 172.16.42.1 (SSH без пароля) |
| **Фізичні клавіші** | ✅ Працює | Живлення (`qpnp_pon`), гучність (`gpio-keys`) |
| **Акумулятор / Живлення** | ✅ Працює | Індикація заряду в статус-барі через `/sys/class/power_supply` |
| **Звук / Дзвінки / Камера** | ⏳ В процесі | Потребує інтеграції з пропрієтарними HAL / ALSA UCM |
