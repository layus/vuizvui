{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.vuizvui.user.profpatsch.programs.scanning;

in {
  options.vuizvui.user.profpatsch.programs.scanning = {
    enable = mkEnableOption "scanning &amp; simple-scan";

    remoteScanners = mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        See <literal>hardware.sane.extraBackends</literal>.
        Proxy, because I may want to change this option.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.simple-scan ];
    hardware.sane = {
      enable = true;
      netConf = cfg.remoteScanners;
    };
  };
}
