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
    applications = lib.mkOption {
      type = lib.types.attrsOf (
        import ./application.nix {
          inherit
            pkgs
            lib
            k8slib
            kubelib
            ;
          flakeConfig = config;
        }
      );
      description = "Collection of applications for ArgoCD";
    };

    k8s.annotationDomain = lib.mkOption {
      type = lib.types.str;
      default = "nix-k8s-modules";
      example = "k8s.example.com";
      description = ''
        Domain used in the annotation prefix for generated annotations, e.g.
        `<application>.<annotationDomain>/config-hash`. Must form a valid
        DNS subdomain together with the application name.
      '';
    };
  };

  config = {

    assertions = lib.flatten (
      lib.mapAttrsToList (k: v: [
        (
          let
            isRestrictedKind = manifest: builtins.elem manifest.kind v.validation.restrictedManifestKinds;
            restrictedManifestsInCharts = lib.filter isRestrictedKind (
              v.dependencies.chartResources ++ v.application.chartResources
            );
            untrackedManifests = lib.filter (
              r: (lib.lists.any (s: r.metadata.name == s) v.validation.allowedManifestNames) == false
            ) restrictedManifestsInCharts;
            untrackedManifestNames = lib.map (m: m.metadata.name) untrackedManifests;
          in
          {
            assertion = untrackedManifests == [ ];
            message =
              "ERROR: A chart for application ${v.name} contains restricted manifest Kind types!\n"
              + "ERROR: Secrets/restricted manifests:\n"
              + "ERROR:\t${lib.concatStringsSep "\nERROR:\t" untrackedManifestNames}";
          }
        )
        (
          let
            containersDeps =
              if v.validation.requireResourcesForDependencies then v.dependencies.containers else [ ];
            containersApp =
              if v.validation.requireResourcesForApplication then v.application.containers else [ ];
            allContainers = containersDeps ++ containersApp;
            containersMissingResources = lib.filter (
              c: (builtins.hasAttr "resources" c) == false
            ) allContainers;
            violatingNames = lib.map (c: c.name) containersMissingResources;
          in
          {
            assertion = containersMissingResources == [ ];
            message =
              "ERROR: Application ${v.name} is missing required 'resources' set for the following containers:\n"
              + "ERROR:\t${lib.concatStringsSep "\nERROR:\t" violatingNames}";
          }
        )
      ]) config.applications
    );

  };

}
