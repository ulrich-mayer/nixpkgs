{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.sane.brscan3;

  netDeviceList = attrValues cfg.netDevices;

  etcFiles = pkgs.callPackage ./brscan3_etc_files.nix { netDevices = netDeviceList; };

  netDeviceOpts = { name, ... }: {

    options = {

      name = mkOption {
        type = types.str;
        description = lib.mdDoc ''
          The friendly name you give to the network device. If undefined,
          the name of attribute will be used.
        '';

        example = "office1";
      };

      model = mkOption {
        type = types.str;
        description = lib.mdDoc ''
          The model of the network device.
        '';

        example = "MFC-7440N";
      };

      ip = mkOption {
        type = with types; nullOr str;
        default = null;
        description = lib.mdDoc ''
          The ip address of the device. If undefined, you will have to
          provide a nodename.
        '';

        example = "192.168.1.2";
      };

      nodename = mkOption {
        type = with types; nullOr str;
        default = null;
        description = lib.mdDoc ''
          The node name of the device. If undefined, you will have to
          provide an ip.
        '';

        example = "BRW0080927AFBCE";
      };

    };


    config =
      { name = mkDefault name;
      };
  };

in

{
  options = {

    hardware.sane.brscan3.enable =
      mkEnableOption (lib.mdDoc "Brother's brscan3 scan backend") // {
      description = lib.mdDoc ''
        When enabled, will automatically register the "brscan3" sane
        backend and bring configuration files to their expected location.
      '';
    };

    hardware.sane.brscan3.netDevices = mkOption {
      default = {};
      example =
        { office1 = { model = "MFC-7440N"; ip = "192.168.1.2"; };
          office2 = { model = "MFC-7440N"; nodename = "BRW0080927AFBCE"; };
        };
      type = with types; attrsOf (submodule netDeviceOpts);
      description = lib.mdDoc ''
        The list of network devices that will be registered against the brscan3
        sane backend.
      '';
    };
  };

  config = mkIf (config.hardware.sane.enable && cfg.enable) {

    hardware.sane.extraBackends = [
      pkgs.brscan3
    ];

    environment.etc."opt/brother/scanner/brscan3" =
      { source = "${etcFiles}/etc/opt/brother/scanner/brscan3"; };

    assertions = [
      { assertion = all (x: !(null != x.ip && null != x.nodename)) netDeviceList;
        message = ''
          When describing a network device as part of the attribute list
          `hardware.sane.brscan3.netDevices`, only one of its `ip` or `nodename`
          attribute should be specified, not both!
        '';
      }
    ];

  };
}
