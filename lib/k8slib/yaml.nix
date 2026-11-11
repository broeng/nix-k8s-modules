{ pkgs, lib, ... }:
rec {

  yaml2json =
    opts: f:
    pkgs.stdenv.mkDerivation {
      name = "yaml.readFile";
      phases = [ "buildPhase" ];
      buildPhase = "${pkgs.yq}/bin/yq -M ${opts} . ${f} > $out";
    };

  parseFile =
    f:
    lib.pipe f [
      (yaml2json "")
      builtins.readFile
      builtins.fromJSON
    ];

  parseMultiYamlFile =
    f:
    lib.pipe f [
      (yaml2json "-s")
      builtins.readFile
      builtins.fromJSON
      (builtins.filter (v: v != null))
    ];

  writeFile =
    attrs:
    pkgs.stdenv.mkDerivation {
      jsonText = builtins.toJSON attrs;
      passAsFile = "jsonText";
      name = "yaml.writeFile";
      phases = [ "buildPhase" ];
      buildPhase = "${pkgs.yq-go}/bin/yq -P -M $jsonTextPath > $out";
    };

}
