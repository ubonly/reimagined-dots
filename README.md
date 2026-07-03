# Reimagined Dots

A ChromeOS-inspired Quickshell config for Hyprland on Arch Linux. The repository mirrors the real `~/.config` layout, so the Quickshell files live under `.config/quickshell/`. It includes a floating dock, app launcher, quick settings, notifications, clipboard history, media controls, screen capture and recording, wallpaper selection, and a settings window with dynamic Material You theming.

## Installation

### Automatic Install (Supports Arch, Fedora, Debian/Ubuntu, NixOS)

```bash
git clone https://github.com/ubonly/reimagined-dots.git ~/reimagined-dots
cd ~/reimagined-dots
./install.sh
```

The script will automatically detect your Linux distribution, install the necessary package dependencies, copy all configs (`quickshell`, `matugen`, `hypr`), and set up backups.

### Manual Setup

If you prefer to install things by hand, you will need:

- `hyprland`
- `quickshell`
- `hyprlock`
- `hyprpaper`
- `hyprpolkitagent` (recommended)
- `ttf-roboto`
- `inter-font`
- `ttf-jetbrains-mono-nerd`
- `ttf-google-sans`
- `ttf-material-symbols-variable-git`
- `fontconfig`
- `jq`
- `bc` (for math calculations in scripts)
- `python`, `python-pillow`, Python DBus/GObject bindings
- Qt 6 QML modules: QtQuick, Layouts, Controls, Dialogs, Qt5Compat GraphicalEffects, Qt Wayland, Qt SVG
- `libsecret` development files for the Google account helper
- `networkmanager`
- `bluez-utils`
- `wireplumber`
- `brightnessctl`
- `libnotify`
- `psmisc`
- `procps-ng`
- `xdg-utils`
- `xdg-user-dirs`
- `xdg-desktop-portal`
- `xdg-desktop-portal-hyprland` (recommended on Hyprland)
- `grim`
- `slurp`
- `ffmpeg`
- `wf-recorder`
- `wl-clipboard`
- `hyprshot`
- `cliphist`
- `curl`
- `zenity`
- `matugen`
- `kitty`, `fish`, `starship` (for the themed terminal prompt)
- `playerctl`
- `swww` or `hyprpaper` (for static wallpaper rendering)
- `mpvpaper` (optional, for video wallpaper rendering)

### Other Distributions Compatibility

Almost all dependencies are available across other major Linux distributions. Here is a package name mapping helper:

#### Fedora
Most core utilities can be installed via `dnf`:
```bash
sudo dnf install hyprland hyprlock hyprpaper jq bc python3-pillow python3-dbus python3-gobject kde-connect NetworkManager bluez wireplumber brightnessctl libnotify psmisc procps-ng xdg-utils xdg-user-dirs grim slurp ffmpeg-free wf-recorder wl-clipboard cliphist curl zenity kitty fish playerctl xdg-desktop-portal xdg-desktop-portal-hyprland
```
* **Quickshell**: Build from source (`cargo install quickshell` or use Copr repo if available).
* **Matugen**: Install via cargo (`cargo install matugen`) or download from Github releases.
* **Starship / Hyprshot / swww / mpvpaper**: not always present in enabled Fedora repositories. The installer checks availability, skips unavailable packages, and can install Starship through Cargo.

#### Debian / Ubuntu

On Debian stable/trixie, Hyprland components such as `hyprland`, `hyprlock`, `hyprpaper`, `hyprpolkitagent`, and `xdg-desktop-portal-hyprland` are installed from official Debian backports by the installer. Ubuntu does not get Debian backports automatically; unavailable packages are skipped with a warning.

Install core utilities via `apt`:
```bash
sudo apt install jq bc python3 python3-pillow python3-dbus python3-gi kdeconnect network-manager bluez wireplumber brightnessctl libnotify-bin psmisc procps xdg-utils xdg-user-dirs grim slurp ffmpeg wf-recorder wl-clipboard cliphist curl zenity kitty fish starship playerctl
```
* **Quickshell & Matugen**: Build from source (cargo / github releases).
* **Debian backports**: use `./install.sh` or manually add your codename backports suite before installing Hyprland packages.

#### NixOS

You can install this configuration declaratively using Nix Flakes and Home Manager, or manually:

##### Option A: Home Manager Module (Recommended)

Add this repository to your flake inputs:

```nix
inputs = {
  reimagined-dots.url = "github:ubonly/reimagined-dots";
};
```

Then import the module and enable it in your home-manager configuration:

```nix
imports = [
  inputs.reimagined-dots.homeManagerModules.default
];

programs.quickshell-reimagined.enable = true;
```

This will automatically pull all required package dependencies and symlink the `quickshell` and `matugen` configuration directories to `~/.config/`.

##### Option B: Manual Installation

Add the following package names to your `environment.systemPackages` or Home Manager config:
* `pkgs.quickshell` (available in nixpkgs-unstable)
* `pkgs.matugen` (available in nixpkgs-unstable)
* `pkgs.jq`, `pkgs.bc`, Python with `dbus-python`, `pygobject3`, `pillow`, and `requests`
* `pkgs.brightnessctl`, `pkgs.libnotify`, `pkgs.psmisc`, `pkgs.procps`, `pkgs.xdg-utils`
* `pkgs.grim`, `pkgs.slurp`, `pkgs.ffmpeg`, `pkgs.wf-recorder`, `pkgs.wl-clipboard`
* `pkgs.cliphist`, `pkgs.hyprlock`, `pkgs.hyprpaper`, `pkgs.hyprshot`, `pkgs.curl`, `pkgs.zenity`
* `pkgs.kitty`, `pkgs.fish`, `pkgs.starship`, `pkgs.playerctl`
* `pkgs.swww` or `pkgs.hyprpaper`
* Enable bluetooth, networkmanager, and hyprland using their respective NixOS system options.

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
