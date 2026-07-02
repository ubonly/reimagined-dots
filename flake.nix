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
            ]))
            kdePackages.kdeconnect-kde
            jq
            bc
            brightnessctl
            libnotify
            psmisc
            procps
            xdg-utils
            cmake
            ninja
            pkg-config
            gcc
            qt6.qtbase
            libsecret
            grim
            ffmpeg
            wf-recorder
            wl-clipboard
            cliphist
            hyprlock
            curl
            zenity
            hyprpaper
            nerd-fonts.jetbrains-mono
          ];

          # Automatically link the configuration files to ~/.config
          xdg.configFile."quickshell".source = ./.config/quickshell;
          xdg.configFile."matugen".source = ./.config/matugen;
        };
      };
  };
}
