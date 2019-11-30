{ config, lib, pkgs, ... }:

with lib;

let
  inherit (builtins) replaceStrings listToAttrs filter;
  inherit (strings) concatStringsSep;

  cfg = config.programs.syncoid;

  sanoid = (import ../../pkgs { }).sanoid;

  /* Create a SSH key option with a default value and a description.
   */
  mkSskKeyOption = default: description: mkOption {
    type = with types; nullOr str;
    default = default;
    description = description;
  };

  /* Create a schedule option with a default value and a description.
   */
  mkScheduleOption = default: description: mkOption {
    type = types.str;
    default = default;
    description = description;
  };
in
{
  ###### interface

  options.programs.syncoid = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable syncoid service.

        This will create a oneshot type systemd service invoking the
        syncoid tool with the specified sync targets and a corresponding
        systemd timer invoking the service according to the `schedule`
        option.
      '';
    };

    defaultSchedule = mkScheduleOption "hourly" ''
      A calendar event specifying the schedule to run sanoid in cron mode.

      The syntax of this option follows the Calendar Events section from 
      https://www.freedesktop.org/software/systemd/man/systemd.time.html.

      This schedule will be used for all datasets that don't have an
      explicitly specified `schedule` option.
    '';

    defaultSshKey = mkSskKeyOption null ''
      The path to the SSH private key file to use to connect.

      This key will be used for all datasets that don't have an
      explicitly specified `sshKey` option.
    '';

    datasets = mkOption {
      type = with types; listOf (submodule {
        options = {
          source = mkOption {
            type = str;
            description = "The source dataset to sync from.";
          };

          target = mkOption {
            type = str;
            description = "The target dataset to sync to.";
          };

          sshKey = mkSskKeyOption cfg.defaultSshKey "The path to the SSH private key file to use to connect.";

          schedule = mkScheduleOption cfg.defaultSchedule ''
            A calendar event specifying the schedule to run sanoid in cron mode.

            The syntax of this option follows the Calendar Events section from 
            https://www.freedesktop.org/software/systemd/man/systemd.time.html.
          '';

          extraOptions = mkOption {
            type = str;
            default = "";
            description = "Additional syncoid options that are passed verbatim to syncoid.";
          };

          recursive = mkOption {
            type = bool;
            default = false;
            description = "Whether to also sync child datasets (i.e. the `--recursive` option of syncoid).";
          };

          skipParent = mkOption {
            type = bool;
            default = false;
            description = "Whether to sync the parent dataset. Only meaningful if `recursive` is set to `true`.";
          };
        };
      });
    };
  };

  ###### implementation

  config = let
    /* Construct a valid systemd unit name from a syncoid dataset path.
       The path may point to a remote system (i.e. `user@host:path`) and will
       most probably contain slashes.
     */
    mkSystemdName = datasetPath: "syncoid-" + (
      replaceStrings ["@" ":" "/"] ["-at-" "--" "-"] datasetPath);

    /* Build an attribute set to be set to `systemd.services` or `systemd.timers`.

       The `mkUnitFunction` is a function that accepts a dataset and returns a
       systemd service/timer attribute set.
     */
    mkSystemdSet = mkUnitFunction: listToAttrs (map mkUnitFunction cfg.datasets);
  in mkIf cfg.enable {
    environment.systemPackages = [ sanoid ];

    systemd.services = let
      mkDatasetSyncService = dataset: {
        name = "${mkSystemdName dataset.source}";
        value = {
          description = "ZFS snapshot syncronization tool - ${dataset.source} -> ${dataset.target}";
          serviceConfig = let
            options = concatStringsSep " " (filter (x: x != "") [
              (optionalString (dataset.sshKey != null) "--sshkey=${dataset.sshKey}")
              (optionalString dataset.recursive "--recursive")
              (optionalString dataset.skipParent "--skip-parent")
              dataset.extraOptions
            ]);
          in {
            ExecStart = "${sanoid}/bin/syncoid ${options} ${dataset.source} ${dataset.target}";
            Type = "oneshot";
          };
        };
      };
    in mkSystemdSet mkDatasetSyncService;

    systemd.timers = let
      mkDatasetSyncTimer = dataset: {
        name = "${mkSystemdName dataset.source}";
        value = {
          description = "ZFS snapshot syncronization tool - ${dataset.source} -> ${dataset.target} (timer)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = dataset.schedule;
            Unit = "${mkSystemdName dataset.source}.service";
          };
        };
      };
    in mkSystemdSet mkDatasetSyncTimer;
  };
}
