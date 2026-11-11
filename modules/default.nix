{ nix-kube-generators }:
let
  #
  # Provides default `k8slib` and `kubelib` module arguments, built from the
  # `pkgs` module argument. Both can be overridden by setting them through
  # `_module.args` (or specialArgs). The key ensures it's only included once,
  # no matter how many of the modules below are imported.
  #
  args = {
    key = "nix-k8s-modules/args";
    _file = ./default.nix;
    imports = [
      (
        { lib, pkgs, ... }:
        {
          _module.args = {
            k8slib = lib.mkDefault (pkgs.callPackage ../lib/k8slib { });
            kubelib = lib.mkDefault (nix-kube-generators.lib { inherit pkgs; });
          };
        }
      )
    ];
  };

  environment = {
    _file = ./default.nix;
    imports = [
      ./environment
      args
    ];
  };

  # applications depend on k8s.environment (kubeVersion), so include it
  apps = {
    _file = ./default.nix;
    imports = [
      ./apps
      ./environment
      args
    ];
  };

  resources = {
    _file = ./default.nix;
    imports = [
      ./resources
      args
    ];
  };
in
{
  inherit environment apps resources;

  default = {
    _file = ./default.nix;
    imports = [
      environment
      apps
      resources
    ];
  };
}
