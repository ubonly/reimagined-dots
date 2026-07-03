#!/usr/bin/env bash

set -e

echo "┌─────────────────────────────────────────────┐"
echo "│         Running Arch Linux Installer        │"
echo "└─────────────────────────────────────────────┘"
echo ""

# 1. Find AUR Helper
AUR_HELPER=""
HELPERS=("yay" "paru" "pikaur" "aura" "trizen" "pakku")

for helper in "${HELPERS[@]}"; do
    if command -v "$helper" &> /dev/null; then
        AUR_HELPER="$helper"
        break
    fi
done

if [ -z "$AUR_HELPER" ]; then
    echo "⚠️ Не найден AUR хелпер (проверены: yay, paru, pikaur, aura, trizen, pakku)."
    echo "Официальные пакеты будут установлены, AUR-зависимости будут пропущены."
else
    echo "Используется AUR хелпер: $AUR_HELPER"
fi
echo ""

# 2. Pacman Packages
PACMAN_PACKAGES=(
    "hyprland"
    "quickshell"
    "hyprlock"
    "hyprpaper"
    "hyprpolkitagent"
    "ttf-roboto"
    "inter-font"
    "ttf-jetbrains-mono-nerd"
    "fontconfig"
    "cmake"
    "ninja"
    "gcc"
    "rust"
    "cargo"
    "pkgconf"
    "qt6-base"
    "qt6-declarative"
    "qt6-5compat"
    "qt6-wayland"
    "qt6-svg"
    "wayland-protocols"
    "libxkbcommon"
    "pam"
    "pipewire"
    "libsecret"
    "jq"
    "python"
    "python-pillow"
    "python-requests"
    "python-dbus"
    "python-gobject"
    "kdeconnect"
    "networkmanager"
    "bluez-utils"
    "wireplumber"
    "brightnessctl"
    "libnotify"
    "blueman"
    "grim"
    "slurp"
    "ffmpeg"
    "wf-recorder"
    "wl-clipboard"
    "hyprshot"
    "cliphist"
    "curl"
    "unzip"
    "zenity"
    "kitty"
    "fish"
    "starship"
    "playerctl"
    "psmisc"
    "procps-ng"
    "xdg-utils"
    "xdg-user-dirs"
    "xdg-desktop-portal"
    "xdg-desktop-portal-hyprland"
    "dbus"
    "glib2"
    "polkit"
    "power-profiles-daemon"
    "bc"
)

# 3. AUR Packages
AUR_PACKAGES=(
    "ttf-google-sans"
    "ttf-material-symbols-variable-git"
    "matugen-bin"
)

echo "Установка пакетов из официальных репозиториев..."
echo "Пакеты: ${PACMAN_PACKAGES[*]}"
echo ""
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

echo ""
if [ -n "$AUR_HELPER" ]; then
    echo "Установка пакетов из AUR..."
    echo "Пакеты: ${AUR_PACKAGES[*]}"
    echo ""
    $AUR_HELPER -S --needed --noconfirm "${AUR_PACKAGES[@]}"
else
    echo "Пропуск AUR-пакетов: ${AUR_PACKAGES[*]}"
fi

if ! command -v matugen &> /dev/null; then
    if command -v cargo &> /dev/null; then
        read -p "Matugen не найден. Установить его через Cargo? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            cargo install matugen --locked
        fi
    else
        echo "⚠️ Matugen не найден, Cargo тоже не найден. Установите matugen вручную."
    fi
fi

# 4. Check for Notification Daemon Conflicts
echo ""
echo "Проверка конфликтующих демонов уведомлений..."
CONFLICTS=()
for pkg in dunst mako swaync fnott; do
    if pacman -Qs "^${pkg}$" > /dev/null; then
        CONFLICTS+=("$pkg")
    fi
done

if [ ${#CONFLICTS[@]} -gt 0 ]; then
    echo "⚠️ Внимание: Установлены сторонние демоны уведомлений (${CONFLICTS[*]})."
    echo "Quickshell использует свой собственный встроенный сервер уведомлений."
    read -p "Удалить конфликтующие пакеты автоматически? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo pacman -Rns --noconfirm "${CONFLICTS[@]}"
        echo "Конфликтующие пакеты удалены."
    else
        echo "Пропуск удаления. Могут возникнуть конфликты с DBus уведомлениями."
    fi
else
    echo "Конфликтов с уведомлениями не найдено."
fi

# 5. Verification Checklist
echo ""
echo "Проверка установленных программ..."
MISSING=()
COMMANDS=(
    "quickshell:quickshell"
    "hyprctl:hyprland"
    "hyprshot:hyprshot"
    "hyprlock:hyprlock"
    "hyprpaper:hyprpaper"
    "grim:grim"
    "slurp:slurp"
    "ffmpeg:ffmpeg"
    "wf-recorder:wf-recorder"
    "wl-copy:wl-clipboard"
    "cliphist:cliphist"
    "nmcli:networkmanager"
    "bluetoothctl:bluez-utils"
    "wpctl:wireplumber"
    "brightnessctl:brightnessctl"
    "blueman-manager:blueman"
    "notify-send:libnotify"
    "jq:jq"
    "python3:python"
    "kdeconnectd:kdeconnect"
    "curl:curl"
    "zenity:zenity"
    "kitty:kitty"
    "fish:fish"
    "starship:starship"
    "playerctl:playerctl"
    "xdg-user-dir:xdg-user-dirs"
    "dbus-update-activation-environment:dbus"
    "matugen:matugen-bin (AUR) or Cargo"
    "cmake:cmake"
    "ninja:ninja"
    "killall:psmisc"
)

for entry in "${COMMANDS[@]}"; do
    cmd="${entry%%:*}"
    pkg="${entry##*:}"
    if command -v "$cmd" &> /dev/null; then
        echo "  ✅ $cmd"
    else
        echo "  ❌ $cmd (пакет: $pkg)"
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Некоторые компоненты не найдены. Рекомендуется установить их вручную."
fi
