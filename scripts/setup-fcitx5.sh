#!/usr/bin/env bash
set -euo pipefail

echo "=== Japanese Input Setup (fcitx5 + Mozc) ==="

echo "Installing packages..."
sudo pacman -S --noconfirm fcitx5 fcitx5-mozc fcitx5-qt fcitx5-gtk

echo ""
echo "Done."
echo "  Hyprland config (env vars + exec-once) should be managed via dotfiles."
