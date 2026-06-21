#!/usr/bin/env bash

# выходим при любой ошибке
set -e

echo "╔══════════════════════════════════════════════╗"
echo "║   Quickshell Dock (google-dots) — Installer  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── 1. Ищем AUR хелпер ────────────────────────────────────────────────────
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

# ─── 2. Пакеты из официальных репозиториев (pacman) ─────────────────────────
PACMAN_PACKAGES=(
    # Hyprland (оконный менеджер)
    "hyprland"
    
    # Quickshell
    "quickshell"

    # Шрифты
    "ttf-roboto"
    "inter-font"                       # Inter (fallback шрифт)

    # Системные утилиты
    "jq"                               # JSON парсинг (Theme.qml, keyboard layout, wallpaper scripts)
    "python"                           # Python скрипты (list-apps.py, cliphist.py, clipboard_pin.py)
    "networkmanager"                   # nmcli — WiFi управление
    "bluez-utils"                      # bluetoothctl — Bluetooth управление
    "wireplumber"                      # wpctl — управление громкостью
    "brightnessctl"                    # управление яркостью
    "libnotify"                        # notify-send — уведомления (запись экрана)
    "blueman"                          # blueman-manager — расширенные настройки Bluetooth

    # Скриншоты и запись экрана
    "grim"                             # скриншоты (freeze screenshot для выбора области)
    "ffmpeg"                           # обрезка скриншотов по области (crop region)
    "wf-recorder"                      # запись экрана
    "wl-clipboard"                     # wl-copy — копирование в буфер обмена
    "hyprshot"                         # скриншоты окон и областей

    # Буфер обмена
    "cliphist"                         # менеджер истории буфера обмена

    # Блокировка экрана
    "hyprlock"                         # блокировка экрана

    # Обои и темы
    "curl"                             # скачивание случайных обоев (konachan, wallhaven)
    "zenity"                           # GUI выбор файла обоев (fallback file picker)

    # Системные утилиты (обычно уже установлены)
    "psmisc"                           # killall — остановка wf-recorder
    "procps-ng"                        # pgrep — проверка запущенных процессов
    "xdg-utils"                        # xdg-open — открытие файлов
    "power-profiles-daemon"            # управление профилями питания (performance/balanced/saver)
    "bc"                               # математические вычисления в скриптах
)

# ─── 3. Пакеты из AUR ──────────────────────────────────────────────────────
AUR_PACKAGES=(
    "ttf-google-sans"                  # Google Sans — основной UI шрифт
    "ttf-material-symbols-variable-git" # Material Symbols иконки
    "matugen-bin"                      # генерация Material You цветовой схемы из обоев
)


# ─── 4. Установка ──────────────────────────────────────────────────────────
echo "┌─────────────────────────────────────────────┐"
echo "│  Установка пакетов из официальных репозиториев │"
echo "└─────────────────────────────────────────────┘"
echo ""
echo "Пакеты: ${PACMAN_PACKAGES[*]}"
echo ""
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

echo ""
echo "┌─────────────────────────────────────────────┐"
echo "│  Установка пакетов из AUR                     │"
echo "└─────────────────────────────────────────────┘"
echo ""
echo "Пакеты: ${AUR_PACKAGES[*]}"
echo ""
$AUR_HELPER -S --needed --noconfirm "${AUR_PACKAGES[@]}"

# ─── 5. Проверка конфликтов демонов уведомлений ──────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────┐"
echo "│  Проверка на наличие других демонов уведомлений │"
echo "└─────────────────────────────────────────────┘"
echo ""

CONFLICTS=()
for pkg in dunst mako swaync fnott; do
    if pacman -Qs "^${pkg}$" > /dev/null; then
        CONFLICTS+=("$pkg")
    fi
done

if [ ${#CONFLICTS[@]} -gt 0 ]; then
    echo "⚠️ Внимание: У вас установлены сторонние демоны уведомлений (${CONFLICTS[*]})."
    echo "Quickshell использует свой собственный встроенный сервер уведомлений."
    echo "Сторонние демоны будут конфликтовать с ним и ломать уведомления."
    read -p "Удалить конфликтующие пакеты автоматически? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo pacman -Rns --noconfirm "${CONFLICTS[@]}"
        echo "Конфликтующие пакеты успешно удалены."
    else
        echo "Пропуск. Уведомления Quickshell могут не работать из-за конфликта DBus."
    fi
else
    echo "Конфликтов с уведомлениями не найдено."
fi

# ─── 6. Проверка установки ──────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────┐"
echo "│  Проверка установленных программ              │"
echo "└─────────────────────────────────────────────┘"
echo ""

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
    "curl:curl"
    "zenity:zenity"
    "matugen:matugen-bin (AUR)"
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
    echo "⚠️  Некоторые программы не найдены. Возможно нужно установить вручную:"
    for pkg in "${MISSING[@]}"; do
        echo "    - $pkg"
    done
fi

# ─── 7. Настройка Hyprland ─────────────────────────────────────────────────
echo ""
echo "Настройка Hyprland..."
HYPR_DIR="$HOME/.config/hypr"
HYPR_CONF="$HYPR_DIR/hyprland.conf"

mkdir -p "$HYPR_DIR"

if [ -f "$HYPR_CONF" ]; then
    BACKUP_CONF="$HYPR_DIR/hypr_backup_$(date +%Y%m%d_%H%M%S).conf"
    echo "Создание бэкапа существующего конфига Hyprland: $BACKUP_CONF"
    mv "$HYPR_CONF" "$BACKUP_CONF"
fi

echo "Копирование конфигурации Hyprland из репозитория..."
cp "$SCRIPT_DIR/hypr/hyprland.conf" "$HYPR_CONF"
echo "Конфигурация Hyprland обновлена."


# ─── 8. Копируем конфиг ────────────────────────────────────────────────────
echo ""
CONFIG_DIR="$HOME/.config/quickshell"

if [ -d "$CONFIG_DIR" ]; then
    echo "Директория $CONFIG_DIR уже существует."
    read -p "Создать бэкап и перезаписать конфигом из репозитория? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_DIR="${CONFIG_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Бэкап существующего конфига в $BACKUP_DIR..."
        mv "$CONFIG_DIR" "$BACKUP_DIR"
        echo "Копирование конфигурации..."
        cp -r "$SCRIPT_DIR/quickshell" "$CONFIG_DIR"
    fi
else
    echo "Копирование конфигурации в $CONFIG_DIR..."
    mkdir -p "$HOME/.config"
    cp -r "$SCRIPT_DIR/quickshell" "$CONFIG_DIR"
fi

# ─── 9. Копируем конфиг Matugen ────────────────────────────────────────────────
echo ""
MATUGEN_DIR="$HOME/.config/matugen"

if [ -d "$MATUGEN_DIR" ]; then
    echo "Директория $MATUGEN_DIR уже существует."
    read -p "Создать бэкап и перезаписать конфигом Matugen из репозитория? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_MATUGEN="${MATUGEN_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Бэкап существующего конфига в $BACKUP_MATUGEN..."
        mv "$MATUGEN_DIR" "$BACKUP_MATUGEN"
        echo "Копирование конфигурации Matugen..."
        cp -r "$SCRIPT_DIR/matugen" "$MATUGEN_DIR"
    fi
else
    echo "Копирование конфигурации Matugen в $MATUGEN_DIR..."
    mkdir -p "$HOME/.config"
    cp -r "$SCRIPT_DIR/matugen" "$MATUGEN_DIR"
fi

# ─── 10. Создаём директорию для обоев ───────────────────────────────────────
mkdir -p "$HOME/Pictures/Wallpapers"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║          ✅ Установка завершена!              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Запустите Quickshell командой 'quickshell' или перезайдите в Hyprland."
echo ""
