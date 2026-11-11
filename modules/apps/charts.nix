{
  flakeConfig,
  pkgs,
  k8slib,
  lib,
  kubelib,
  targetNamespace,
  ...
}:
lib.types.submodule (
  { config, ... }:
  {
    options = {

      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the Helm chart";
      };

      chart = lib.mkOption {
        type = lib.types.path;
        description = "Path to a downloaded Helm chart";
      };

      values = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Values for the evaluation of the Helm chart";
      };

      includeCRDs = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include CRDs with deployment?";
      };

      renderedChart = lib.mkOption {
        type = lib.types.path;
        default = kubelib.buildHelmChart {
          name = config.name;
          chart = config.chart;
          namespace = targetNamespace;
          values = config.values;
          includeCRDs = config.includeCRDs;
          kubeVersion = flakeConfig.k8s.environment.kubeVersion;
        };
        description = "Path to built version of the Helm chart";
      };

      parsedChart = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = k8slib.yaml.parseMultiYamlFile config.renderedChart;
        description = "Rendered list of resources from chart, unfiltered.";
        readOnly = true;
      };

      chartResources = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = lib.filter (
          m:
          builtins.all (r: r == false) (
            lib.map (dr: k8slib.attrs.attrSetContains m dr) (lib.filter (dr: dr != { }) config.discardResources)
          )
        ) config.parsedChart;
        description = "Rendered list of resources from chart";
        readOnly = true;
      };

      discardResources = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Names of resources to drop from deployment";
      };

      valuesTemplates = lib.mkOption {
        type = import ./values.nix {
          chart = config;
          inherit
            pkgs
            lib
            k8slib
            kubelib
            targetNamespace
            flakeConfig
            ;
        };
        default = { };
        description = "Values templates files for this chart";
      };
    };
  }
)
