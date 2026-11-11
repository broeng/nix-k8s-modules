{
  pkgs,
  lib,
  k8slib,
  kubelib,
  ...
}:
lib.types.submodule [
  (
    { config, ... }:
    {
      options = {

        file = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to a file";
        };

        content = lib.mkOption {
          type = lib.types.str;
          default = if (config.file != null) then builtins.readFile config.file else "";
          description = "Text content for this resource";
        };

      };
    }
  )
]
