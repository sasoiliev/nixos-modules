{ stdenv, makeWrapper, fetchFromGitHub
, autoreconfHook, pkgconfig
, ccnet-server, libsearpc
, vala, libuuid, glib, libevent, libevhtp
, sqlite, mariadb, postgresql
, which, curl, python2, fuse
, libarchive, xz, bzip2
}:

stdenv.mkDerivation rec {
  pname = "seafile-server";
  version = "v7.1.1";
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "haiwen";
    repo = "seafile-server";
    rev = "refs/tags/${version}-server";
    sha256 = "0m3mva02f2vyxkm25pc4p0i9v0rgcn08wgh2azcalqlhn2s7kgq8";
  };

  propagatedBuildInputs = [ ccnet-server ];

  buildInputs = [
    libsearpc libevent libuuid sqlite mariadb postgresql glib
    curl python2 fuse libarchive libevhtp xz bzip2
    makeWrapper
  ];
  nativeBuildInputs = [ pkgconfig autoreconfHook vala which ];

  wrapperPath = stdenv.lib.makeBinPath [
    ccnet-server
    python2
  ];

  fixupPhase = ''
    wrapProgram $out/bin/seafile-admin --prefix PATH : ${wrapperPath}
  '';
}
