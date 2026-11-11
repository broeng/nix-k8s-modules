{
  flakeConfig,
  pkgs,
  k8slib,
  lib,
  kubelib,
  ...
}:
lib.types.submodule [
  (
    { name, config, ... }:
    {
      options = {

        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable ArgoCD application manifest generation";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Name of this application";
        };

        namespace = lib.mkOption {
          type = lib.types.submodule {
            options = {

              name = lib.mkOption {
                type = lib.types.str;
                description = "Namespace for this application";
              };

              create = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Automatically create the namespace for this application?";
              };

              labels = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
                description = "Labels to apply to namespace resource";
              };

            };
          };
          description = "Namespace config for this application";
        };

        variables = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Convience option to store commonly used variables";
        };

        validation = import ./validation.nix {
          inherit pkgs lib;
        };

        deployment = import ./deployment.nix {
          inherit pkgs lib;
        };

        dependencies = import ./resources.nix {
          inherit
            flakeConfig
            pkgs
            lib
            kubelib
            k8slib
            ;
        };

        application = import ./resources.nix {
          inherit
            flakeConfig
            pkgs
            lib
            kubelib
            k8slib
            ;
          targetNamespace = config.namespace.name;
          createNamespace = config.namespace.create;
          namespaceLabels = config.namespace.labels;
        };

        applicationResources = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = config.dependencies.generatedResources ++ config.application.generatedResources;
          description = "Complete list of resources for this application";
          readOnly = true;
        };

        configurationResources = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = lib.filter (
            m:
            k8slib.attrs.attrSetContainsAnyOf m [
              { kind = "ConfigMap"; }
            ]
          ) config.applicationResources;
          description = "Configuration related resources for this application";
        };

        configHash = lib.mkOption {
          type = lib.types.str;
          default = k8slib.hash.unsafeSha256Hash (kubelib.toYAMLStreamFile config.configurationResources);
          description = "Hash of configuration related resources";
        };

        generatedResources = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default =
            if (config.deployment.embedConfigurationHash) then
              (lib.map (
                m:
                lib.recursiveUpdate
                  (
                    if (lib.attrByPath [ "spec" "template" ] { } m) != { } then
                      lib.recursiveUpdate m {
                        spec.template.metadata.annotations."${name}.${flakeConfig.k8s.annotationDomain}/config-hash" =
                          config.configHash;
                      }
                    else
                      m
                  )
                  {
                    metadata.annotations."${name}.${flakeConfig.k8s.annotationDomain}/config-hash" = config.configHash;
                  }
              ) config.applicationResources)
            else
              config.applicationResources;
          description = "Complete list of resources for this application";
          readOnly = true;
        };

        out = lib.mkOption {
          type = lib.types.path;
          default = kubelib.toYAMLStreamFile config.generatedResources;
          description = "Generated yaml with all resources";
        };

      };
    }
  )
]
