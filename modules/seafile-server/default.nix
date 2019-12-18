{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.seafile;
  seafile-server = (import ../../pkgs { }).seafile-server;
in {
  options.services.seafile = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the seafile service.
      '';
    };
  };

  ###### implementation

  config = mkIf cfg.enable {
    environment.systemPackages = [ seafile-server ];
  };
}