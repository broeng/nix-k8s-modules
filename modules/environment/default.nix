{
  config,
  pkgs,
  lib,
  k8slib,
  kubelib,
  ...
}:
{

  options = {

    k8s.environment = lib.mkOption {
      type = lib.types.submodule [
        (
          { name, config, ... }:
          {
            options = {

              name = lib.mkOption {
                type = lib.types.str;
                description = "Name of environment. Should match folder it's located in.";
              };

              kubeVersion = lib.mkOption {
                type = lib.types.str;
                description = "Version of kubernetes running";
              };

              domainTLD = lib.mkOption {
                type = lib.types.str;
                description = "TLD for domains in this environment";
              };

              applications = lib.mkOption {
                type = lib.types.listOf (
                  import ../apps/application.nix {
                    inherit
                      pkgs
                      lib
                      k8slib
                      kubelib
                      ;
                    flakeConfig = config;
                  }
                );
                description = "List of applications for this environment";
              };

              variables = lib.mkOption {
                type = lib.types.attrs;
                default = { };
                description = "Convience option to store commonly used variables";
              };
            };
          }
        )
      ];
      description = "Environment specific settings";
    };

  };

}
