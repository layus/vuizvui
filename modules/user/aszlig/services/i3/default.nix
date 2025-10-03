{ pkgs, lib, config, ... }:

with lib;

let
  cfg = config.vuizvui.user.aszlig.services.i3;
  inherit (config.services.xserver) xrandrHeads;

  # The symbols if you press shift and a number key.
  wsNumberSymbols = [
    "exclam" "at" "numbersign" "dollar" "percent"
    "asciicircum" "ampersand" "asterisk" "parenleft" "parenright"
  ];

  wsCount = length wsNumberSymbols;

  headCount = length xrandrHeads;
  wsPerHead = wsCount / headCount;
  excessWs = wsCount - (headCount * wsPerHead);
  headModifier = if cfg.reverseHeads then reverseList else id;
  getHeadAt = x: (elemAt (headModifier xrandrHeads) x).output;

  mkSwitchTo = number: "$mod+${if number == 10 then "0" else toString number}";

  mkDefaultWorkspace = number: numberSymbol: {
    name = toString number;
    value = {
      label = mkDefault null;
      labelPrefix = mkDefault "${toString number}: ";
      keys.switchTo = mkDefault (mkSwitchTo number);
      keys.moveTo = mkDefault "$mod+Shift+${numberSymbol}";
      head = if headCount == 0 then mkDefault null
             else mkDefault (getHeadAt ((number - (excessWs + 1)) / wsPerHead));
    };
  };

  wsCfgList = mapAttrsToList (_: getAttr "config") cfg.workspaces;
  wsConfig = concatStrings wsCfgList;
  defaultWorkspaces = listToAttrs (imap mkDefaultWorkspace wsNumberSymbols);

  conky = import ./conky.nix {
    inherit pkgs lib;
    timeout = cfg.networkTimeout;
  };

  mkBar = output: statusCmd: singleton ''
    bar {
      ${optionalString (output != null) "output ${output}"}
      ${optionalString (statusCmd != null) "status_command ${statusCmd}"}
      colors {
        focused_workspace  #5c5cff #e5e5e5
        active_workspace   #ffffff #0000ee
        inactive_workspace #00cdcd #0000ee
        urgent_workspace   #ffff00 #cd0000
      }
    }
  '';

  barConfig = let
    barHeads = map (h: h.output) (headModifier xrandrHeads);
    bars = if headCount == 0 then mkBar null conky.single
      else if headCount == 1 then mkBar (head barHeads) conky.single
      else let inner = take (length barHeads - 2) (tail barHeads);
           in mkBar (head barHeads) conky.left
           ++ map (flip mkBar null) inner
           ++ mkBar (last barHeads) conky.right;
  in concatStrings (headModifier bars);

in
{
  options.vuizvui.user.aszlig.services.i3 = {
    enable = mkEnableOption "i3";

    workspaces = mkOption {
      type = types.attrsOf (types.submodule (import ./workspace.nix));
      description = ''
        Workspace to monitor assignment.

        Workspaces are by default assigned starting from the leftmost monitor
        being workspace 1 and the rightmost monitor being workspace 10. The
        workspaces are divided by the number of available heads, so if you have
        a dual head system, you'll end up having workspace 1 to 5 on the left
        monitor and 6 to 10 on the right.
      '';
    };

    reverseHeads = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Reverse the order of the heads, so if enabled and you have two heads,
        you'll end up having workspaces 1 to 5 on the right head and 6 to 10 on
        the left head.
      '';
    };

    networkTimeout = mkOption {
      type = types.int;
      default = 300;
      description = ''
        Maximum number of seconds to wait for network device detection.
      '';
    };
  };

  config = mkIf cfg.enable {
    vuizvui.user.aszlig.services.i3.workspaces = defaultWorkspaces;

    services.xserver.windowManager = {
      i3.enable = true;
      i3.configFile = pkgs.replaceVarsWith {
        src =./i3.conf;

        replacements = {
          inherit (pkgs) dmenu xterm;
          inherit (pkgs.xorg) xsetroot;
          inherit wsConfig barConfig;

          # XXX: Decouple this by making the i3 bindsym directives available to
          #      the NixOS module system.
          flameshot = config.vuizvui.user.aszlig.programs.flameshot.package;

          lockall = pkgs.writeScript "lockvt.sh" ''
            #!${pkgs.stdenv.shell}
            "${pkgs.socat}/bin/socat" - UNIX-CONNECT:/run/console-lock.sock \
              < /dev/null
          '';
        };

        postCheck = ''
          ${pkgs.i3}/bin/i3 -c "$target" -C
        '';
      };
    };
  };
}
