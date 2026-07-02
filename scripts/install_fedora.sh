#!/usr/bin/env bash

set -e

echo "┌─────────────────────────────────────────────┐"
echo "│          Running Fedora Installer           │"
echo "└─────────────────────────────────────────────┘"
echo ""

# 1. Install official Fedora packages
FEDORA_PACKAGES=(
    "jq"
    "bc"
    "python3-pillow"
    "python3-dbus"
    "python3-gobject"
    "kde-connect"
    "NetworkManager"
    "bluez"
    "wireplumber"
    "brightnessctl"
    "libnotify"
    "psmisc"
    "procps-ng"
    "xdg-utils"
    "grim"
    "ffmpeg"
    "wf-recorder"
    "wl-clipboard"
    "hyprlock"
    "curl"
    "unzip"
    "zenity"
    "blueman"
    "google-roboto-fonts"
    "hyprpaper"
    "cmake"
    "ninja-build"
    "gcc-c++"
    "pkgconf-pkg-config"
    "qt6-qtbase-devel"
    "libsecret-devel"
)

# Проверяем наличие установленного tuned-ppd или power-profiles-daemon, чтобы избежать конфликтов
if rpm -q tuned-ppd &>/dev/null || rpm -q power-profiles-daemon &>/dev/null; then
    echo "Провайдер профилей питания (tuned-ppd или power-profiles-daemon) уже установлен."
else
    echo "Добавляем power-profiles-daemon в список установки..."
    FEDORA_PACKAGES+=("power-profiles-daemon")
fi

echo "Установка системных пакетов Fedora через dnf..."
echo "Пакеты: ${FEDORA_PACKAGES[*]}"
echo ""
sudo dnf install -y "${FEDORA_PACKAGES[@]}"

# 2. Check for Notification Daemon Conflicts
echo ""
echo "Проверка конфликтующих демонов уведомлений..."
CONFLICTS=()
for pkg in dunst mako swaync fnott; do
    if rpm -q "$pkg" &> /dev/null; then
        CONFLICTS+=("$pkg")
    fi
done

if [ ${#CONFLICTS[@]} -gt 0 ]; then
    echo "⚠️ Внимание: Установлены сторонние демоны уведомлений (${CONFLICTS[*]})."
    echo "Quickshell использует свой собственный встроенный сервер уведомлений."
    read -p "Удалить конфликтующие пакеты автоматически? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo dnf remove -y "${CONFLICTS[@]}"
        echo "Конфликтующие пакеты удалены."
    else
        echo "Пропуск удаления. Могут возникнуть конфликты с DBus уведомлениями."
    fi
else
    echo "Конфликтов с уведомлениями не найдено."
fi

# 3. Download Fonts (required for icons and UI styling)
echo ""
echo "Проверка шрифтов..."
mkdir -p "$HOME/.local/share/fonts"
NEED_FC_CACHE=0

# Material Symbols
if ! fc-list : family | grep -qi "Material Symbols" 2>/dev/null; then
    echo "Скачивание шрифта Material Symbols Rounded..."
    curl -L -o "$HOME/.local/share/fonts/MaterialSymbolsRounded.ttf" \
        "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
    NEED_FC_CACHE=1
fi

# Inter
if ! fc-list : family | grep -qi "Inter" 2>/dev/null; then
    echo "Скачивание шрифта Inter..."
    curl -L -o "$HOME/.local/share/fonts/Inter-Regular.ttf" \
        "https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Regular.ttf"
    curl -L -o "$HOME/.local/share/fonts/Inter-Medium.ttf" \
        "https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Medium.ttf"
    curl -L -o "$HOME/.local/share/fonts/Inter-Bold.ttf" \
        "https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Bold.ttf"
    NEED_FC_CACHE=1
fi

# JetBrainsMono Nerd Font for the Starship terminal prompt
if ! fc-match "JetBrains Mono Nerd Font" | grep -qi "JetBrainsMono Nerd Font" 2>/dev/null; then
    echo "Скачивание шрифта JetBrainsMono Nerd Font..."
    mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd"
    curl -L -o /tmp/JetBrainsMonoNerdFont.zip \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    unzip -o /tmp/JetBrainsMonoNerdFont.zip -d "$HOME/.local/share/fonts/JetBrainsMonoNerd" '*.ttf' >/dev/null
    NEED_FC_CACHE=1
fi

if [ $NEED_FC_CACHE -eq 1 ]; then
    fc-cache -f "$HOME/.local/share/fonts"
    echo "Шрифты успешно установлены и кэш обновлен."
else
    echo "Все необходимые шрифты уже установлены."
fi

# 4. Check for Cargo and compile Quickshell and Matugen if needed
echo ""
if ! command -v cargo &> /dev/null; then
    read -p "Cargo (Rust) не установлен. Установить его и средства сборки? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo dnf install -y cargo gcc-c++ pkgconf-pkg-config
    fi
fi

if command -v cargo &> /dev/null; then
    # Compile Quickshell if not installed
    if ! command -v quickshell &> /dev/null; then
        read -p "Установить Quickshell из исходников через Cargo? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "Установка зависимостей сборки Quickshell..."
            sudo dnf install -y qt6-qtdeclarative-devel qt6-qt5compat-devel qt6-qtwayland-devel wayland-devel wayland-protocols-devel libxkbcommon-devel
            echo "Сборка и установка Quickshell (это может занять несколько минут)..."
            cargo install quickshell --locked
        fi
    else
        echo "Quickshell уже установлен."
    fi

    # Compile Matugen if not installed
    if ! command -v matugen &> /dev/null; then
        read -p "Установить Matugen через Cargo? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "Сборка и установка Matugen..."
            cargo install matugen --locked
        fi
    else
        echo "Matugen уже установлен."
    fi
else
    echo "⚠️ Внимание: Для работы конфига требуются quickshell и matugen."
    echo "Пожалуйста, установите их вручную."
fi

# 5. Verification
echo ""
echo "Проверка установленных программ..."
MISSING=()
COMMANDS=(
    "quickshell:quickshell (Cargo)"
    "matugen:matugen (Cargo)"
    "hyprlock:hyprlock"
    "grim:grim"
    "ffmpeg:ffmpeg"
    "wf-recorder:wf-recorder"
    "wl-copy:wl-clipboard"
    "nmcli:NetworkManager"
    "bluetoothctl:bluez"
    "wpctl:wireplumber"
    "brightnessctl:brightnessctl"
    "notify-send:libnotify"
    "jq:jq"
    "python3:python3"
    "kdeconnectd:kde-connect"
    "curl:curl"
    "zenity:zenity"
    "cmake:cmake"
    "ninja:ninja-build"
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
    echo "⚠️  Некоторые компоненты не найдены. Убедитесь, что ~/.cargo/bin добавлен в ваш PATH."
fi
