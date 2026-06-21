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
            jq
            bc
            brightnessctl
            libnotify
            psmisc
            procps
            xdg-utils
            grim
            ffmpeg
            wf-recorder
            wl-clipboard
            cliphist
            hyprlock
            curl
            zenity
            hyprpaper
          ];

          # Automatically link the configuration files to ~/.config
          xdg.configFile."quickshell".source = ./.config/quickshell;
          xdg.configFile."matugen".source = ./.config/matugen;
        };
      };
  };
}
