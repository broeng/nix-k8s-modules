{
  pkgs,
}:
pkgs.stdenv.mkDerivation {
  pname = "openapi2jsonschema";
  version = "0.7.0";

  src = pkgs.fetchFromGitHub {
    owner = "yannh";
    repo = "kubeconform";
    rev = "e65429b1e5990dd019ebb7b5642dcd22a3e9cd13";
    sha256 = "sha256-FTUPARckpecz1V/Io4rY6SXhlih3VJr/rTGAiik4ALA=";
  };

  buildInputs = [
    (pkgs.python313.withPackages (f: [
      pkgs.python313.pkgs.pyyaml
    ]))
  ];

  phases = [
    "buildPhase"
    "fixupPhase"
  ];

  buildPhase = ''
    mkdir -p $out/bin
    cp $src/scripts/openapi2jsonschema.py $out/bin/openapi2jsonschema
    chmod +x $out/bin/openapi2jsonschema
  '';

}
