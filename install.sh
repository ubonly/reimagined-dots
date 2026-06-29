#!/usr/bin/env bash

# выходим при любой ошибке
set -e

echo "╔══════════════════════════════════════════════╗"
echo "║   Quickshell Dock — Multi-Distro Installer   ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── 1. Определение дистрибутива ──────────────────────────────────────────
OS_ID=""
OS_LIKE=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_LIKE="$ID_LIKE"
fi

echo "Определён дистрибутив: $NAME ($OS_ID)"
echo ""

RUN_INSTALLER=""
case "$OS_ID" in
    arch)
        RUN_INSTALLER="scripts/install_arch.sh"
        ;;
    fedora)
        RUN_INSTALLER="scripts/install_fedora.sh"
        ;;
    debian|ubuntu)
        RUN_INSTALLER="scripts/install_debian.sh"
        ;;
    nixos)
        RUN_INSTALLER="scripts/install_nixos.sh"
        ;;
    *)
        # Проверяем ID_LIKE для совместимости (например, EndeavourOS -> arch)
        if [[ "$OS_LIKE" =~ "arch" ]]; then
            RUN_INSTALLER="scripts/install_arch.sh"
        elif [[ "$OS_LIKE" =~ "fedora" ]]; then
            RUN_INSTALLER="scripts/install_fedora.sh"
        elif [[ "$OS_LIKE" =~ "debian" || "$OS_LIKE" =~ "ubuntu" ]]; then
            RUN_INSTALLER="scripts/install_debian.sh"
        fi
        ;;
esac

if [ -n "$RUN_INSTALLER" ]; then
    echo "Запуск скрипта установки для $OS_ID ($RUN_INSTALLER)..."
    bash "$SCRIPT_DIR/$RUN_INSTALLER"
else
    echo "⚠️ Не удалось автоматически определить скрипт установки для вашей ОС ($OS_ID)."
    echo "Выберите дистрибутив вручную:"
    echo "  1) Arch Linux / EndeavourOS / Manjaro"
    echo "  2) Fedora"
    echo "  3) Debian / Ubuntu"
    echo "  4) NixOS"
    echo "  5) Пропустить установку зависимостей (только копирование конфигов)"
    echo ""
    read -p "Выберите опцию [1-5]: " -n 1 -r
    echo
    case "$REPLY" in
        1) bash "$SCRIPT_DIR/scripts/install_arch.sh" ;;
        2) bash "$SCRIPT_DIR/scripts/install_fedora.sh" ;;
        3) bash "$SCRIPT_DIR/scripts/install_debian.sh" ;;
        4) bash "$SCRIPT_DIR/scripts/install_nixos.sh" ;;
        5) echo "Пропуск установки зависимостей..." ;;
        *) echo "Неверный выбор. Выход."; exit 1 ;;
    esac
fi

# ─── 2. Настройка Hyprland ─────────────────────────────────────────────────
echo ""
echo "Настройка Hyprland..."
HYPR_DIR="$HOME/.config/hypr"
mkdir -p "$HYPR_DIR"

for conf in hyprland.conf hyprlock.conf lock.sh lock-status.sh; do
    SRC_CONF="$SCRIPT_DIR/.config/hypr/$conf"
    DEST_CONF="$HYPR_DIR/$conf"
    if [ -f "$SRC_CONF" ]; then
        if [ -f "$DEST_CONF" ]; then
            BACKUP_CONF="$HYPR_DIR/${conf}_backup_$(date +%Y%m%d_%H%M%S)"
            echo "Создание бэкапа существующего конфига Hyprland ($conf): $BACKUP_CONF"
            mv "$DEST_CONF" "$BACKUP_CONF"
        fi
        echo "Копирование $conf из репозитория..."
        cp "$SRC_CONF" "$DEST_CONF"
        case "$conf" in
            *.sh) chmod +x "$DEST_CONF" ;;
        esac
    fi
done
echo "Конфигурация Hyprland обновлена."

# ─── 3. Копируем конфиг Quickshell ──────────────────────────────────────────
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
        cp -r "$SCRIPT_DIR/.config/quickshell" "$CONFIG_DIR"
    fi
else
    echo "Копирование конфигурации в $CONFIG_DIR..."
    mkdir -p "$HOME/.config"
    cp -r "$SCRIPT_DIR/.config/quickshell" "$CONFIG_DIR"
fi

# ─── 4. Копируем конфиг Matugen ────────────────────────────────────────────────
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
        cp -r "$SCRIPT_DIR/.config/matugen" "$MATUGEN_DIR"
    fi
else
    echo "Копирование конфигурации Matugen в $MATUGEN_DIR..."
    mkdir -p "$HOME/.config"
    cp -r "$SCRIPT_DIR/.config/matugen" "$MATUGEN_DIR"
fi

# ─── 5. Создаём директорию для обоев ───────────────────────────────────────
mkdir -p "$HOME/Pictures/Wallpapers"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║          ✅ Установка завершена!              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Запустите Quickshell командой 'quickshell' или перезайдите в Hyprland."
echo ""
