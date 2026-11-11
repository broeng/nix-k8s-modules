{
  pkgs,
  lib,
  yaml,
  ...
}:
rec {

  #
  # Unpack a helm chart
  #
  unpack =
    src:
    pkgs.stdenv.mkDerivation {
      name = "unpacked-chart";
      src = src;
      phases = [ "buildPhase" ];
      buildPhase = ''
        mkdir -p $out
        tar xvzf $src --strip-components=1 -C $out/
      '';
    };

  #
  # Parse a Helm chart
  #
  parse =
    chart:
    let
      ignoreList = [
        "Chart.yaml"
        "Chart.lock"
        "charts"
      ];
    in
    {
      chart = yaml.parseFile "${chart}/Chart.yaml";
      charts =
        if (lib.filesystem.pathIsDirectory "${chart}/charts") then
          (lib.mapAttrs (name: c: parse "${chart}/charts/${name}") (builtins.readDir "${chart}/charts"))
        else
          { };
      files = lib.filterAttrs (k: v: (builtins.elem k ignoreList) == false) (
        lib.mapAttrs (k: v: "${chart}/${k}") (builtins.readDir chart)
      );
    }
    // (lib.optionalAttrs (lib.filesystem.pathIsRegularFile "${chart}/Chart.lock") {
      lock = yaml.parseFile "${chart}/Chart.lock";
    });

  #
  # Write Helm Chart directory
  #
  write =
    chart:
    pkgs.stdenv.mkDerivation {
      name = "helm-chart-${chart.chart.name}";
      phases = [ "buildPhase" ];
      buildPhase = ''
        mkdir -p $out
        ln -s ${yaml.writeFile chart.chart} $out/Chart.yaml
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: src: ''
            ln -s ${src} $out/${name}
          '') chart.files
        )}
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: c: ''
            mkdir -p $out/charts
            ln -s ${write c} $out/charts/${name}
          '') chart.charts
        )}
      '';
    };

}
