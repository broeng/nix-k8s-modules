{
  flakeConfig,
  pkgs,
  lib,
  k8slib,
  kubelib,
  targetNamespace ? null,
  createNamespace ? false,
  namespaceLabels ? { },
  ...
}:
lib.mkOption {
  type = lib.types.submodule [
    (
      { config, ... }:
      {
        options = {

          charts = lib.mkOption {
            type = lib.types.listOf (
              import ./charts.nix {
                inherit
                  pkgs
                  lib
                  k8slib
                  kubelib
                  targetNamespace
                  flakeConfig
                  ;
              }
            );
            default = [ ];
            description = "Charts for this application";
          };

          chartResources = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = lib.filter config.filterChartResources (
              lib.flatten (lib.map (chart: chart.chartResources) config.charts)
            );
            description = "Rendered list of resources from chart";
            readOnly = true;
          };

          filterChartResources = lib.mkOption {
            type = lib.types.functionTo lib.types.bool;
            default = r: true;
            description = "A filter function for the resources loaded from Helm charts";
          };

          manifests = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
            description = "Manifests for this application";
          };

          transformResources = lib.mkOption {
            type = lib.types.functionTo lib.types.attrs;
            default = r: r;
            description = "A transformation function to apply to all resources";
          };

          containers = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default =
              let
                containerResources = [
                  { kind = "Deployment"; }
                  { kind = "StatefulSet"; }
                  { kind = "DaemonSet"; }
                ];
                manifests = lib.filter (
                  m: k8slib.attrs.attrSetContainsAnyOf m containerResources
                ) config.generatedResources;
              in
              lib.flatten (lib.map (m: m.spec.template.spec.containers) manifests);
            description = "All container definitions found in this resource";
          };

          generatedResources = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = lib.map config.transformResources (
              (lib.optional createNamespace (
                k8slib.resources.namespace {
                  name = targetNamespace;
                  labels = namespaceLabels;
                }
              ))
              ++ config.manifests
              ++ config.chartResources
            );
            description = "Rendered list of resources";
            readOnly = true;
          };

          yamlOut = lib.mkOption {
            type = lib.types.path;
            default = pkgs.writeText "resources.yaml" (
              lib.concatStringsSep "---\n" (
                lib.map (r: builtins.readFile (kubelib.toYAMLFile r)) config.generatedResources
              )
            );
            description = "Generated yaml for resources";
          };

        };
      }
    )
  ];
  default = { };
  description = "Various resources for an application.";
}
