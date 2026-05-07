#!/usr/bin/env bash
set -euo pipefail

# snd_hda_macbookpro (davidjo) for MacBook Pro CS8409 internal speaker support
# Repo: https://github.com/davidjo/snd_hda_macbookpro

DKMS_NAME="snd_hda_macbookpro"
DKMS_VER="0.1"
DKMS_SRC="/usr/src/${DKMS_NAME}-${DKMS_VER}"
REPO_URL="https://github.com/davidjo/snd_hda_macbookpro.git"
TMP_DIR="$(mktemp -d)"

echo "=== Audio Setup (CS8409 internal speaker) ==="

# 1. Install dependencies
echo "[1/3] Installing dependencies..."
KERNEL_HEADERS="linux-headers"
if uname -r | grep -q "\-lts$"; then
    KERNEL_HEADERS="linux-lts-headers"
fi
sudo pacman -S --noconfirm git dkms base-devel "$KERNEL_HEADERS"

# 2. Clone repo
echo "[2/3] Cloning ${REPO_URL}..."
git clone "$REPO_URL" "$TMP_DIR/snd_hda_macbookpro"

# 3. Install to DKMS source directory
echo "[3/3] Installing via DKMS..."
sudo dkms remove "${DKMS_NAME}/${DKMS_VER}" --all 2>/dev/null || true
sudo rm -rf "$DKMS_SRC"
sudo cp -r "$TMP_DIR/snd_hda_macbookpro" "$DKMS_SRC"

sudo dkms add -m "$DKMS_NAME" -v "$DKMS_VER"

# Fix BUILT_MODULE_LOCATION: kernel >=6.17 builds to codecs/cirrus/ subdir
sudo sed -i 's|BUILT_MODULE_LOCATION\[0\]="build/hda"|BUILT_MODULE_LOCATION[0]="build/hda/codecs/cirrus"|' "$DKMS_SRC/dkms.conf"

sudo dkms build "${DKMS_NAME}/${DKMS_VER}"
sudo dkms install "${DKMS_NAME}/${DKMS_VER}"

rm -rf "$TMP_DIR"

echo ""
dkms status "$DKMS_NAME"
echo ""
echo "Done. Reboot to activate."
echo "  After reboot, verify: sudo dmesg | grep -i 'patch_cs8409\\|APPLE'"
