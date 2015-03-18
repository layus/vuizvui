{ config, pkgs, lib, ... }:

let
  cfg = config.vuizvui.user.aszlig.profiles.base;

in {
  options.vuizvui.user.aszlig.profiles.base = {
    enable = lib.mkEnableOption "Base profile for aszlig";
  };

  config = lib.mkIf cfg.enable {
    nix = {
      package = pkgs.nixUnstable;
      useChroot = true;
      readOnlyStore = true;
      extraOptions = ''
        build-cores = 0
        auto-optimise-store = true
      '';
    };

    boot.loader.grub = {
      enable = true;
      version = 2;
    };

    hardware.cpu.intel.updateMicrocode = true;

    users.defaultUserShell = "/var/run/current-system/sw/bin/zsh";

    networking.wireless.enable = false;
    networking.firewall.enable = false;
    networking.useNetworkd = true;

    i18n.consoleKeyMap = "dvorak";

    programs.ssh.startAgent = false;
    programs.ssh.extraConfig = ''
      ServerAliveInterval 60
    '';

    services.nixosManual.showManual = false;

    environment.systemPackages = with pkgs; [
      binutils
      cacert
      file
      htop
      iotop
      psmisc
      unrar
      unzip
      vim
      vlock
      wget
      xz
      zsh
    ];

    nixpkgs.config = import ../../../../nixpkgs/config.nix;
    system.fsPackages = with pkgs; [ sshfsFuse ];
    time.timeZone = "Europe/Berlin";
  };
}