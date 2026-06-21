# Reimagined Dots

A ChromeOS-inspired Quickshell config for Hyprland on Arch Linux. The repository mirrors the real `~/.config` layout, so the Quickshell files live under `.config/quickshell/`. It includes a floating dock, app launcher, quick settings, notifications, clipboard history, media controls, screen capture and recording, wallpaper selection, and a settings window with dynamic Material You theming.

## Installation

### Quick Install

```bash
git clone https://github.com/ubonly/reimagined-dots.git ~/reimagined-dots
rsync -a ~/reimagined-dots/.config/quickshell/ ~/.config/quickshell/
```

The repository is meant to be copied into place as-is. Add the required Hyprland rules manually if you have not done that already.

### Manual Setup

If you prefer to install things by hand, you will need:

- `hyprland`
- `quickshell-git`
- `ttf-roboto`
- `inter-font`
- `ttf-google-sans`
- `ttf-material-symbols-variable-git`
- `jq`
- `bc` (for math calculations in scripts)
- `python` & `python-pillow` (for wallpaper image validation)
- `networkmanager`
- `bluez-utils`
- `wireplumber`
- `brightnessctl`
- `libnotify`
- `psmisc`
- `procps-ng`
- `xdg-utils`
- `grim`
- `ffmpeg`
- `wf-recorder`
- `wl-clipboard`
- `hyprshot`
- `cliphist`
- `hyprlock`
- `curl`
- `zenity`
- `matugen-bin`
- `swww` or `hyprpaper` (for static wallpaper rendering)
- `mpvpaper` (optional, for video wallpaper rendering)

## Hyprland Configuration

Add these lines to `~/.config/hypr/hyprland.conf`:

```ini
layerrule = blur, quickshell
layerrule = ignorealpha 0.15, quickshell
layerrule = xray 0, quickshell

exec-once = quickshell
```

## Running Quickshell

```bash
quickshell
```

Or, if needed:

```bash
quickshell -p ~/.config/quickshell
```

## File Structure

```text
reimagined-dots/
├── README.md
└── .config/
    └── quickshell/
        ├── shell.qml
        ├── BackgroundWindow.qml
        ├── AppLauncher.qml
        ├── AppButton.qml
        ├── WorkspaceButton.qml
        ├── WorkspaceAppButton.qml
        ├── QuickSettingsPopup.qml
        ├── ScreenCapture.qml
        ├── ClipboardPopup.qml
        ├── MediaPopup.qml
        ├── NotificationsPopup.qml
        ├── NotificationCenterPopup.qml
        ├── SettingsWindow.qml
        ├── WallpaperSelectorWindow.qml
        ├── ClockWidget.qml
        ├── DockSeparator.qml
        ├── TrayIcon.qml
        ├── Theme/
        │   └── Theme.qml
        ├── services/
        │   ├── ConfigService.qml
        │   ├── AudioService.qml
        │   ├── BluetoothService.qml
        │   ├── BrightnessService.qml
        │   ├── NetworkService.qml
        │   └── MprisService.qml
        ├── list-apps.py
        ├── cliphist.py
        ├── clipboard_pin.py
        ├── list-recent.py
        ├── hypr-events.py
        ├── bt_list.sh
        ├── set_wallpaper.sh
        ├── set_theme_mode.sh
        ├── random_konachan.sh
        ├── random_osu.sh
        ├── toggle-launcher.sh
        ├── toggle-clipboard.sh
        ├── config.json
        ├── colors.json
        ├── apps.json
        ├── recent-apps.json
        └── assets/icons/
```

## Customization

- Edit `apps.json` to change launcher pins.
- Tweak colors and theme roles in `Theme/Theme.qml`.
- Wallpaper changes update `colors.json` through `matugen`.

## Shortcuts & IPC

| Shortcut | Action |
|---|---|
| `Super + R` | Toggle app launcher |
| `Super + V` | Toggle clipboard |
| `Super + I` | Toggle settings |
| `Super + Shift + S` | Region screenshot |
| `PrintScreen` | Fullscreen screenshot |

You can also trigger actions via IPC:

```bash
qs ipc call launcher toggle
qs ipc call clipboard_ui toggle
qs ipc call screenshot region
qs ipc call screenshot fullscreen
qs ipc call WallpaperSelector toggle
```
