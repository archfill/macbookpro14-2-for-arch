#!/usr/bin/env bash
set -euo pipefail

echo "=== Base Packages Setup (battery / thermal / fan) ==="

# 1. General packages (official repos)
echo "[1/2] Installing packages..."
sudo pacman -S --noconfirm tlp powertop brightnessctl thermald

# mbpfan is in AUR
if ! command -v yay &>/dev/null; then
    echo "ERROR: yay is required for mbpfan. Install it first: https://github.com/Jguer/yay"
    exit 1
fi
yay -S --noconfirm mbpfan

# 2. Enable services
echo "[2/2] Enabling services..."
sudo systemctl enable tlp
sudo systemctl enable thermald
sudo systemctl enable mbpfan
sudo systemctl start mbpfan

echo ""
echo "Done."
