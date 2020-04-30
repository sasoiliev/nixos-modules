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
  version = "2.0.3";

  src = fetchgit {
    url = "https://github.com/jimsalterjrs/sanoid";
    rev = "refs/tags/v${version}";
    sha256 = "1wmymzqg503nmhw8hrblfs67is1l3ljbk2fjvrqwyb01b7mbn80x";
  };

  phases = "unpackPhase installPhase fixupPhase";

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out
    find . -maxdepth 1 -type f -exec cp {} $out \;
    mv $out/sanoid.conf $out/sanoid.conf.example
    mkdir -p $out/bin
    for file in syncoid sanoid findoid; do
      mv $out/$file $out/bin/$file.pl
      substituteInPlace $out/bin/$file.pl \
        --replace "#!/usr/bin/perl" "#!${perl}/bin/perl ${builtins.concatStringsSep " " (map mkPerlInclude [ "ConfigIniFiles" "CaptureTiny" ])}"
      makeWrapper $out/bin/$file.pl $out/bin/$file --prefix PATH : ${lib.makeBinPath [
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
    license = stdenv.lib.licenses.gpl3;
    maintainers = [];
    platforms = stdenv.lib.platforms.linux;
    homepage = https://github.com/jimsalterjrs/sanoid;
  };
}
