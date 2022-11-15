{ stdenv, lib, fetchgit, makeWrapper
, perl, perlPackages
, pv, mbuffer, sudo, zfs, openssh, procps, coreutils
, lzop, xz, gzip, zstd, pigz, lz4
}:

let
  mkReplacements = cmdMap:
    let pkg = c: cmdMap."${c}";
    in map (
        c: ''--replace "${c}" "${pkg c}/bin/${baseNameOf c}"''
      ) (builtins.attrNames cmdMap);
  replacementMap = {
    "sanoid" = {
      "/bin/ps"     = procps;
      "/sbin/zfs"   = zfs;
      "/sbin/zpool" = zfs;
    };
    "findoid" = {
      "/sbin/zfs" = zfs;
    };
  };
  mkPerlInclude = perlModule: "-I${perlPackages."${perlModule}"}/${perl.libPrefix}";
in stdenv.mkDerivation rec {
  name = "sanoid-${version}";
  version = "";

  src = fetchgit {
    url = "https://github.com/sasoiliev/sanoid";
    rev = "d32556ca90baaf7f549bd9831964af1c33f90131";
    sha256 = "0if9nm97k1lr9hh9rbrb25ji1cq72dxqnvlcmli3wdypvi9i6d35";
  };

  phases = "unpackPhase installPhase fixupPhase";

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out
    find . -maxdepth 1 -type f -exec cp {} $out \;
    mv $out/sanoid.conf $out/sanoid.conf.example
    mkdir -p $out/bin
    # Workaround for an issue introduced by https://github.com/NixOS/nixpkgs/pull/179603 -
    # the file variable is clobbered in substituteInPlace.
    for _file in syncoid sanoid findoid; do
      mv $out/$_file $out/bin/$_file.pl
      substituteInPlace $out/bin/$_file.pl \
        --replace "#!/usr/bin/perl" "#!${perl}/bin/perl ${builtins.concatStringsSep " " (map mkPerlInclude [ "ConfigIniFiles" "CaptureTiny" ])}"
      makeWrapper $out/bin/$_file.pl $out/bin/$_file --prefix PATH : ${lib.makeBinPath [
        lzop xz gzip zstd pigz lz4 # compression tools
        openssh
        pv mbuffer sudo zfs procps coreutils
      ] }}
    done
    substituteInPlace $out/bin/sanoid.pl \
      ${(builtins.concatStringsSep " \\" (mkReplacements replacementMap."sanoid"))}
    substituteInPlace $out/bin/findoid.pl \
      ${(builtins.concatStringsSep " \\" (mkReplacements replacementMap."findoid"))}
  '';

  meta = {
    inherit version;
    description = ''Policy-driven ZFS snapshot management and replication tools.'';
    license = lib.licenses.gpl3;
    maintainers = [];
    platforms = lib.platforms.linux;
    homepage = https://github.com/jimsalterjrs/sanoid;
  };
}
