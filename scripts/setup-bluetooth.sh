#!/usr/bin/env bash
set -euo pipefail

echo "[1/2] Installing Bluetooth packages..."
sudo pacman -S --noconfirm --needed bluez bluez-utils

echo "[2/2] Enabling and starting bluetooth.service..."
sudo systemctl enable --now bluetooth.service

echo "Done. Bluetooth is ready."
echo "Use 'bluetoothctl' to pair devices."
