{ pkgs, ... }:
{

  #
  # Build a yaml containing the default values file from a chart.
  #
  buildValuesFile =
    {
      name,
      chart,
      namespace ? null,
      extraOpts ? [ ],
    }:
    let
      hasNamespace = !builtins.isNull namespace;
      helmNamespaceFlag = if hasNamespace then "--namespace ${namespace}" else "";
      namespaceName = if hasNamespace then "-${namespace}" else "";
    in
    pkgs.stdenv.mkDerivation {
      name = "helm-${chart}${namespaceName}-${name}-values";
      phases = [ "installPhase" ];
      installPhase = ''
        export HELM_CACHE_HOME="$TMP/.nix-helm-build-cache"
        ${pkgs.kubernetes-helm}/bin/helm show values \
          "${chart}" \
          ${helmNamespaceFlag} \
          ${builtins.concatStringsSep " " extraOpts} \
          >> $out
      '';
    };

  #
  # Package Helm Chart
  #
  packageHelmChart =
    {
      name,
      src,
      ...
    }:
    pkgs.stdenv.mkDerivation {
      name = "helm-${name}-src";
      phases = [ "installPhase" ];
      installPhase = ''
        ${pkgs.kubernetes-helm}/bin/helm package ${src} --destination .
        mv ./${name}*.tgz $out
      '';
    };

}
