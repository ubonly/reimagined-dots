#!/usr/bin/env bash

# выходим при любой ошибке
set -e

echo "╔══════════════════════════════════════════════╗"
echo "║   Quickshell Dock — Multi-Distro Installer   ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

backup_and_copy_dir() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ ! -d "$src" ]; then
        return 0
    fi

    if [ -d "$dest" ]; then
        echo "Директория $dest уже существует."
        read -p "Создать бэкап и перезаписать $label из репозитория? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Пропуск копирования $label."
            return 0
        fi

        local backup="${dest}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "Бэкап существующего $label в $backup..."
        mv "$dest" "$backup"
    fi

    echo "Копирование $label в $dest..."
    mkdir -p "$(dirname "$dest")"
    cp -r "$src" "$dest"
}

install_user_fonts_and_aliases() {
    echo ""
    echo "Настройка шрифтов и fontconfig aliases..."

    local fonts_dir="$HOME/.local/share/fonts"
    local fontconfig_dir="$HOME/.config/fontconfig/conf.d"
    local bundled_fonts_dir="$SCRIPT_DIR/.config/quickshell/sans_font"
    local bundled_target_dir="$fonts_dir/ReimaginedSans"
    local need_fc_cache=0

    mkdir -p "$fonts_dir" "$fontconfig_dir"

    if ! command -v fc-match >/dev/null 2>&1; then
        echo "⚠️ fontconfig/fc-match не найден, шрифты будут скопированы, но кэш может не обновиться."
    fi

    if [ -d "$bundled_fonts_dir" ]; then
        echo "Установка bundled Google Sans из .config/quickshell/sans_font..."
        rm -rf "$bundled_target_dir"
        mkdir -p "$bundled_target_dir"
        cp -r "$bundled_fonts_dir"/. "$bundled_target_dir"/
        need_fc_cache=1
    else
        echo "⚠️ bundled Google Sans не найден: $bundled_fonts_dir"
    fi

    if command -v curl >/dev/null 2>&1; then
        if ! command -v fc-match >/dev/null 2>&1 || ! fc-match "Material Symbols Rounded" 2>/dev/null | grep -qi "MaterialSymbols\\|Material Symbols"; then
            echo "Скачивание Material Symbols Rounded..."
            curl -L -o "$fonts_dir/MaterialSymbolsRounded.ttf" \
                "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" || true
            need_fc_cache=1
        fi

        if ! command -v fc-match >/dev/null 2>&1 || ! fc-match "Material Symbols Outlined" 2>/dev/null | grep -qi "MaterialSymbols\\|Material Symbols"; then
            echo "Скачивание Material Symbols Outlined..."
            curl -L -o "$fonts_dir/MaterialSymbolsOutlined.ttf" \
                "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" || true
            need_fc_cache=1
        fi

        if ! command -v fc-match >/dev/null 2>&1 || ! fc-match "Inter" 2>/dev/null | grep -qi "Inter"; then
            echo "Скачивание Inter..."
            curl -L -o "$fonts_dir/Inter-Regular.ttf" "https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Regular.ttf" || true
            curl -L -o "$fonts_dir/Inter-Medium.ttf" "https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Medium.ttf" || true
            curl -L -o "$fonts_dir/Inter-Bold.ttf" "https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Bold.ttf" || true
            need_fc_cache=1
        fi

        if ! command -v fc-match >/dev/null 2>&1 || ! fc-match "JetBrains Mono Nerd Font" 2>/dev/null | grep -qi "JetBrainsMono Nerd Font\\|JetBrains Mono Nerd"; then
            echo "Скачивание JetBrainsMono Nerd Font..."
            mkdir -p "$fonts_dir/JetBrainsMonoNerd"
            curl -L -o /tmp/JetBrainsMonoNerdFont.zip \
                "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" || true
            if [ -s /tmp/JetBrainsMonoNerdFont.zip ]; then
                unzip -o /tmp/JetBrainsMonoNerdFont.zip -d "$fonts_dir/JetBrainsMonoNerd" '*.ttf' >/dev/null || true
                need_fc_cache=1
            fi
        fi
    else
        echo "⚠️ curl не найден, пропуск скачивания пользовательских шрифтов."
    fi

    cat > "$fontconfig_dir/99-reimagined-dots-fonts.conf" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias>
    <family>Google Sans</family>
    <prefer>
      <family>Google Sans</family>
      <family>Inter</family>
      <family>Noto Sans</family>
    </prefer>
  </alias>
  <alias>
    <family>Google Sans Text</family>
    <prefer>
      <family>Google Sans Text</family>
      <family>Google Sans</family>
      <family>Inter</family>
      <family>Noto Sans</family>
    </prefer>
  </alias>
  <alias>
    <family>Google Sans Code</family>
    <prefer>
      <family>Google Sans Code</family>
      <family>JetBrains Mono Nerd Font</family>
      <family>monospace</family>
    </prefer>
  </alias>
  <alias>
    <family>Material Symbols Rounded</family>
    <prefer>
      <family>Material Symbols Rounded</family>
      <family>Material Symbols Outlined</family>
    </prefer>
  </alias>
</fontconfig>
EOF
    need_fc_cache=1

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$fonts_dir" "$HOME/.config/fontconfig" >/dev/null 2>&1 || fc-cache -f >/dev/null 2>&1 || true
    fi

    if [ "$need_fc_cache" -eq 1 ]; then
        echo "Шрифты и aliases обновлены."
    fi
}

find_initial_wallpaper() {
    local configured=""

    if [ -f "$CONFIG_DIR/config.json" ] && command -v jq >/dev/null 2>&1; then
        configured="$(jq -r '.wallpaperPath // empty' "$CONFIG_DIR/config.json" 2>/dev/null || true)"
        if [ -n "$configured" ] && [ -f "$configured" ]; then
            printf '%s\n' "$configured"
            return 0
        fi
    fi

    find "$HOME/Pictures/Wallpapers" "$HOME/Pictures" "$HOME/Downloads" \
        -maxdepth 2 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' \) \
        2>/dev/null | head -n 1
}

repair_initial_config_and_theme() {
    echo ""
    echo "Начальная настройка Matugen, Hyprland и terminal theme..."

    mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/.config/hypr" "$HOME/.config/kitty"

    if [ -f "$CONFIG_DIR/config.json" ] && command -v jq >/dev/null 2>&1; then
        local wp
        wp="$(jq -r '.wallpaperPath // empty' "$CONFIG_DIR/config.json" 2>/dev/null || true)"
        if [ -n "$wp" ] && [ ! -f "$wp" ]; then
            echo "Очистка несуществующего wallpaperPath из config.json: $wp"
            local tmp="${CONFIG_DIR}/config.json.tmp.$$"
            jq '.wallpaperPath = "" | .wallpaperState = ""' "$CONFIG_DIR/config.json" > "$tmp" && mv "$tmp" "$CONFIG_DIR/config.json"
        fi
    fi

    local initial_wallpaper
    initial_wallpaper="$(find_initial_wallpaper || true)"

    if [ -n "$initial_wallpaper" ] && [ -f "$initial_wallpaper" ] && [ -x "$CONFIG_DIR/set_wallpaper.sh" ]; then
        echo "Генерация цветов Matugen из: $initial_wallpaper"
        "$CONFIG_DIR/set_wallpaper.sh" "$initial_wallpaper" || true
        sleep 1
        return 0
    fi

    if [ -f "$CONFIG_DIR/colors.json" ] && [ -f "$CONFIG_DIR/apply_matugen_pipeline.py" ]; then
        echo "Применение существующего colors.json к Hyprland/Kitty/GTK/Fish..."
        python3 "$CONFIG_DIR/apply_matugen_pipeline.py" || true
        return 0
    fi

    echo "⚠️ Wallpaper для первого Matugen-прогона не найден. Цвета применятся после выбора обоев в Settings."
}

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

for conf in hyprland.conf hyprland.lua hyprlock.conf lock.sh lock-status.sh; do
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

# ─── 3. Копируем конфиги приложений ───────────────────────────────────────
echo ""
CONFIG_DIR="$HOME/.config/quickshell"
MATUGEN_DIR="$HOME/.config/matugen"

backup_and_copy_dir "$SCRIPT_DIR/.config/quickshell" "$CONFIG_DIR" "конфиг Quickshell"
backup_and_copy_dir "$SCRIPT_DIR/.config/matugen" "$MATUGEN_DIR" "конфиг Matugen"
backup_and_copy_dir "$SCRIPT_DIR/.config/kitty" "$HOME/.config/kitty" "конфиг Kitty"

find "$CONFIG_DIR" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} \; 2>/dev/null || true
find "$MATUGEN_DIR" -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

install_user_fonts_and_aliases

# ─── 5. Собираем нативные helper'ы ──────────────────────────────────────────
if [ -x "$CONFIG_DIR/accounts/build.sh" ]; then
    echo ""
    echo "Сборка Account Provider helper..."
    if "$CONFIG_DIR/accounts/build.sh"; then
        echo "Account Provider helper собран."
    else
        echo "⚠️ Не удалось собрать Account Provider helper. Google account останется отключенным."
    fi
fi

if [ -x "$CONFIG_DIR/launcher/build.sh" ]; then
    echo ""
    echo "Сборка Launcher helper..."
    if "$CONFIG_DIR/launcher/build.sh"; then
        echo "Launcher helper собран."
    else
        echo "⚠️ Не удалось собрать Launcher helper. App Launcher будет использовать последний кэш приложений."
    fi
fi

# ─── 6. Создаём директорию для обоев ───────────────────────────────────────
mkdir -p "$HOME/Pictures/Wallpapers"

repair_initial_config_and_theme

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║          ✅ Установка завершена!              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Запустите Quickshell командой 'quickshell' или перезайдите в Hyprland."
echo ""
