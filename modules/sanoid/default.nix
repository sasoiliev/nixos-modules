{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.sanoid;
  sanoid = (import ../../pkgs { }).sanoid;
in
{
  ###### interface

  options.programs.sanoid = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable sanoid service.

        This will create a oneshot type `sanoid` systemd service that will
        run the sanoid tool in cron mode and a systemd timer that will
        invoke the service on the specified calendar event.
      '';
    };
    config = mkOption {
      type = with types; nullOr lines;
      default = null;
      description = ''
        Sanoid configuration.
      '';
    };
    schedule = mkOption {
      type = types.str;
      default = "hourly";
      description = ''
        A calendar event specifying the schedule to run sanoid in cron mode.

        The syntax of this option follows the Calendar Events section from 
        https://www.freedesktop.org/software/systemd/man/systemd.time.html
      '';
    };
  };

  ###### implementation

  config = mkIf cfg.enable {
    environment.etc."sanoid/sanoid.conf".text = mkIf (!isNull cfg.config) cfg.config;
    environment.etc."sanoid/sanoid.defaults.conf".source = "${sanoid}/sanoid.defaults.conf";
    environment.systemPackages = [ sanoid ];
    systemd.services.sanoid = {
      description = "ZFS snapshot policy management tool";
      serviceConfig = {
        ExecStart = "${sanoid}/bin/sanoid --cron --verbose";
        Type = "oneshot";
      };
    };
    systemd.timers.sanoid = {
      description = "Timer for sanoid";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Unit = "sanoid.service";
      };
    };
  };
}