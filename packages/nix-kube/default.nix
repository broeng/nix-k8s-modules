{ writeShellApplication, coreutils }:
#
# Start a temporary pod running nix-shell in the current cluster, removed
# again on exit. Arguments are passed on to nix-shell, e.g.:
#
#   NAMESPACE=foo nix-kube -p curl dig
#
# Uses kubectl from PATH, so the version matching the cluster is used.
#
writeShellApplication {
  name = "nix-kube";
  runtimeInputs = [ coreutils ];
  text = ''
    NS=''${NAMESPACE:-default}
    kubectl --namespace="$NS" run -it --rm "nix-kube-''${USER:-$(id -un)}" \
      --image nixos/nix -- nix-shell "$@"
  '';
}
