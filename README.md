NixOS Modules and Packages
==========================

This repository contains custom NixOS modules and packages
for my personal use.

For the pieces that makes sense I will consider opening
pull requests and contributing them upstream.

Usage
-----

Import the modules in your `configuration.nix`:

```nix
{ config, pkgs, ... }:

{
    imports = [
        ./hardware-configuration.nix
        (import (builtins.fetchGit {
            url = https://github.com/sasoiliev/nixos-modules.git;
            ref = "master";
            rev = "1b2417c6ae61c7174bddea1df92f48f080c9bcc5";
        }))
    ];

    # ...
}
```

Modules
-------

### Sanoid

[Sanoid][1] is a ZFS policy-driven snapshot management tool.

This module installs the Sanoid package and creates a systemd service and
timer for running the Sanoid tool on the specified schedule.

The supported options are:

| Option     | Description                                           | Type           | Default Value |
| :--------- | :---------------------------------------------------- | :------------- | :------------ |
| `enable`   | Whether to enable the Sanoid module                   | `bool`         | `false`       |
| `config`   | The contents of `sanoid.conf`                         | `nullOr lines` | `null`        |
| `schedule` | The systemd timer schedule (`OnCalendar` unit option) | `str`          | `"hourly"`    |

#### Usage

The module will create a pair of a systemd service running `sanoid` in cron mode and 
a timer to invoke the service at the specified `schedule`.

#### Example

For Sanoid configuration please refer to its documentation.

```nix
{
    # ...

    programs.sanoid = {
        enable = true;
        schedule = "hourly";
        config = ''
            [pool/dataset]
                use_template = production
                hourly = 12
                monthly = 1

            [template_production]
                frequently = 0
                hourly = 36
                daily = 30
                monthly = 3
                yearly = 0
                autosnap = yes
                autoprune = yes                
        '';
    };

    # ...
}
```

### Syncoid

Syncoid is a ZFS snapshot syncronization tool which is part of Sanoid.

This module allows you to configure regular ZFS dataset syncronization
via systemd services and timers.

The supported options are:

| Option            | Description                                     | Type             | Default Value |
| :---------------- | :---------------------------------------------- | :--------------- | :------------ |
| `enable`          | Whether to enable the Syncoid module            | `bool`           | `false`       |
| `defaultSshKey`   | The default SSH private key to use when syncing | `nullOr str`     | `null`        |
|                   | via SSH                                         |                  |               |
| `defaultSchedule` | The schedule to use for datasets with no        | `nullOr str`     | `null`        |
|                   | `schedule`                                      |                  |               |
|                   | option set                                      |                  |               |
| `datasets`        | A list of `dataset` objects (see below)         | `listOf dataset` | `[]`          |

A dataset accepts the following options:

| Option         | Description                                 | Type         | Default Value |
| :------------- | :------------------------------------------ | :----------- | :------------ |
| `source`       | The source dataset to sync from             | `str`        |               |
| `target`       | The target dataset to sync to               | `str`        |               |
| `sshKey`       | The SSH private key to use for this dataset | `nullOr str` | `null`        |
| `extraOptions` | Extra `syncoid` options to pass verbatim    | `str`        | `""`          |
| `recursive`    | Whether to sync child datasets              | `bool`       | `false`       |
| `skipParent`   | Whether to sync parent dataset              | `bool`       | `false`       |

#### Usage

The module will create a pair of a systemd service and a systemd timer for each
configured dataset. The service/timer will be named `syncoid-<source>.{service,timer}`.

#### Example

```nix
{
    # ...

    programs.syncoid = {
        enable = true;
        defaultSchedule = "hourly";
        defaultSshKey = "default-ssh-key";
        datasets = [
            { source = "pool/dataset1";
              target = "user@host:pool/backup/dataset1";
              schedule = "minutely";
              sshKey = "ssh-key";
              recursive = true;
              skipParent = false;
            }
            { source = "pool/dataset2";
              target = "user@host2:pool/dataset2";
            }
        ];
    };

    # ...
}
```

[1]: https://github.com/jimsalterjrs/sanoid/
