#!/usr/bin/env bash
set -euo pipefail

DRIVER_DIR="$(cd "$(dirname "$0")/../driver/touchbar" && pwd)"
UDEV_DIR="$(cd "$(dirname "$0")/../driver/udev" && pwd)"
MODPROBE_DIR="$(cd "$(dirname "$0")/../driver/modprobe.d" && pwd)"
DKMS_NAME="appleibridge"
DKMS_VER="0.1"
DEST="/usr/src/${DKMS_NAME}-${DKMS_VER}"

echo "=== Touch Bar Driver Setup (DKMS) ==="

echo "[1/3] Installing dependencies..."
KERNEL_HEADERS="linux-headers"
if uname -r | grep -q "\-lts$"; then
    KERNEL_HEADERS="linux-lts-headers"
fi
sudo pacman -S --noconfirm dkms base-devel "$KERNEL_HEADERS"

echo "[2/3] Building and installing DKMS module..."
sudo dkms remove "${DKMS_NAME}/${DKMS_VER}" --all 2>/dev/null || true
sudo rm -rf "$DEST"
sudo cp -r "$DRIVER_DIR" "$DEST"
sudo dkms add "${DKMS_NAME}/${DKMS_VER}"
sudo dkms build "${DKMS_NAME}/${DKMS_VER}"
sudo dkms install "${DKMS_NAME}/${DKMS_VER}"

sudo cp "$UDEV_DIR/91-apple-touchbar.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules

# fnmode=2: default fn keys, fn pressed = special keys
sudo cp "$MODPROBE_DIR/apple-touchbar.conf" /etc/modprobe.d/

echo "[3/3] Done. Reboot to activate Touch Bar."
echo "  Manual test: sudo modprobe apple-ibridge && sudo modprobe apple-ib-tb"
