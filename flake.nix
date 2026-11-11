{
  description = "Nix modules for defining and rendering kubernetes applications and manifests";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    nix-kube-generators.url = "github:farcaller/nix-kube-generators";
    crds-catalog = {
      url = "github:datreeio/CRDs-catalog";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-kube-generators,
      crds-catalog,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {

      # Modules for use with lib.evalModules
      k8sModules = import ./modules { inherit nix-kube-generators; };

      # Functions for evaluating environments and rendering them
      lib = import ./lib {
        inherit nix-kube-generators crds-catalog;
        inherit (self) k8sModules;
      };

      packages = forAllSystems (
        pkgs:
        {
          openapi2jsonschema = self.lib.mkOpenapi2jsonschema pkgs;
        }
        // self.lib.mkScripts pkgs
      );

      checks = forAllSystems (pkgs: {
        example = pkgs.callPackage ./tests/example { k8sLib = self.lib; };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

    };
}
