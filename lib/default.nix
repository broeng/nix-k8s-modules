{
  nix-kube-generators,
  crds-catalog,
  k8sModules,
}:
rec {

  # Helper library for building kubernetes manifests (k8slib)
  mkK8sLib = pkgs: pkgs.callPackage ./k8slib { };

  # nix-kube-generators library (kubelib)
  mkKubeLib = pkgs: nix-kube-generators.lib { inherit pkgs; };

  mkOpenapi2jsonschema = pkgs: pkgs.callPackage ../packages/openapi2jsonschema { };

  #
  # Evaluate a single environment module together with applications.
  # See ./loading.nix for arguments, plus `pkgs`.
  #
  evalEnvironment =
    args@{ pkgs, ... }:
    (pkgs.callPackage ./loading.nix { inherit k8sModules; }).evalEnvironment (
      removeAttrs args [ "pkgs" ]
    );

  #
  # Evaluate all environments in a directory, returns an attrset of
  # evaluated configs keyed by environment name.
  #
  # evalEnvironments {
  #   inherit pkgs;
  #   environmentsDir = ./environments;
  #   applicationDirs = [ ./applications ./bundles ];
  #   modules = [ ./resources ];
  #   moduleArgs = { inherit charts; };
  # }
  #
  evalEnvironments =
    args@{ pkgs, ... }:
    (pkgs.callPackage ./loading.nix { inherit k8sModules; }).evalEnvironments (
      removeAttrs args [ "pkgs" ]
    );

  #
  # Rendering functions (makeRendererPackages, makeRenderAll, ...) for
  # evaluated environments.
  #
  mkRendering =
    {
      pkgs,
      crdsCatalog ? crds-catalog,
      valuesDir ? "docs/generated-values",
      crdSchemasDir ? "docs/generated-crd-schemas",
    }:
    pkgs.callPackage ./rendering.nix {
      k8slib = mkK8sLib pkgs;
      openapi2jsonschema = mkOpenapi2jsonschema pkgs;
      inherit crdsCatalog valuesDir crdSchemasDir;
    };

  #
  # All rendering packages for the given evaluated environments:
  #
  #   render-<app>-<env>, render-dependencies-<app>-<env>,
  #   render-no-deps-<app>-<env>, render-all, values-<chart>-<env>,
  #   values-generate-all, crd-schemas-generate-all, validate-crd,
  #   make-chart-tree
  #
  mkRenderPackages =
    args@{ environments, ... }:
    let
      r = mkRendering (removeAttrs args [ "environments" ]);
    in
    (r.makeRendererPackages environments)
    // (r.makePackageDependenciesRenderer environments)
    // (r.makePackageOnlyRenderer environments)
    // (r.makeRenderAll environments)
    // (r.makeChartValuesRenderer environments)
    // (r.makeChartValuesRenderAll environments)
    // (r.makeCRDSchemasAll environments)
    // (r.makeCRDValidate environments)
    // (r.makeChartTree environments);

  # General utility scripts (git-check-changes, update-charts)
  mkScripts = pkgs: (pkgs.callPackage ./scripts.nix { }).all;

}
