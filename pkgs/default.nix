{ system ? builtins.currentSystem }:

let
  pkgs = import <nixpkgs> { inherit system; };

  callPackage = pkgs.lib.callPackageWith (pkgs // pkgs.xlibs // self);

  self = {
    sanoid = callPackage ./sanoid { makeWrapper = pkgs.makeWrapper; }; 
    zpool-influxdb = callPackage ./zpool-influxdb { };
  };
in
self

