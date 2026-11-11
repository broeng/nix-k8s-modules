{ pkgs, lib, ... }:
lib.mkOption {
  type = lib.types.submodule [
    (
      { config, ... }:
      {
        options = {

          allowedManifestNames = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Names of secrets and other restricted types permitted to be loaded through Charts.";
          };

          restrictedManifestKinds = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "Secret" ];
            description = ''
              Manifest Kind types that should be restricted when
              originating from charts, explicitly allowed.
            '';
          };

          requireResourcesForApplication = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Require all containers for the application to have requests defined";
          };

          requireResourcesForDependencies = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Require all containers for dependencies of the application to have requests defined";
          };

        };
      }
    )
  ];
  default = { };
  description = "Validation related options";
}
