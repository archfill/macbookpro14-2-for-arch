#!/usr/bin/env bash
set -euo pipefail

IFACE="wlp2s0"
NVRAM_URL="https://raw.githubusercontent.com/nwallace83/macbook_linux_scripts/main/brcmfmac43602-pcie.txt"
FIRMWARE_DIR="/lib/firmware/brcm"

echo "=== Wi-Fi Setup (Broadcom BCM43602) ==="

# 1. Install driver and tools
echo "[1/4] Installing driver and tools..."
sudo pacman -S --noconfirm wget pciutils
sudo update-pciids -q 2>/dev/null || true

# b43-firmware is in AUR
if ! command -v yay &>/dev/null; then
    echo "ERROR: yay is required for b43-firmware. Install it first: https://github.com/Jguer/yay"
    exit 1
fi
yay -S --noconfirm b43-firmware

# 2. NVRAM file for 5GHz support
echo "[2/4] Installing NVRAM file for 5GHz support..."
TMP_NVRAM="$(mktemp)"
wget -q -O "$TMP_NVRAM" "$NVRAM_URL"

# Update macaddr to match device
if ip link show "$IFACE" &>/dev/null; then
    MACADDR="$(ip link show "$IFACE" | awk '/ether/{print $2}')"
    sed -i "s/macaddr=.*/macaddr=${MACADDR}/" "$TMP_NVRAM"
    echo "  macaddr set to ${MACADDR}"
else
    echo "  Warning: ${IFACE} not found, skipping macaddr update"
fi

sudo cp "$TMP_NVRAM" "${FIRMWARE_DIR}/brcmfmac43602-pcie.txt"
sudo cp "${FIRMWARE_DIR}/brcmfmac43602-pcie.txt" \
    "${FIRMWARE_DIR}/brcmfmac43602-pcie.Apple Inc.-MacBookPro14,2.txt"
rm -f "$TMP_NVRAM"

# 3. TX power limit service
echo "[3/4] Setting up TX power limit service..."
sudo tee /etc/systemd/system/set-wifi-power.service > /dev/null << 'EOF'
[Unit]
Description=Set WiFi TX Power for Broadcom BCM43602
After=network.target

[Service]
ExecStart=/sbin/iwconfig wlp2s0 txpower 10dBm
Type=oneshot

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable set-wifi-power.service

echo "[4/4] Done."
echo ""
echo "Reboot to apply all changes."
echo "  After reboot, verify 5GHz: iw phy phy0 info | grep 'Band 2'"
