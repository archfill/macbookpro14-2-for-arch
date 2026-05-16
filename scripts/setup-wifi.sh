#!/usr/bin/env bash
set -euo pipefail

NVRAM_URL="https://raw.githubusercontent.com/nwallace83/macbook_linux_scripts/main/brcmfmac43602-pcie.txt"
FIRMWARE_DIR="/lib/firmware/brcm"

echo "=== Wi-Fi Setup (Broadcom BCM43602) ==="

# Detect brcmfmac interface
IFACE=""
for iface in /sys/class/net/*/; do
    iface_name=$(basename "$iface")
    driver_link="${iface}/device/driver"
    if [[ -L "$driver_link" ]] && readlink "$driver_link" | grep -q "brcmfmac"; then
        IFACE="$iface_name"
        break
    fi
done
if [[ -z "$IFACE" ]]; then
    echo "ERROR: brcmfmac interface not found"
    exit 1
fi
echo "  Detected interface: ${IFACE}"

# 1. Install tools
echo "[1/4] Installing tools..."
sudo pacman -S --noconfirm wget pciutils
sudo update-pciids -q 2>/dev/null || true

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

# 3. Disable FWSUP (firmware supplicant offload) - required for WPA2 authentication
# brcmfmac offloads EAPOL to firmware by default, but BCM43602's old firmware
# (2015, v7.35.177) cannot complete the 4-way handshake, causing auth timeout.
# feature_disable=0x2000 disables BRCMF_FEAT_FWSUP (bit 13), forcing wpa_supplicant
# to handle EAPOL directly on the host side.
echo "[3/4] Disabling firmware supplicant offload (FWSUP)..."
echo 'options brcmfmac roamoff=1 feature_disable=0x2000' \
    | sudo tee /etc/modprobe.d/brcmfmac.conf > /dev/null
echo "  Written to /etc/modprobe.d/brcmfmac.conf"

# 4. TX power limit service (using iw, not iwconfig)
echo "[4/4] Setting up TX power limit service..."
sudo tee /etc/systemd/system/set-wifi-power.service > /dev/null << EOF
[Unit]
Description=Set WiFi TX Power for Broadcom BCM43602
After=network.target

[Service]
ExecStart=/usr/bin/iw dev ${IFACE} set txpower fixed 1000
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable set-wifi-power.service

echo ""
echo "Done. Reboot to apply all changes."
echo ""
echo "After reboot, verify with:"
echo "  ip link show ${IFACE}              # interface is UP"
echo "  iw phy phy0 info | grep 'Band 2'  # 5GHz support"
echo "  sudo dmesg | grep -i brcm         # no driver errors"
echo "  nmcli device connect ${IFACE}     # connect to AP"
