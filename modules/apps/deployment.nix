{ pkgs, lib, ... }:
lib.mkOption {
  type = lib.types.submodule [
    (
      { config, ... }:
      {
        options = {

          embedConfigurationHash = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Embed an annotation containing a hash of the application configuration";
          };

          ignoreDifferences = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
            description = "Differences to ignore in mutating manifests";
          };

          syncPolicy = lib.mkOption {
            type = lib.types.submodule {
              options = {

                respectIgnoreDifferences = lib.mkOption {
                  type = lib.types.bool;
                  default = config.ignoreDifferences != [ ];
                  description = "Respect ignored differences when syncing";
                };

                useServerSideApply = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Use kubectl's Server Side Apply. Should eventually be default.";
                };

              };
            };
            default = { };
            description = "Sync policy controls for application";
          };

        };
      }
    )
  ];
  default = { };
  description = "Application specific configuration for argo deployment";
}
