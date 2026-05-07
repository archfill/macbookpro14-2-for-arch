#!/usr/bin/env bash
set -euo pipefail

echo "=== Base Packages Setup (battery / thermal / fan) ==="

confirm() {
    local msg="$1"
    read -rp "${msg} [y/N] " ans
    [[ "${ans,,}" == "y" ]]
}

# 1. Required packages (official repos)
echo "[1/4] Installing required packages..."
sudo pacman -S --noconfirm tlp powertop brightnessctl

# 2. Optional: mbpfan (AUR)
if confirm "[2/4] Install mbpfan-git (fan control for MacBook)? Requires yay."; then
    if ! command -v yay &>/dev/null; then
        echo "ERROR: yay is required for mbpfan. Install it first: https://github.com/Jguer/yay"
        exit 1
    fi
    yay -S --noconfirm mbpfan-git
    INSTALL_MBPFAN=true
else
    INSTALL_MBPFAN=false
fi

# 3/4. TLP config: prevent Intel GPU frequency drop on Hyprland (stuttering)
TLP_CONF="/etc/tlp.conf"
if [[ -f "$TLP_CONF" ]]; then
    sudo sed -i 's/^#\?INTEL_GPU_MIN_FREQ_ON_AC=.*/INTEL_GPU_MIN_FREQ_ON_AC=500/' "$TLP_CONF"
    sudo sed -i 's/^#\?INTEL_GPU_MIN_FREQ_ON_BAT=.*/INTEL_GPU_MIN_FREQ_ON_BAT=500/' "$TLP_CONF"
fi

# 4. Enable services
echo "[4/4] Enabling services..."
sudo systemctl enable tlp
if [[ "$INSTALL_MBPFAN" == "true" ]]; then
    sudo systemctl enable mbpfan
    sudo systemctl start mbpfan
fi

echo ""
echo "Done."
