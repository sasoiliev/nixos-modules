{ system ? builtins.currentSystem }:

let
  pkgs = import <nixpkgs> { inherit system; };

  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = {
    sanoid = callPackage ./sanoid { makeWrapper = pkgs.makeWrapper; }; 
    zpool-influxdb = callPackage ./zpool-influxdb { };
  };
in
self

