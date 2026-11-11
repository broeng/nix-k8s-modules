{
  pkgs,
  lib,
  k8sModules,
  ...
}:
rec {

  # Function to discover application folders (folders in root containing a default.nix)
  discoverApplicationsAtRoot =
    root:
    let # Files in the root
      root-files = builtins.attrNames (builtins.readDir root);
      # Generate list of expected app file paths
      app-files = map (file: (root + "/${file}/default.nix")) root-files;
    in
    # return the paths that exist
    builtins.filter builtins.pathExists app-files;

  discoverEnvironmentsAtRoot =
    root:
    let
      envFolders = builtins.attrNames (builtins.readDir root);
    in
    # return only folders containing a default.nix
    builtins.filter (d: builtins.pathExists (root + "/${d}/default.nix")) envFolders;

  #
  # Evaluate a single environment.
  #
  # environment:     path to (or inline) module defining k8s.environment
  # applicationDirs: directories whose sub-folders containing a default.nix
  #                  are loaded as application modules
  # modules:         extra modules to include in the evaluation
  # moduleArgs:      extra arguments passed to all modules via _module.args
  #
  evalEnvironment =
    {
      environment,
      applicationDirs ? [ ],
      modules ? [ ],
      moduleArgs ? { },
    }:
    (lib.evalModules {
      modules = [
        {
          _module.args = moduleArgs // {
            inherit pkgs lib;
          };
        }
        "${pkgs.path}/nixos/modules/misc/assertions.nix"
        k8sModules.default
        environment
      ]
      ++ modules
      ++ (lib.concatMap discoverApplicationsAtRoot applicationDirs);
    }).config;

  #
  # Evaluate every environment found in environmentsDir (sub-folders
  # containing a default.nix), returning an attrset keyed by folder name.
  #
  evalEnvironments =
    {
      environmentsDir,
      applicationDirs ? [ ],
      modules ? [ ],
      moduleArgs ? { },
    }:
    lib.genAttrs (discoverEnvironmentsAtRoot environmentsDir) (
      env:
      evalEnvironment {
        environment = environmentsDir + "/${env}";
        inherit applicationDirs moduleArgs;
        modules = modules ++ [
          # package names and rendered paths use the folder name, while
          # applications refer to k8s.environment.name
          (
            { config, ... }:
            {
              assertions = [
                {
                  assertion = config.k8s.environment.name == env;
                  message = "ERROR: k8s.environment.name '${config.k8s.environment.name}' must match its folder name '${env}'";
                }
              ];
            }
          )
        ];
      }
    );

}
