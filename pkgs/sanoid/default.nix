{ stdenv, lib, fetchgit
, perl, perlPackages
, pv, mbuffer, sudo, zfs, openssh, procps, coreutils
, lzop, xz, gzip, zstd, pigz, lz4
, 
}:

let
  mkReplacements = cmdMap:
    let pkg = c: cmdMap."${c}";
    in map (
        c: ''--replace "${c}" "${pkg c}/bin/${baseNameOf c}"''
      ) (builtins.attrNames cmdMap);
in stdenv.mkDerivation rec {
  name = "sanoid-${version}";
  version = "2.0.1";

  src = fetchgit {
    url = "https://github.com/jimsalterjrs/sanoid";
    rev = "refs/tags/v${version}";
    sha256 = "142s74srx7ayyrkm8c31lp81zwwjwj4z14xmvylc6qfk3vih9rwy";
  };

  phases = "unpackPhase patchPhase installPhase fixupPhase";

  patches = [ ./01-sanoid.patch ];

  installPhase = ''
    mkdir -p $out
    find . -maxdepth 1 -type f -exec cp {} $out \;
    mv $out/sanoid.conf $out/sanoid.conf.example
    mkdir -p $out/bin
    for file in syncoid sanoid findoid; do
      mv $out/$file $out/bin/$file
      substituteInPlace $out/bin/$file \
        --replace "#!/usr/bin/perl" "#!${perl}/bin/perl -I${perlPackages.ConfigIniFiles}/${perl.libPrefix}" \
        ${(builtins.concatStringsSep " \\" (mkReplacements {
          "/usr/bin/lz4"     = lz4;
          "/usr/bin/lzop"    = lzop;
          "/usr/bin/xz"      = xz;
          "/usr/bin/zstd"    = zstd;
          "/usr/bin/pigz"    = pigz;
          "/usr/bin/ssh"     = openssh;
          "/usr/bin/pv"      = pv;
          "/usr/bin/mbuffer" = mbuffer;
          "/usr/bin/sudo"    = sudo;
          "/sbin/zfs"        = zfs;
          "/sbin/zpool"      = zfs;
          "/bin/ls"          = coreutils;
          "/bin/ps"          = procps;
        }))}
      done
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
