#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# [1/3] Install dependencies
echo "[touchpad] [1/3] Install dependencies"
sudo pacman -S --noconfirm libinput

# [2/3] Install quirks, reload udev, and verify
echo "[touchpad] [2/3] Install quirks / reload udev / verify"

sudo mkdir -p /etc/libinput
sudo cp "${REPO_DIR}/driver/libinput/local-overrides.quirks" /etc/libinput/local-overrides.quirks

sudo udevadm trigger /dev/input/event* 2>/dev/null || true

# Find event device for Apple SPI Keyboard (applespi/input0)
KB_EVENT=""
while IFS= read -r line; do
    if echo "$line" | grep -q "applespi/input0"; then
        in_block=1
    fi
    if [[ "${in_block:-0}" == "1" ]] && echo "$line" | grep -q "Handlers="; then
        KB_EVENT=$(echo "$line" | grep -oP 'event\d+')
        break
    fi
done < /proc/bus/input/devices

if [[ -z "$KB_EVENT" ]]; then
    echo "  WARNING: Apple SPI Keyboard not found, skipping verification"
elif libinput quirks list "/dev/input/${KB_EVENT}" 2>/dev/null | grep -q "AttrKeyboardIntegration=internal"; then
    echo "  OK: AttrKeyboardIntegration=internal applied to /dev/input/${KB_EVENT}"
else
    echo "  WARNING: quirk not confirmed on /dev/input/${KB_EVENT}. Reboot to apply."
fi

# [3/3] Done
echo "[touchpad] [3/3] Done. Reboot to fully apply DWT fix."
