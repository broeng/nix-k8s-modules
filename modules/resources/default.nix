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
    resources = lib.mkOption {
      type = lib.types.attrsOf (
        import ./resources.nix {
          inherit
            pkgs
            lib
            k8slib
            kubelib
            ;
        }
      );
      default = { };
      description = "Collection of resources for ArgoCD applications";
    };
  };

}
