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
    "zenity"
    "blueman"
    "power-profiles-daemon"
    "google-roboto-fonts"
    "google-inter-fonts"
    "hyprpaper"
)

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

# 3. Download Material Symbols Rounded Font (required for icons)
echo ""
echo "Проверка шрифтов..."
mkdir -p "$HOME/.local/share/fonts"
if ! fc-list : family | grep -qi "Material Symbols"; then
    echo "Скачивание шрифта Material Symbols Rounded..."
    curl -L -o "$HOME/.local/share/fonts/MaterialSymbolsRounded.ttf" \
        "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
    fc-cache -f "$HOME/.local/share/fonts"
    echo "Шрифт Material Symbols Rounded установлен."
else
    echo "Шрифт Material Symbols Rounded уже установлен."
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
    "curl:curl"
    "zenity:zenity"
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
