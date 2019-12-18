{ config, lib, pkgs, ... }:

{
  imports = [
    (import ./modules/sanoid)
    (import ./modules/syncoid)
    (import ./modules/seafile-server)
  ];
}
