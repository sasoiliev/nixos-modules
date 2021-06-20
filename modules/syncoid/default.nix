{ config, lib, pkgs, ... }:

with lib;

let
  inherit (builtins) replaceStrings listToAttrs filter foldl' hasAttr;
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
    type = types.nullOr types.str;
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

    defaultSchedule = mkScheduleOption null ''
      A calendar event specifying the schedule to run sanoid in cron mode
      or <literal>null</literal> to disable periodic sync.

      The syntax of this option follows the Calendar Events section from
      https://www.freedesktop.org/software/systemd/man/systemd.time.html

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

          unitName = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              The systemd service unit name.

              `"<source>--<target>"` will be used if left `null`, where
              `<source>` and `<target>` will equal to the respective option
              values with "@" replaced with "-at-" and "/" and ":" replaced
              with "-".
            '';
          };

          systemdTarget = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              A systemd target name to include the service in.

              This allows for grouping datasets together in a target that can
              be then invoked with a single command.
            '';
          };

          sshKey = mkSskKeyOption cfg.defaultSshKey "The path to the SSH private key file to use to connect.";

          schedule = mkScheduleOption cfg.defaultSchedule ''
            A calendar event specifying the schedule to run sanoid in cron mode
            or <literal>null</literal> to disable periodic sync.

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

          noSyncSnapshot = mkOption {
            type = bool;
            default = false;
            description = "Whether to create a new snapshot or just to sync the existing ones (i.e. `--no-sync-snap` option of syncoid).";
          };

          createBookmark = mkOption {
            type = bool;
            default = false;
            description = "Whether to create a ZFS bookmark on the source. Only works if `noSyncSnapshot == true`.";
          };

          restartOnFailure = mkOption {
            type = bool;
            default = false;
            description = "Whether to restart the service on failure.";
          };

          restartSec = mkOption {
            type = int;
            default = 30;
            description = ''
              How long to wait (in seconds) before restarting a failed service run.
              Only applicable if `restartOnFailure == true`.
            '';
          };
        };
      });
    };
  };

  ###### implementation

  config = let
    /* Escapes a syncoid dataset path.

       The path may point to a remote system (i.e. `user@host:path`) and will
       most probably contain slashes.
     */
    escapePath = datasetPath: replaceStrings ["@" ":" "/"] ["-at-" "-" "-"] datasetPath;

    /* Build an attribute set to be set to `systemd.services` or `systemd.timers`.

       The `mkUnitFunction` is a function that accepts a dataset and returns a
       systemd service/timer attribute set.
     */
    mkSystemdSet = datasets: mkUnitFunction: listToAttrs (map mkUnitFunction datasets);

    unitName = dataset: "syncoid-" + (
      if dataset.unitName != null
        then dataset.unitName
        else "${escapePath dataset.source}--${escapePath dataset.target}"
    );
  in mkIf cfg.enable {
    environment.systemPackages = [ sanoid ];

    systemd.services = let
      mkDatasetSyncService = dataset: {
        name = unitName dataset;
        value = {
          description = "ZFS snapshot syncronization tool - ${dataset.source} -> ${dataset.target}";
          serviceConfig = let
            options = concatStringsSep " " (filter (x: x != "") [
              (optionalString (dataset.sshKey != null) "--sshkey=${dataset.sshKey}")
              (optionalString dataset.recursive "--recursive")
              (optionalString dataset.skipParent "--skip-parent")
              (optionalString dataset.noSyncSnapshot "--no-sync-snap")
              (optionalString (dataset.noSyncSnapshot && dataset.createBookmark) "--create-bookmark")
              dataset.extraOptions
            ]);
          in {
            ExecStart = "${sanoid}/bin/syncoid ${options} ${dataset.source} ${dataset.target}";
            Type = "oneshot";
          } // (optionalAttrs dataset.restartOnFailure
          { Restart = "on-failure";
            RestartSec = dataset.restartSec;
          });
        };
      };
    in mkSystemdSet cfg.datasets mkDatasetSyncService;

    systemd.timers = let
      mkDatasetSyncTimer = dataset: {
        name = unitName dataset;
        value = {
          description = "ZFS snapshot syncronization tool - ${dataset.source} -> ${dataset.target} (timer)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = dataset.schedule;
            Unit = "${unitName dataset}.service";
          };
        };
      };
    in mkSystemdSet (filter (d: d.schedule != null) cfg.datasets) mkDatasetSyncTimer;

    systemd.targets = let
      mkSyncTargets = datasets: let
        datasetUnit = x: "${unitName x}.service";
        addDataset = xs: x: let
          unitSingleton = [ (datasetUnit x) ];
          targetUnits = if (hasAttr x.systemdTarget xs)
            then xs."${x.systemdTarget}".wants ++ unitSingleton
            else unitSingleton;
        in xs // { "${x.systemdTarget}".wants = targetUnits; };
      in foldl' addDataset {} datasets;
    in mkSyncTargets (filter (x: x.systemdTarget != null) cfg.datasets);
  };
}
