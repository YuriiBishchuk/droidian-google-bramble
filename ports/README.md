# 📱 Google Pixel 4a (5G) (google-bramble) - Multi-Port Ecosystem

Цей каталог містить три незалежні гілки/проєкти портирування мобільного Linux на платформу **Google Pixel 4a (5G) (SM7250 / Snapdragon 765G)**:

```
ports/
├── pmos-downstream/     # 🟢 РЕАЛІЗОВАНО: postmarketOS на downstream ядрі LineageOS 4.19
├── droidian-halium/     # 🚀 В ПРОЦЕСІ: Droidian (Debian + Halium 11 GSI + libhybris)
└── pmos-mainline/       # 🔮 МАЙБУТНЄ: postmarketOS на чистому ядрі Linux 6.x (FOSS)
```

---

## 1. `pmos-downstream` (postmarketOS Downstream 4.19)
- **Статус:** 🟢 **Повністю робочий брінг-ап + відкритий upstream MR [!9754](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/merge_requests/9754)**.
- **Ядро:** Android Linux 4.19.325 (LineageOS 23.2).
- **Графіка:** Pixman CPU software rendering (60 FPS, стабільний Phosh).
- **Тачскрін:** 10-точковий ємнісний сенсор FocalTech FT5446.
- **Батарея:** UPower 99% із сенсором зарядки та хуком `statx`.
- **Мережа:** USB NCM Gadget (172.16.42.1) + повноцінний Wi-Fi WPA2/WPA3.
- **Призначення:** Базовий стабільний фундамент, перевірка завантажувача Boot Header v3 та конфігураційного дерева пристроїв.

---

## 2. `droidian-halium` (Droidian / Halium 11)
- **Статус:** 🚀 **Активна розробка**.
- **Архітектура:** Debian Linux rootfs + Halium 11 LXC container (Android vendor) + `libhybris`.
- **Ціль:** 
  - **Апаратне 3D-прискорення Adreno 620** через `hybris-egl` (плавний 60 FPS UI без CPU-лагів).
  - Повна підтримка датчиків (акселерометр, гіроскоп, датчик освітлення та наближення) через `sensorfw`.
  - Аудіо стек через Android Audio HAL (`pulseaudio-modules-droid` / `pipewire-module-spa-droid`).
  - Мобільний зв'язок (дзвінки, SMS, 4G) через `ofono-binder-plugin`.
- **Перевага:** Використовує наш відпрацьований Boot v3 та ядра, даючи повноцінний щоденний смартфон (Daily Driver).

---

## 3. `pmos-mainline` (postmarketOS Mainline 6.x)
- **Статус:** 🔮 **Заплановано**.
- **Архітектура:** Чисте апстрімне ядро Linux 6.12+ на базі `qcom/sm7250.dtsi`.
- **Ціль:** Чистий FOSS без пропрієтарних Android-блобів, відкритий GPU драйвер Freedreno + Turnip.
- **База для старту:** Витягнуті таймінги DSI панелі, адреси I2C та пін-контрол з `lito-v2`.
