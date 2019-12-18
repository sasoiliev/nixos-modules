{ system ? builtins.currentSystem }:

let
  pkgs = import <nixpkgs> { inherit system; };

  callPackage = pkgs.lib.callPackageWith (pkgs // pkgs.xlibs // self);

  self = rec {
    sanoid = callPackage ./sanoid { makeWrapper = pkgs.makeWrapper; }; 
    zpool-influxdb = callPackage ./zpool-influxdb { };
    libevhtp = callPackage ./libevhtp { };
    libsearpc = callPackage ./libsearpc { };
    ccnet-server = callPackage ./ccnet-server { inherit libsearpc; };
    seafile-server = callPackage ./seafile-server {
      inherit libsearpc libevhtp;
      makeWrapper = pkgs.makeWrapper;
    };
  };
in
self

