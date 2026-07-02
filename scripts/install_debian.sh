#!/usr/bin/env bash

set -e

echo "┌─────────────────────────────────────────────┐"
echo "│      Running Debian/Ubuntu Installer        │"
echo "└─────────────────────────────────────────────┘"
echo ""

# 1. Install official Debian/Ubuntu packages
DEBIAN_PACKAGES=(
    "jq"
    "bc"
    "python3-pillow"
    "python3-dbus"
    "python3-gi"
    "kdeconnect"
    "network-manager"
    "bluez"
    "wireplumber"
    "brightnessctl"
    "libnotify-bin"
    "psmisc"
    "procps"
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
    "power-profiles-daemon"
    "fonts-roboto"
    "hyprpaper"
    "cmake"
    "ninja-build"
    "g++"
    "pkg-config"
    "qt6-base-dev"
    "qt6-networkauth-dev"
    "libsecret-1-dev"
)

echo "Установка системных пакетов Debian/Ubuntu через apt..."
echo "Пакеты: ${DEBIAN_PACKAGES[*]}"
echo ""
sudo apt update
sudo apt install -y "${DEBIAN_PACKAGES[@]}"

# 2. Check for Notification Daemon Conflicts
echo ""
echo "Проверка конфликтующих демонов уведомлений..."
CONFLICTS=()
for pkg in dunst mako swaync fnott; do
    if dpkg -s "$pkg" &> /dev/null; then
        CONFLICTS+=("$pkg")
    fi
done

if [ ${#CONFLICTS[@]} -gt 0 ]; then
    echo "⚠️ Внимание: Установлены сторонние демоны уведомлений (${CONFLICTS[*]})."
    echo "Quickshell использует свой собственный встроенный сервер уведомлений."
    read -p "Удалить конфликтующие пакеты автоматически? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo apt remove -y "${CONFLICTS[@]}"
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
        sudo apt install -y cargo build-essential pkg-config
    fi
fi

if command -v cargo &> /dev/null; then
    # Compile Quickshell if not installed
    if ! command -v quickshell &> /dev/null; then
        read -p "Установить Quickshell из исходников через Cargo? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "Установка зависимостей сборки Quickshell..."
            sudo apt install -y qt6-base-dev qt6-declarative-dev qt6-5compat-dev qt6-wayland-dev libwayland-dev wayland-protocols libxkbcommon-dev
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
    "nmcli:network-manager"
    "bluetoothctl:bluez"
    "wpctl:wireplumber"
    "brightnessctl:brightnessctl"
    "notify-send:libnotify-bin"
    "jq:jq"
    "python3:python3"
    "kdeconnectd:kdeconnect"
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
    echo "⚠️  Не некоторые компоненты не найдены. Убедитесь, что ~/.cargo/bin добавлен в ваш PATH."
fi
