#!/usr/bin/env bash

set -e

echo "┌─────────────────────────────────────────────┐"
echo "│      Running Debian/Ubuntu Installer        │"
echo "└─────────────────────────────────────────────┘"
echo ""

# 1. Install official Debian/Ubuntu packages
OS_ID=""
VERSION_CODENAME=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-}"
    VERSION_CODENAME="${VERSION_CODENAME:-}"
fi

APT_SKIPPED=()

apt_suite_enabled() {
    local suite="$1"
    grep -RhsE "^[^#].*${suite}" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null | grep -q "$suite"
}

enable_debian_backports() {
    if [ "$OS_ID" != "debian" ] || [ -z "$VERSION_CODENAME" ]; then
        return 1
    fi

    case "$VERSION_CODENAME" in
        sid|unstable|testing)
            return 1
            ;;
    esac

    local suite="${VERSION_CODENAME}-backports"
    if ! apt_suite_enabled "$suite"; then
        echo "Добавление официального Debian backports репозитория: $suite" >&2
        echo "deb http://deb.debian.org/debian $suite main contrib non-free non-free-firmware" | sudo tee "/etc/apt/sources.list.d/reimagined-${suite}.list" >/dev/null
    else
        echo "Debian backports уже подключён: $suite" >&2
    fi

    printf '%s\n' "$suite"
    return 0
}

apt_package_available() {
    apt-cache show "$1" >/dev/null 2>&1
}

install_apt_available() {
    local label="$1"
    shift

    local available=()
    local missing=()
    local pkg
    for pkg in "$@"; do
        if apt_package_available "$pkg"; then
            available+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    if [ ${#available[@]} -gt 0 ]; then
        echo ""
        echo "Установка $label через apt..."
        echo "Пакеты: ${available[*]}"
        sudo apt install -y "${available[@]}"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Эти пакеты не найдены в текущих apt-репозиториях и будут пропущены:"
        printf '  - %s\n' "${missing[@]}"
        APT_SKIPPED+=("${missing[@]}")
    fi
}

install_apt_available_from_suite() {
    local suite="$1"
    local label="$2"
    shift 2

    local available=()
    local missing=()
    local pkg
    for pkg in "$@"; do
        if apt_package_available "$pkg"; then
            available+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    if [ ${#available[@]} -gt 0 ]; then
        echo ""
        echo "Установка $label через apt ($suite как target release)..."
        echo "Пакеты: ${available[*]}"
        sudo apt install -y -t "$suite" "${available[@]}"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Эти пакеты не найдены в текущих apt-репозиториях и будут пропущены:"
        printf '  - %s\n' "${missing[@]}"
        APT_SKIPPED+=("${missing[@]}")
    fi
}

install_apt_backports_available() {
    local suite="$1"
    shift

    local available=()
    local missing=()
    local pkg
    for pkg in "$@"; do
        if apt-cache policy "$pkg" 2>/dev/null | grep -q "$suite"; then
            available+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    if [ ${#available[@]} -gt 0 ]; then
        echo ""
        echo "Установка Hyprland-компонентов из Debian backports ($suite)..."
        echo "Пакеты: ${available[*]}"
        sudo apt install -y -t "$suite" "${available[@]}"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Эти backports-пакеты не найдены и будут пропущены:"
        printf '  - %s\n' "${missing[@]}"
        APT_SKIPPED+=("${missing[@]}")
    fi
}

APT_BASE_PACKAGES=(
    "jq"
    "bc"
    "python3"
    "python3-pillow"
    "python3-dbus"
    "python3-gi"
    "python3-requests"
    "kdeconnect"
    "network-manager"
    "bluez"
    "wireplumber"
    "brightnessctl"
    "libnotify-bin"
    "psmisc"
    "procps"
    "xdg-utils"
    "xdg-user-dirs"
    "dbus-user-session"
    "fontconfig"
    "grim"
    "slurp"
    "ffmpeg"
    "wf-recorder"
    "wl-clipboard"
    "cliphist"
    "curl"
    "unzip"
    "zenity"
    "blueman"
    "power-profiles-daemon"
    "fonts-roboto"
    "kitty"
    "fish"
    "starship"
    "playerctl"
    "xdg-desktop-portal"
    "cmake"
    "ninja-build"
    "g++"
    "build-essential"
    "pkg-config"
    "cargo"
    "rustc"
    "git"
    "qt6-base-dev"
    "qt6-declarative-dev"
    "qt6-5compat-dev"
    "qt6-wayland-dev"
    "qt6-svg-dev"
    "libqt6svg6"
    "qml6-module-qtquick"
    "qml6-module-qtquick-layouts"
    "qml6-module-qtquick-controls"
    "qml6-module-qtquick-dialogs"
    "qml6-module-qt-labs-folderlistmodel"
    "qml6-module-qt-labs-platform"
    "qml6-module-qt5compat-graphicaleffects"
    "libsecret-1-dev"
    "libssl-dev"
    "libwayland-dev"
    "wayland-protocols"
    "libxkbcommon-dev"
    "libpam0g-dev"
    "libpipewire-0.3-dev"
)

DEBIAN_BACKPORT_PACKAGES=(
    "quickshell"
    "hyprland"
    "hyprlock"
    "hyprpaper"
    "hyprpolkitagent"
    "xdg-desktop-portal-hyprland"
)

APT_OPTIONAL_PACKAGES=(
    "swww"
    "mpvpaper"
)

echo "Обновление apt metadata..."
sudo apt update

BACKPORT_SUITE=""
if BACKPORT_SUITE="$(enable_debian_backports)"; then
    sudo apt update
fi

if [ -n "$BACKPORT_SUITE" ]; then
    install_apt_available_from_suite "$BACKPORT_SUITE" "системных пакетов Debian" "${APT_BASE_PACKAGES[@]}"
else
    install_apt_available "системных пакетов Debian/Ubuntu" "${APT_BASE_PACKAGES[@]}"
fi

if [ -n "$BACKPORT_SUITE" ]; then
    install_apt_backports_available "$BACKPORT_SUITE" "${DEBIAN_BACKPORT_PACKAGES[@]}"
else
    install_apt_available "Hyprland-компонентов" "${DEBIAN_BACKPORT_PACKAGES[@]}"
fi

install_apt_available "опциональных wallpaper-компонентов" "${APT_OPTIONAL_PACKAGES[@]}"

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
        sudo apt install -y cargo rustc build-essential pkg-config
    fi
fi

if command -v cargo &> /dev/null; then
    if command -v quickshell &> /dev/null; then
        echo "Quickshell уже установлен."
    else
        echo "⚠️ Quickshell не найден."
        echo "На Debian trixie он ставится из официального trixie-backports пакета 'quickshell'."
        echo "На Ubuntu установите Quickshell вручную по официальной инструкции: https://quickshell.org/docs/v0.3.0/guide/install-setup/"
        echo "Важно: 'cargo install quickshell' не существует, Quickshell не публикуется в crates.io."
    fi

    # Compile Matugen if not installed
    if ! command -v matugen &> /dev/null; then
        read -p "Установить Matugen через Cargo? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "Сборка и установка Matugen..."
            if ! cargo install matugen --locked; then
                echo "⚠️ Не удалось установить Matugen через Cargo. Установите matugen вручную или проверьте Rust toolchain."
            fi
        fi
    else
        echo "Matugen уже установлен."
    fi

    # Compile Starship if apt did not provide it
    if ! command -v starship &> /dev/null; then
        read -p "Starship не найден. Установить его через Cargo для terminal theming? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "Сборка и установка Starship..."
            if ! cargo install starship --locked; then
                echo "⚠️ Не удалось установить Starship через Cargo. Terminal theming будет неполным до установки starship."
            fi
        fi
    else
        echo "Starship уже установлен."
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
    "quickshell:quickshell"
    "matugen:matugen (Cargo)"
    "hyprctl:hyprland"
    "hyprlock:hyprlock"
    "hyprpaper:hyprpaper"
    "grim:grim"
    "slurp:slurp"
    "ffmpeg:ffmpeg"
    "wf-recorder:wf-recorder"
    "wl-copy:wl-clipboard"
    "cliphist:cliphist"
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
    "kitty:kitty"
    "fish:fish"
    "starship:starship"
    "playerctl:playerctl"
    "xdg-user-dir:xdg-user-dirs"
    "dbus-update-activation-environment:dbus-user-session"
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

if [ ${#APT_SKIPPED[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Пропущенные apt-пакеты:"
    printf '  - %s\n' "${APT_SKIPPED[@]}" | sort -u
    echo "На Debian они могут требовать backports или более свежий релиз. На Ubuntu Debian backports не подключается автоматически."
fi
