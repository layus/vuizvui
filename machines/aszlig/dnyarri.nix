{ config, pkgs, utils, lib, ... }:

let
  mkDevice = category: num: uuid: {
    name = "dnyarri-${category}-crypt-${toString num}";
    value.device = "/dev/disk/by-uuid/${uuid}";
  };

  cryptDevices = {
    root = lib.imap (mkDevice "root") [
      "36260b1f-b403-477f-ab0e-505061c4e9d8"
      "3d5d71fa-ca2a-4144-a656-c68378cd2128"
    ];
    swap = lib.imap (mkDevice "swap") [
      "537b8b6b-0f03-4b2a-b0bb-6ebf18f7d9a0"
      "82d5a52d-1661-474d-859d-85c7d400d4b5"
    ];
  };

in {
  vuizvui.user.aszlig.profiles.workstation.enable = true;

  nix.settings.max-jobs = 24;

  # XXX: This machine has a pretty complicated audio setup, so until this works
  #      properly with PipeWire, let's stay with PulseAudio for now.
  services.pipewire.enable = lib.mkOverride 90 false;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  hardware.printers.ensureDefaultPrinter = "Bunti";
  hardware.printers.ensurePrinters = lib.singleton {
    name = "Bunti";
    deviceUri = "hp:/usb/HP_Color_LaserJet_2700?serial=00CNFNL14079";
    model = "HP/hp-color_laserjet_2700-ps.ppd.gz";
    location = "Living room";
    description = "Color laser printer";
    ppdOptions.PageSize = "A4";
  };

  boot = {
    loader.systemd-boot.enable = true;
    loader.grub.enable = false;
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages_latest;

    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" ];
      luks.devices =
        lib.listToAttrs (lib.concatLists (lib.attrValues cryptDevices));
    };
  };

  environment.systemPackages = [
    (pkgs.vuizvui.buildSandbox pkgs.gpodder {
      paths.required = [ "$HOME/gPodder" ];
      fullNixStore = true;
    })
    pkgs.paperwork
  ];

  services.fwupd.enable = true;
  services.fwupd.package = pkgs.fwupd.overrideAttrs (drv: {
    # This is to disable reports because they include identifying information.
    postInstall = (drv.postInstall or "") + ''
      sed -i -e '/ReportURI/d' "$out"/etc/fwupd/remotes.d/*.conf
    '';
  });

  hardware.cpu.amd.updateMicrocode = true;

  hardware.sane.enable = true;

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "dnyarri";
  networking.interfaces.enp1s0.useDHCP = true;

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-uuid/8C65-450D";
      fsType = "vfat";
    };
    "/" = {
      label = "dnyarri-root";
      fsType = "btrfs";
      options = [ "space_cache" "compress=zstd" "noatime" "discard=async" ];
    };
  };

  services.btrfs.autoScrub.enable = true;

  # The machine has two identical sound cards, so let's give them stable
  # identifiers because the device names assigned by the kernel are based on
  # initialisation order.
  services.udev.extraRules = let
    mkRule = id: path: ''
      ACTION=="add", DEVPATH=="${path}", SUBSYSTEM=="sound", ATTR{id}="${id}"
    '';
  in lib.concatStrings (lib.mapAttrsToList mkRule {
    lower = "/devices/pci0000:00/0000:00:03.1/0000:02:00.0/*/sound/card?*";
    upper = "/devices/pci0000:40/0000:40:01.1/0000:41:00.0/*/sound/card?*";
  });

  swapDevices = map ({ name, ... }: {
    device = "/dev/mapper/${name}";
  }) cryptDevices.swap;

  users.users.aszlig.extraGroups = [ "scanner" ];

  services.xserver.videoDrivers = [ "amdgpu" ];
  services.xserver.xrandrHeads = [ "DisplayPort-0" "DisplayPort-1" ];
  services.xserver.wacom.enable = true;

  vuizvui.user.aszlig.services.i3.workspaces."1" = {
    label = "XMPP";
    assign = lib.singleton { class = "^(?:Tkabber|Gajim|Psi)\$"; };
  };

  vuizvui.user.aszlig.services.i3.workspaces."3" = {
    label = "Browser";
    assign = lib.singleton { class = "^Firefox\$"; };
  };
}
