# 🤖 Droidian (Halium 11) Porting Architecture for Google Pixel 4a (5G) (bramble)

## 1. Концепція та цілі
Мета проєкту — перетворити Google Pixel 4a (5G) на щоденний швидкий мобільний Linux-смартфон завдяки використанню **Droidian** (Debian GNU/Linux для мобільних) у тандемі з **Halium 11 GSI** через контейнер вендора та бібліотеку `libhybris`.

### Що це вирішує:
1. **Апаратне прискорення GPU Adreno 620:**
   - Wayland-композитор (Phosh / Phoc) рендериться безпосередньо через пропрієтарний драйвер вендора `libGLESv2_adreno.so` через `hybris-egl`.
   - **Результат:** 60 FPS анімації, плавний скролінг, жодного перевантаження центрального процесора.
2. **Датчики (Sensors):**
   - Робота через `sensorfw` та плагін `hybris-sensor`.
   - Автоповорот екрана, регулювання яскравості, датчик наближення під час дзвінка.
3. **Аудіо:**
   - Використання `pulseaudio-modules-droid` або `pipewire-module-spa-droid` для взаємодії з рідним Android Audio HAL (`audio.primary.lito.so`).
4. **Мобільний зв'язок (Модем / RIL):**
   - Дзвінки, SMS та 4G мобільний інтернет через `ofono` + `ofono-binder-plugin` через рідний сервіс `rild`.

---

## 2. Структура адаптації Droidian
```
ports/droidian-halium/
├── boot/                        # Генератор boot.img та vendor_boot.img (Halium initramfs)
│   ├── build_boot.sh            # Скрипт збірки образів завантажувача
│   └── cmdline.txt              # Аргументи ядра для Droidian
├── device-adaptation/           # Пакет адаптації пристрою (Debian package)
│   ├── debian/                  # Метадані та правила збірки dpkg
│   └── sparse/                  # Оверлей файлової системи для кореневого розділу
│       ├── etc/
│       │   ├── droidian/        # Конфігурація Droidian (модель, архітектура, вендор)
│       │   ├── pulse/           # Конфігурація аудіо для droid-сервера
│       │   └── udev/rules.d/    # Правила udev для пристроїв Android
│       └── usr/lib/
│           └── droidian-device/ # Скрипти запуску та адаптації
└── README.md
```

---

## 3. Компоненти системи
1. **Ядро та дерево пристроїв:**
   - Наше перевірене ядро `android_kernel_google_redbull` (LineageOS 23.2, Linux 4.19.325).
   - Готовий конфіг `config-google-bramble.aarch64` з увімкненими опціями для Halium (`CONFIG_ANDROID_BINDER_IPC=y`, cgroups, namespace).
2. **Образи для прошивки:**
   - **Boot / Vendor Boot:** Header v3 з `halium-boot` ramdisk.
   - **System:** `droidian-rootfs-api30-arm64.tar.xz` (Debian rootfs).
   - **Vendor:** Рідний розділ вендора Pixel 4a (5G) (Android 11/12/13/14).

---

## 4. Покроковий план реалізації
- [ ] **Крок 1:** Створення `droidian-device-google-bramble` шаблону через `droidian-build-tools`.
- [ ] **Крок 2:** Адаптація `halium-boot` ramdisk під Boot Header v3 (інтеграція з нашим скриптом `mkbootimg`).
- [ ] **Крок 3:** Підготовка конфігурації `hybris-egl` та перевірка виводу Phosh через апаратний GPU.
- [ ] **Крок 4:** Інтеграція сенсорів через `sensorfw` та аудіо через PipeWire/PulseAudio droid-модулі.
