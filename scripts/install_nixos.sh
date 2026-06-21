#!/usr/bin/env bash

set -e

echo "┌─────────────────────────────────────────────┐"
echo "│          NixOS Configuration Guide          │"
echo "└─────────────────────────────────────────────┘"
echo ""
echo "NixOS управляет пакетами декларативно через configuration.nix или Home Manager."
echo "Поэтому автоматическая системная установка пакетов скриптом невозможна."
echo ""
echo "Шаг 1: Добавьте следующие пакеты в ваш configuration.nix или home.nix:"
echo "------------------------------------------------------------------"
cat << 'EOF'
  environment.systemPackages = with pkgs; [
    # Quickshell & Matugen (доступны в nixpkgs-unstable)
    quickshell
    matugen

    # Системные зависимости
    jq
    bc
    python3
    python3Packages.pillow
    brightnessctl
    libnotify
    psmisc
    procps
    xdg-utils
    grim
    ffmpeg
    wf-recorder
    wl-clipboard
    cliphist
    hyprlock
    curl
    zenity
    hyprpaper
  ];

  # Не забудьте включить службы:
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.power-profiles-daemon.enable = true;
  programs.hyprland.enable = true;
EOF
echo "------------------------------------------------------------------"
echo ""

# Download Material Symbols font if not present
echo "Шаг 2: Шрифты"
mkdir -p "$HOME/.local/share/fonts"
if ! fc-list : family | grep -qi "Material Symbols" 2>/dev/null; then
    read -p "Скачать и установить шрифт Material Symbols Rounded локально в ~/.local/share/fonts? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Скачивание Material Symbols Rounded..."
        curl -L -o "$HOME/.local/share/fonts/MaterialSymbolsRounded.ttf" \
            "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
        fc-cache -f "$HOME/.local/share/fonts"
        echo "Шрифт Material Symbols Rounded установлен."
    fi
else
    echo "Шрифт Material Symbols Rounded уже установлен."
fi

echo ""
echo "Продолжаем копирование конфигурационных файлов (quickshell, matugen, hypr)..."
echo ""
