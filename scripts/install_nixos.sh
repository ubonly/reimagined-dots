#!/usr/bin/env bash

set -e

echo "┌─────────────────────────────────────────────┐"
echo "│          NixOS Configuration Guide          │"
echo "└─────────────────────────────────────────────┘"
echo ""
echo "NixOS управляет пакетами декларативно через configuration.nix или Home Manager."
echo "В этом репозитории реализован Nix Flake с готовым модулем Home Manager,"
echo "который автоматически установит все пакеты и подключит нужные конфиги!"
echo ""
echo "Способ 1: Автоматическая установка через Home Manager (Flakes)"
echo "------------------------------------------------------------------"
echo "1. Добавьте этот репозиторий в inputs вашего flake.nix:"
cat << 'EOF'
inputs = {
  reimagined-dots.url = "github:ubonly/reimagined-dots";
};
EOF
echo ""
echo "2. Импортируйте модуль и включите его в вашем home.nix:"
cat << 'EOF'
imports = [
  inputs.reimagined-dots.homeManagerModules.default
];

programs.quickshell-reimagined.enable = true;
EOF
echo "------------------------------------------------------------------"
echo ""
echo "Способ 2: Классический вариант (без Home Manager)"
echo "------------------------------------------------------------------"
echo "Добавьте пакеты в ваш configuration.nix:"
cat << 'EOF'
  environment.systemPackages = with pkgs; [
    quickshell
    matugen
    jq
    bc
    (python3.withPackages (ps: [
      ps.dbus-python
      ps.pygobject3
      ps.pillow
      ps.requests
    ]))
    kdePackages.kdeconnect-kde
    hyprland
    hyprlock
    hyprpaper
    hyprpolkitagent
    hyprshot
    networkmanager
    bluez
    wireplumber
    blueman
    power-profiles-daemon
    brightnessctl
    libnotify
    psmisc
    procps
    xdg-utils
    xdg-user-dirs
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    dbus
    fontconfig
    glib
    polkit
    grim
    slurp
    ffmpeg
    wf-recorder
    wl-clipboard
    cliphist
    curl
    zenity
    kitty
    fish
    starship
    playerctl
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qt5compat
    qt6.qtwayland
    qt6.qtsvg
    wayland
    wayland-protocols
    libxkbcommon
    linux-pam
    pipewire
    libsecret
    nerd-fonts.jetbrains-mono
  ];

  # Не забудьте включить службы:
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.power-profiles-daemon.enable = true;
  programs.hyprland.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
EOF
echo "------------------------------------------------------------------"
echo ""

# Download Material Symbols font if not present
echo "Шрифты"
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
