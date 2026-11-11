# nix-k8s-modules

Nix modules for defining Kubernetes applications as Nix, rendering Helm charts
and plain manifests into YAML, and validating the result. Applications are
grouped into environments, and each application renders to its own YAML stream,
which is suitable for e.g. an ArgoCD config management plugin.

## Flake outputs

| Output | Description |
| --- | --- |
| `k8sModules.default` | All modules below |
| `k8sModules.environment` | `k8s.environment` options (name, kubeVersion, domainTLD, applications, variables) |
| `k8sModules.apps` | `applications.<name>` options, validation assertions and `k8s.annotationDomain` (includes `environment`) |
| `k8sModules.resources` | `resources.<name>` for sharing file/text content between applications |
| `lib.mkKubeLib pkgs` | [nix-kube-generators](https://github.com/farcaller/nix-kube-generators) library (`kubelib`) |
| `lib.evalEnvironment` | Evaluate a single environment module with applications |
| `lib.evalEnvironments` | Evaluate every environment found in a directory |
| `lib.mkRenderPackages` | Render, values, CRD schema and validation packages for evaluated environments |
| `lib.mkRendering` | The individual rendering functions used by `mkRenderPackages` |
| `lib.mkScripts pkgs` | `git-check-changes` and `update-charts` helper scripts |
| `lib.mkTools pkgs` | `maketemp`, `nix-kube` and `seal-secret` tools |
| `lib.mkDevShell` | Development shell with the base tools |
| `lib.mkEnvironmentShells` | A development shell per environment |
| `packages.<system>.openapi2jsonschema` | Script used for generating JSON schemas from CRDs |
| `packages.<system>.{maketemp,nix-kube,seal-secret}` | See [Development shells](#development-shells) |
| `devShells.<system>.default` | Base development shell, for working on this repository |

The modules expect `pkgs` as a module argument. `kubelib` is provided to all
modules by default (built from `pkgs`), and can be overridden through
`_module.args`. The `apps` module writes to the `assertions` option from
nixpkgs' `nixos/modules/misc/assertions.nix`, which `evalEnvironment(s)`
includes automatically.

## Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    k8s-modules = {
      url = "github:broeng/nix-k8s-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, k8s-modules, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      environments = k8s-modules.lib.evalEnvironments {
        inherit pkgs;
        # every sub-folder with a default.nix is an environment
        environmentsDir = ./environments;
        # every sub-folder with a default.nix is loaded as a module
        applicationDirs = [ ./applications ];
        # extra modules for all environments
        modules = [ { k8s.annotationDomain = "k8s.example.com"; } ];
        # extra arguments for all modules
        moduleArgs = { };
      };
    in
    {
      packages.x86_64-linux = k8s-modules.lib.mkRenderPackages {
        inherit pkgs environments;
      };
    };
}
```

An environment (`environments/prod/default.nix`):

```nix
{ config, ... }:
{
  k8s.environment = {
    name = "prod";
    kubeVersion = "v1.33.0";
    domainTLD = "example.com";
    applications = with config.applications; [ hello ];
  };
}
```

An application (`applications/hello/default.nix`):

```nix
{ config, charts, ... }:
{
  applications.hello = {
    namespace = {
      name = "hello";
      create = true;
    };

    # charts and manifests the application depends on
    dependencies.manifests = [ ];

    application = {
      charts = [
        {
          name = "hello";
          chart = charts.hello; # path to a helm chart
          values = { replicaCount = 2; };
          discardResources = [ { kind = "Secret"; } ];
        }
      ];
      manifests = [
        {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata.name = "hello";
          data.greeting = "hello world";
        }
      ];
    };
  };
}
```

See [tests/example](tests/example) for a complete, minimal setup.

## Rendering packages

`mkRenderPackages` produces the following packages:

| Package | Description |
| --- | --- |
| `render-<app>-<env>` | All manifests for an application |
| `render-dependencies-<app>-<env>` | Only the dependency manifests of an application |
| `render-no-deps-<app>-<env>` | Only the application manifests, without dependencies |
| `render-all` | All applications in all environments, fails if any assertion fails |
| `values-<chart>-<env>` | Default values of a chart |
| `values-generate-all` | Write default values of all charts to `valuesDir` |
| `crd-schemas-generate-all` | Generate JSON schemas for all CRDs into `crdSchemasDir` |
| `validate-crd` | Validate all manifests with kubeconform |
| `make-chart-tree` | A tree of symlinks to all charts in use, for inspection |

Optional arguments: `crdsCatalog` (defaults to this flake's
[CRDs-catalog](https://github.com/datreeio/CRDs-catalog) input), `valuesDir`
(default `docs/generated-values`) and `crdSchemasDir` (default
`docs/generated-crd-schemas`). The directories are relative to where the
scripts are run.

## Development shells

`lib.mkDevShell { pkgs; packages ? [ ]; shellHook ? ""; }` creates a shell
with the base tools: `jq`, `helm`, `nixfmt-tree`, `openapi2jsonschema`,
`xurls`, `yaml2nix`, `yq` and the tools below.

`lib.mkEnvironmentShells` creates one shell per evaluated environment, used
with `nix develop .#<env>`:

```nix
devShells = k8s-modules.lib.mkEnvironmentShells {
  inherit pkgs environments inputs;
  # config for importing the per environment nixpkgs
  nixpkgsConfig.allowUnfree = true;
  # extra packages, from the package set of the environment
  packages = envPkgs: [ envPkgs.talosctl pkgs.argocd ];
  # extra shell hook, conf is the evaluated environment
  shellHook = env: conf: ''
    export KUBECONFIG=$(fetch-kubeconfig ${env} | maketemp)
    on_exit "echo bye"
  '';
};
```

Each shell has the base tools and `kubectl`, and sets `K8S_ENVIRONMENT` to the
environment name and `PS1` to a prompt showing it (`prompt = null` to disable).

Tools like `kubectl` can be pinned per environment, to match the version
running in each cluster. If `inputs` has an input named `nixpkgs-env-<env>`
(prefix configurable through `envNixpkgsPrefix`), the package set of that
environment is imported from it, otherwise `pkgs` is used. Pass `envPkgs = env:
<package set>` to choose differently.

All shells provide:

- `K8S_SHELL_TMPDIR`: a private temporary directory, removed when the shell
  exits.
- `on_exit <command>`: run a command when the shell exits. Use this instead of
  `trap ... EXIT`, which would replace the cleanup.

### Tools

| Tool | Description |
| --- | --- |
| `maketemp` | Writes stdin to a new private temporary file and prints its path. Inside the shells, the file is created in `K8S_SHELL_TMPDIR`, so it is removed on exit. |
| `nix-kube` | Starts a temporary pod running `nix-shell` with the given arguments, in `$NAMESPACE` (default `default`). |
| `seal-secret` | Creates a SealedSecret from `key=value` pairs and prints it as Nix. Options: `--name` (default `my-secret`), `--namespace`, `--scope` (default `cluster-wide`), `--controller-name` and `--controller-namespace`. The controller can also be set through kubeseal's `SEALED_SECRETS_CONTROLLER_NAME` and `SEALED_SECRETS_CONTROLLER_NAMESPACE` environment variables. |

## Validation

Each application adds assertions (NixOS convention: `assertion = true` means
OK) which are checked by `render-all`:

- Manifests of kinds in `validation.restrictedManifestKinds` (default `Secret`)
  coming from Helm charts must be listed in `validation.allowedManifestNames`.
- All containers must have `resources` set, controlled by
  `validation.requireResourcesForApplication` and
  `validation.requireResourcesForDependencies`.

## Configuration hash

When `deployment.embedConfigurationHash` is enabled (the default), a hash of all
ConfigMaps of an application is added as the annotation
`<app>.<k8s.annotationDomain>/config-hash` on all resources, and on pod
templates, so that workloads are restarted when configuration changes.
