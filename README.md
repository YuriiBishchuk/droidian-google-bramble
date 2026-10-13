# Droidian GNU/Linux for Google Pixel 4a (5G) (`bramble`)

[![Platform](https://img.shields.io/badge/Platform-Qualcomm%20SM7250%20(Snapdragon%20765G)-blue.svg)](#hardware-specifications)
[![GPU](https://img.shields.io/badge/GPU-Adreno%20620%20(Mesa%20Turnip%20Vulkan%201.3)-green.svg)](#graphics--gpu-hardware-acceleration)
[![Kernel](https://img.shields.io/badge/Kernel-4.19.269%20(LineageOS%2020%20%2F%20Android%2013)-orange.svg)](#kernel--system-architecture)
[![Compositor](https://img.shields.io/badge/Compositor-Phoc%20%2B%20Phosh%20(wlroots%20Vulkan)-purple.svg)](#desktop-environment)

A native GNU/Linux port of **Droidian** for the **Google Pixel 4a (5G)** (codename `bramble`), featuring native GPU hardware acceleration over Qualcomm KGSL using Mesa Turnip Vulkan 1.3.

---

## 📱 Hardware Specifications

| Component | Specification |
|---|---|
| **SoC** | Qualcomm Snapdragon 765G (`SM7250`) |
| **CPU** | Octa-core (1x2.4 GHz Kryo 475 Prime, 1x2.2 GHz Kryo 475 Gold, 6x1.8 GHz Kryo 475 Silver) |
| **GPU** | Adreno 620 |
| **Display** | 6.24" OLED, 1080x2340 @ 61.66 Hz, Command Mode DSI |
| **Touchscreen** | FocalTech Touch (`/dev/input/event2`) |
| **Base Kernel** | Downstream 4.19.269 LineageOS 20 (Android 13 BSP) |

---

## ⚡ Current Status & Working Features

- [x] **Native GPU Hardware Acceleration**: Turnip Vulkan 1.3 running directly over `/dev/kgsl-3d0`.
- [x] **Compositor**: `phoc` (wlroots 0.17+) running natively on `WLR_RENDERER=vulkan` at 60 FPS with low CPU load (~1–4%).
- [x] **Mobile Shell**: `phosh` (GTK4/libadwaita) fully responsive with scaling factor 2.75.
- [x] **Touchscreen**: Touch and multi-touch gestures mapped via `udev` (`/dev/input/event2`).
- [x] **Display & Backlight**: DRM KMS (`/dev/dri/card0`) DSI-1 command-mode refresh with sysfs backlight control.
- [x] **USB Networking & ADB**: SSH (`root:127.0.0.1:2222`) and ADB access in recovery and live mode.
- [x] **Fastboot Flashing**: Automated scripts for partitioning, boot image packaging, and system flashing.
- [ ] **Cellular / Calls / SMS**: Ongoing integration with oFono / ModemManager.
- [ ] **Audio**: Pulseaudio ALSA / TinyALSA UCM mapping.
- [ ] **Sensors & Auto-rotate**: IIO sensor proxy.

---

## 🛠️ Architecture: The Vulkan Bringup

Running modern Wayland compositors on downstream Android kernels (`4.19`) usually forces developers into either broken software rasterization (`pixman` @ 10-15 FPS) or broken Libhybris GLES. 

This port solves hardware acceleration **natively** by leveraging Mesa Turnip Vulkan on Qualcomm's proprietary KGSL kernel driver (`/dev/kgsl-3d0`):

```
+-------------------------------------------------------------+
|                 Phosh Shell & Mobile Apps                   |
+-------------------------------------------------------------+
                              | Wayland (dmabuf / wl_shm)
+-------------------------------------------------------------+
|               Phoc Compositor (wlroots Vulkan)              |
+-------------------------------------------------------------+
       |                                              |
       | Vulkan 1.3 (Turnip)                          | DRM KMS Atomic
       v                                              v
+-------------------------------+             +---------------+
| /dev/kgsl-3d0 (Adreno 620 GPU)|             | /dev/dri/card0|
+-------------------------------+             +---------------+
```

### Key Engineering Shims (`libfix_drm_formats.so`)

Because downstream Qualcomm MSM DRM and KGSL do not expose modern Linux DRM node bindings out of the box, we inject an in-memory preload library (`ports/droidian-halium/adaptation-google-bramble/fix_drm_formats.c`):

1. **`VK_EXT_physical_device_drm` Injection**:
   * Intercepts `vkGetPhysicalDeviceProperties2` to report primary DRM node `(226, 0)`, allowing wlroots to bind Turnip Vulkan directly to `/dev/dri/card0`.
2. **`DRM_FORMAT_MOD_INVALID` Fallback**:
   * Intercepts wlroots format modifier search to safely map client-allocated `DRM_FORMAT_MOD_INVALID` buffers to linear modifiers, preventing compositor crashes on app launches.
3. **Command Mode Display Autorefresh**:
   * Automatically asserts `autorefresh=1` and `DPMS=0` on connector 29 (`DSI-1`) so the panel doesn't sleep in command mode.
4. **Touchscreen Udev Binding**:
   * Synthesizes `ID_INPUT_TOUCHSCREEN=1`, `WL_OUTPUT=DSI-1`, and `seat0` properties for `event2`.

---

## 🚀 Installation & Flashing Guide

### Prerequisites
- Google Pixel 4a (5G) (`bramble`) with **unlocked bootloader**.
- Fastboot and Android platform tools installed.
- Baseline Android 13 firmware (TQ3A.230805.001).

### 1. Build the Boot Image
```bash
cd ports/droidian-halium/boot
./build_boot.sh
```

### 2. Flash to Device
Ensure the device is connected in Fastboot mode:
```bash
fastboot flash boot_a output/boot.img
fastboot flash boot_b output/boot.img
fastboot reboot
```

### 3. Deploy Live Environment (over ADB / Recovery)
```bash
./ports/droidian-halium/start_droidian_live.sh
```

---

## 🧪 Application Testing Status (2026-10-13)

| Application | Status | Notes |
|---|---|---|
| **phosh-mobile-settings** | ✅ Works | Mobile settings UI functional |
| **gnome-calculator** | ✅ Works | Network warnings only (offline) |
| **firefox (XWayland)** | ✅ Works | Stable via XWayland with `GDK_BACKEND=x11`, `MOZ_ENABLE_WAYLAND=0`, disabled WebRender/GPU process. Launcher script: `ports/droidian-halium/firefox_xwayland.sh` |
| **firefox (Wayland)** | ⚠️ Partial | Runs ~90s with `MOZ_DISABLE_GPU=1 MOZ_DISABLE_GPU_PROCESS=1 MOZ_WEBRENDER=0`, then exits cleanly. Glycin crash with GPU enabled. |
| **gnome-control-center** | ❌ Unsupported | "Only supported under GNOME and Unity" |
| **eglgears_wayland** | ⚠️ Partial | Missing `libadreno_app_profiles.so` from vendor |
| **xeglgears (XWayland)** | ✅ Works | OpenGL ES gears demo stable on XWayland |

**Firefox Solutions:**
- **XWayland (recommended):** `./ports/droidian-halium/firefox_xwayland.sh` — stable for hours
- **Wayland native:** Requires `MOZ_DISABLE_GPU=1 MOZ_DISABLE_GPU_PROCESS=1 MOZ_WEBRENDER=0 MOZ_FORCE_DISABLE_E10S=1` — limited runtime

---

## 📂 Repository Structure

- `ports/droidian-halium/` - Primary Droidian / Halium 11 port:
  - `adaptation-google-bramble/` - Device adaptation package, udev rules, environment configs, and preload shims.
  - `boot/` - Halium 11 initramfs scripts, boot image packer, and kernel dtb handling.
  - `flash_stock_a13_base.sh` - Automated baseline flashing.
  - `start_droidian_live.sh` - Live container orchestration and chroot launcher.
  - `firefox_xwayland.sh` - Firefox launcher via XWayland (stable).
- `ports/pmos-downstream/` - Alternative postmarketOS downstream port files.

---

## 🔗 GitHub Repository

**Public repo:** https://github.com/YuriiBishchuk/droidian-google-bramble

---

## 📄 License & Credits

- Maintained by [Yurii Bishchuk](https://github.com/YuriiBishchuk).
- Built with love for the [Droidian](https://droidian.org) and [Halium](https://halium.org) communities.
- Distributed under the [MIT License](LICENSE).
