{ stdenv, fetchFromGitHub, cmake, gnumake, libevent }:

stdenv.mkDerivation rec {
  pname = "libevhtp";
  version = "1.1.6";
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "ellzey";
    repo = "libevhtp";
    rev = "refs/tags/${version}";
    sha256 = "1k11r6gvndd1nzk6gs896hpfl5cnqir7jrl4jn7p5hsqpllzjjzs";
  };

  cmakeFlags = [ "-DEVHTP_DISABLE_SSL=ON" "-DEVHTP_BUILD_SHARED=OFF" ];

  buildInputs = [ libevent ];
  nativeBuildInputs = [ cmake gnumake ];
}
