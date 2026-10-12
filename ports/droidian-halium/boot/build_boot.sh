#!/bin/bash
# ==============================================================================
# build_boot.sh: Build Droidian / Halium 11 Boot Images for Pixel 4a (5G) (bramble)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAMDISK_DIR="$SCRIPT_DIR/ramdisk"
KERNEL_DIR="$SCRIPT_DIR/kernel"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$OUTPUT_DIR"

if [ ! -d "$RAMDISK_DIR" ] && [ -f "$SCRIPT_DIR/halium_ramdisk_base.tar.gz" ]; then
	echo "==> Extracting Halium base ramdisk..."
	mkdir -p "$RAMDISK_DIR"
	tar -xzf "$SCRIPT_DIR/halium_ramdisk_base.tar.gz" -C "$RAMDISK_DIR"
fi

echo "==> Packing Droidian Halium Ramdisk..."
(
	cd "$RAMDISK_DIR"
	find . | cpio -o -H newc | gzip -9 > "$OUTPUT_DIR/ramdisk.cpio.gz"
)
echo "    Ramdisk packed: $(ls -lh "$OUTPUT_DIR/ramdisk.cpio.gz" | awk '{print $5}')"

echo "==> Preparing empty vendor ramdisk..."
mkdir -p /tmp/empty_vendor_ramdisk
(
	cd /tmp/empty_vendor_ramdisk
	find . | cpio -o -H newc | gzip -9 > "$OUTPUT_DIR/vendor_ramdisk.cpio.gz"
)
rm -rf /tmp/empty_vendor_ramdisk

CMDLINE="console=tty0 printk.devkmsg=on androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 service_locator.enable=1 swiotlb=2048 loop.max_part=16 androidboot.usbcontroller=a600000.dwc3 panic_on_err=1 androidboot.selinux=permissive systemd.unified_cgroup_hierarchy=0 droidian.lvm.prefer"

echo "==> Generating boot.img (Header v3)..."
mkbootimg \
	--header_version 3 \
	--os_version 11.0.0 \
	--os_patch_level 2024-05 \
	--kernel "$KERNEL_DIR/Image.lz4" \
	--ramdisk "$OUTPUT_DIR/ramdisk.cpio.gz" \
	-o "$OUTPUT_DIR/boot.img"

echo "==> Generating vendor_boot.img (Header v3)..."
mkbootimg \
	--header_version 3 \
	--pagesize 4096 \
	--vendor_cmdline "$CMDLINE" \
	--dtb "$KERNEL_DIR/lito-v2.dtb" \
	--vendor_ramdisk "$OUTPUT_DIR/vendor_ramdisk.cpio.gz" \
	--vendor_boot "$OUTPUT_DIR/vendor_boot.img"

echo "=============================================================================="
echo "✅ Droidian Boot Images Successfully Generated!"
echo "   - boot.img:        $OUTPUT_DIR/boot.img ($(ls -lh "$OUTPUT_DIR/boot.img" | awk '{print $5}'))"
echo "   - vendor_boot.img: $OUTPUT_DIR/vendor_boot.img ($(ls -lh "$OUTPUT_DIR/vendor_boot.img" | awk '{print $5}'))"
echo "=============================================================================="
