{
  flakeConfig,
  pkgs,
  chart,
  k8slib,
  lib,
  targetNamespace,
  ...
}:
lib.types.submodule (
  { config, ... }:
  {
    options = {

      subcharts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Subcharts with relevant values files.";
      };

      variables = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Variables to serialize to yaml and store with values for reference";
      };

      renderedDefaultValues = lib.mkOption {
        type = lib.types.path;
        default = k8slib.helm.buildValuesFile {
          name = chart.name;
          chart = chart.chart;
          namespace = targetNamespace;
        };
        description = "Path to a generated default values file (show values)";
      };

      renderedSubChartValues = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = builtins.listToAttrs (
          lib.map (
            sc:
            lib.nameValuePair sc (
              k8slib.helm.buildValuesFile {
                name = sc;
                chart = "${chart.chart}/charts/${sc}";
                namespace = targetNamespace;
              }
            )
          ) config.subcharts
        );
        description = "Path to a generated default values for sub charts (show values)";
      };

    };
  }
)
