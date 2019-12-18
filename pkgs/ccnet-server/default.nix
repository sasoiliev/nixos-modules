{stdenv, fetchurl, which, autoreconfHook, pkgconfig, vala, python, libsearpc, libzdb, libuuid, libevent, sqlite, openssl}:

stdenv.mkDerivation rec {
  version = "7.1.1";
  pname = "ccnet-server";
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://github.com/haiwen/ccnet-server/archive/v${version}-server.tar.gz";
    sha256 = "1nnh854habkc6hp1vg4ld0mkcnsyym0j4a9p1md7ngcx0jw9chav";
  };

  nativeBuildInputs = [ pkgconfig which autoreconfHook vala python ];
  propagatedBuildInputs = [ libsearpc libzdb libuuid libevent sqlite openssl ];

  configureFlags = [ "--enable-server" ];

  meta = with stdenv.lib; {
    homepage = https://github.com/haiwen/ccnet-server;
    description = "A framework for writing networked applications in C";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
