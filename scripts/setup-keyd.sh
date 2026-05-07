#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Keyboard Customization Setup (keyd) ==="

# 1. Install keyd from official repo (extra)
echo "[1/3] Installing keyd..."
sudo pacman -S --noconfirm keyd

# 2. Disable interception-tools if present, install config, enable service
echo "[2/3] Configuring keyd service..."
sudo systemctl stop udevmon 2>/dev/null || true
sudo systemctl disable udevmon 2>/dev/null || true
sudo cp "${REPO_DIR}/driver/keyd/macbook-internal.conf" /etc/keyd/macbook-internal.conf
sudo systemctl enable --now keyd
sudo systemctl restart keyd

# 3. fcitx5: Henkan = activate (かな), Muhenkan = deactivate (英数)
echo "[3/3] Configuring fcitx5 hotkeys..."
FCITX5_CONFIG="${HOME}/.config/fcitx5/config"
if [ -f "$FCITX5_CONFIG" ]; then
    sed -i 's/^0=Alt+Alt_R$/0=Henkan/' "$FCITX5_CONFIG"
    sed -i 's/^0=Alt+Alt_L$/0=Muhenkan/' "$FCITX5_CONFIG"
    fcitx5 -r --enable all 2>/dev/null &
    echo "  fcitx5 config updated."
else
    echo "  WARNING: fcitx5 config not found. Run setup-fcitx5.sh first."
fi

echo ""
echo "=== Done ==="
echo "  CapsLock tap=Escape / hold=Ctrl"
echo "  Left Command tap=英数 (Muhenkan) / hold=Super"
echo "  Right Command tap=かな (Henkan) / hold=Super"
echo ""
echo "Reboot recommended to fully apply keyd."
