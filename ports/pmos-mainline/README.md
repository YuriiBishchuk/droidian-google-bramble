# 🔮 postmarketOS Mainline (Linux 6.x) for Google Pixel 4a (5G) (bramble)

## 1. Концепція
Мета проєкту — довгостроковий FOSS-порт на чистому ядрі Linux (6.12+ LTS / linux-next) без використання пропрієтарних Android-компонентів, з відкритим графічним стеком **Freedreno / Turnip**.

---

## 2. Апаратна основа SM7250 у Mainline
- Базовий SoC DTSI вже присутній у мейнлайн ядрі: [`arch/arm64/boot/dts/qcom/sm7250.dtsi`](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/sm7250.dtsi).
- Існуючі референсні пристрої на SM7250/SM7225 у Mainline:
  - `fairphone-4` (SM7225 / SM750G)
  - `xiaomi-gauguin` (Redmi Note 9 Pro 5G)

---

## 3. Напрацювання, перенесені з Downstream-порту
1. **Завантажувач Boot Header v3:** Ті самі параметри сторінок 4096, зміщення та робота з `vendor_boot`.
2. **Апаратна карта з `lito-v2`:**
   - DSI піни, таймінги та послідовність увімкнення OLED-панелі Samsung.
   - I2C шина, переривання (IRQ) та адреса контролера тачскріна FocalTech FT5446.
   - Розподіл регуляторів живлення PMIC PM7250 / PM7250B / SMB1398.
3. **Середовище та налаштування UI:**
   - Конфігурація масштабування `scale = 2.75` для Phosh.
   - Віртуальна клавіатура Squeekboard.

---

## 4. Дорожня карта (Roadmap)
- [ ] Створення `sm7250-google-bramble.dts` на базі `sm7250.dtsi`.
- [ ] Написання/портування DRM DSI драйвера панелі дисплея.
- [ ] Перевірка раннього UART / simplefb виводу.
- [ ] Увімкнення сенсора тачскріна через стандартний драйвер `edt-ft5x06`.
- [ ] Підключення Freedreno GPU для апаратного рендерингу.
