# Stand-in for a per environment nixpkgs input
{ system, config }:
{
  inherit config;
  kubectl = derivation {
    name = "kubectl-env-test";
    inherit system;
    builder = "/bin/sh";
    args = [
      "-c"
      "echo > $out"
    ];
  };
}
