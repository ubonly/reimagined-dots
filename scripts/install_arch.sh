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
    echo "Ошибка: Не найден AUR хелпер (проверены: yay, paru, pikaur, aura, trizen, pakku)."
    echo "Установите один из них для установки AUR-зависимостей."
    exit 1
fi

echo "Используется AUR хелпер: $AUR_HELPER"
echo ""

# 2. Pacman Packages
PACMAN_PACKAGES=(
    "hyprland"
    "quickshell"
    "ttf-roboto"
    "inter-font"
    "ttf-jetbrains-mono-nerd"
    "cmake"
    "ninja"
    "gcc"
    "pkgconf"
    "qt6-base"
    "libsecret"
    "jq"
    "python"
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
    "ffmpeg"
    "wf-recorder"
    "wl-clipboard"
    "hyprshot"
    "cliphist"
    "hyprlock"
    "curl"
    "unzip"
    "zenity"
    "psmisc"
    "procps-ng"
    "xdg-utils"
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
echo "Установка пакетов из AUR..."
echo "Пакеты: ${AUR_PACKAGES[*]}"
echo ""
$AUR_HELPER -S --needed --noconfirm "${AUR_PACKAGES[@]}"

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
    "grim:grim"
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
    "matugen:matugen-bin (AUR)"
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
