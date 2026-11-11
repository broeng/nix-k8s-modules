{
  pkgs,
  lib,
  tools,
  openapi2jsonschema,
}:
rec {

  # Tools available in all shells
  basePackages = with pkgs; [
    jq
    kubernetes-helm
    nixfmt-tree
    openapi2jsonschema
    tools.maketemp
    tools.nix-kube
    tools.seal-secret
    xurls
    yaml2nix
    yq-go
  ];

  #
  # Shell hook shared by all shells:
  #
  # - K8S_SHELL_TMPDIR: directory for temporary files (used by maketemp),
  #   removed when the shell exits.
  # - on_exit <command>: register a command to run when the shell exits.
  #   Use this instead of `trap ... EXIT`, which would replace the cleanup.
  #
  baseShellHook = ''
    K8S_SHELL_TMPDIR=$(${pkgs.coreutils}/bin/mktemp -d)
    export K8S_SHELL_TMPDIR
    _k8s_on_exit=()
    on_exit() {
      _k8s_on_exit+=("$*")
    }
    _k8s_cleanup() {
      for _k8s_cmd in "''${_k8s_on_exit[@]}"; do
        eval "$_k8s_cmd"
      done
      ${pkgs.coreutils}/bin/rm -rf "$K8S_SHELL_TMPDIR"
    }
    trap _k8s_cleanup EXIT
  '';

  #
  # Development shell with the base tools.
  #
  mkDevShell =
    {
      packages ? [ ],
      shellHook ? "",
    }:
    pkgs.mkShell {
      packages = basePackages ++ packages;
      shellHook = baseShellHook + shellHook;
    };

  defaultPrompt = env: ''\n\[\033[1;32m\][k8s(\u):\w]\$\[\033[0;31m\] ${env} \$\[\033[0m\] '';

  #
  # A shell per evaluated environment (nix develop .#<env>), with the base
  # tools, kubectl, and K8S_ENVIRONMENT set to the environment name.
  #
  # environments:     evaluated environments, e.g. from evalEnvironments
  # inputs:           flake inputs, used to look up a nixpkgs per environment
  # envNixpkgsPrefix: name prefix of the per environment nixpkgs inputs
  # nixpkgsConfig:    config for importing the per environment nixpkgs
  # envPkgs:          env -> package set for that environment. Defaults to
  #                   importing inputs.<envNixpkgsPrefix><env> if it exists,
  #                   otherwise pkgs. Lets tools like kubectl match the
  #                   version of the cluster.
  # packages:         envPkgs -> extra packages for the shell
  # shellHook:        env -> conf -> extra shell hook, e.g. for loading
  #                   credentials. conf is the evaluated environment.
  # prompt:           env -> PS1, or null to leave PS1 alone
  #
  mkEnvironmentShells =
    {
      environments,
      inputs ? { },
      envNixpkgsPrefix ? "nixpkgs-env-",
      nixpkgsConfig ? { },
      envPkgs ? (
        env:
        let
          input = "${envNixpkgsPrefix}${env}";
        in
        if inputs ? ${input} then
          import inputs.${input} {
            system = pkgs.stdenv.hostPlatform.system;
            config = nixpkgsConfig;
          }
        else
          pkgs
      ),
      packages ? (envPkgs: [ ]),
      shellHook ? (env: conf: ""),
      prompt ? defaultPrompt,
    }:
    lib.mapAttrs (
      env: conf:
      let
        p = envPkgs env;
      in
      mkDevShell {
        packages = [ p.kubectl ] ++ packages p;
        shellHook = ''
          export K8S_ENVIRONMENT=${lib.escapeShellArg env}
        ''
        + shellHook env conf
        + lib.optionalString (prompt != null) ''
          export PS1=${lib.escapeShellArg (prompt env)}
        '';
      }
    ) environments;

}
