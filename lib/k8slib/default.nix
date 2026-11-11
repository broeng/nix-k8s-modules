{ pkgs, lib, ... }:
rec {

  argo = pkgs.callPackage ./argo.nix { };

  attrs = pkgs.callPackage ./attrs.nix { };

  base64 = pkgs.callPackage ./base64.nix { };

  charts = pkgs.callPackage ./charts.nix { inherit yaml; };

  external-secrets = pkgs.callPackage ./extsecrets.nix { };

  hash = pkgs.callPackage ./hash.nix { };

  helm = pkgs.callPackage ./helm.nix { };

  istio = pkgs.callPackage ./istio.nix { };

  resources = pkgs.callPackage ./resources.nix { };

  transform = pkgs.callPackage ./transform.nix { };

  yaml = pkgs.callPackage ./yaml.nix { };

}
