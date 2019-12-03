{ stdenv, fetchFromGitHub, zfs, cmake, gnumake }:

stdenv.mkDerivation {
  pname = "zpool-influxdb";
  version = "0.1";

  src = fetchFromGitHub {
    owner = "richardelling";
    repo = "zpool_influxdb";
    rev = "d3274efaafa3a9d0a2762a0f331193cb3747c0cb";
    sha256 = "150vnrcsd5bwa7r4x72w7xfafrkf6vzbxgld2ph1g1mna73615dg";
  };

  nativeBuildInputs = [ cmake gnumake ];
  buildInputs = [ zfs ];

  preConfigure = ''
    substituteInPlace CMakeLists.txt --replace "$""{INSTALL_DIR}/include/libspl" ${zfs.dev}/include/libspl \
      --replace "$""{INSTALL_DIR}/include/libzfs" ${zfs.dev}/include/libzfs \
      --replace "$""{INSTALL_DIR}/lib" ${zfs.lib} \
      --replace "DESTINATION ""$""{INSTALL_DIR}/bin" "DESTINATION $out/bin"
    cat CMakeLists.txt
  '';
}