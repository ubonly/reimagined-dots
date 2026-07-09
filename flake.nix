{
  description = "A ChromeOS-inspired Quickshell configuration for Hyprland";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # Home Manager Module for easy, declarative installation
    homeManagerModules.default = { config, lib, pkgs, ... }:
      let
        cfg = config.programs.quickshell-reimagined;
      in
      {
        options.programs.quickshell-reimagined = {
          enable = lib.mkEnableOption "ChromeOS-like Quickshell dock and panel";
        };

        config = lib.mkIf cfg.enable {
          home.packages = with pkgs; [
            quickshell
            matugen
            (python3.withPackages (ps: [
              ps.dbus-python
              ps.pygobject3
              ps.pillow
              ps.requests
            ]))
            kdePackages.kdeconnect-kde
            hyprland
            hyprlock
            hyprpaper
            hyprpolkitagent
            hyprshot
            networkmanager
            bluez
            wireplumber
            blueman
            power-profiles-daemon
            jq
            bc
            brightnessctl
            libnotify
            psmisc
            procps
            xdg-utils
            xdg-user-dirs
            xdg-desktop-portal
            xdg-desktop-portal-hyprland
            dbus
            fontconfig
            glib
            polkit
            cmake
            ninja
            pkg-config
            gcc
            qt6.qtbase
            qt6.qtdeclarative
            qt6.qt5compat
            qt6.qtwayland
            qt6.qtsvg
            wayland
            wayland-protocols
            libxkbcommon
            linux-pam
            pipewire
            libsecret
            grim
            slurp
            ffmpeg
            wf-recorder
            wl-clipboard
            cliphist
            curl
            zenity
            kitty
            fish
            starship
            playerctl
            nerd-fonts.jetbrains-mono
          ];

          # Automatically link the configuration files to ~/.config
          xdg.configFile."quickshell".source = ./.config/quickshell;
          xdg.configFile."matugen".source = ./.config/matugen;
          home.file.".local/share/fonts/ReimaginedSans".source = ./.config/quickshell/sans_font;
          fonts.fontconfig.enable = true;
        };
      };
  };
}
