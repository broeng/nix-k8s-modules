# Deploying rendered manifests with ArgoCD

This guide sets up a downstream repository to commit its rendered manifests
and have ArgoCD deploy them as plain files. ArgoCD then needs no Nix, no config
management plugin and no evaluation at sync time, and every change to the
cluster shows up as a diff of YAML in review.

The result looks like this:

```
rendered/
  README.md
  prod/
    bootstrap-app/manifests.yaml   # Application manifests for all apps below
    cert-manager/manifests.yaml
    hello/manifests.yaml
  staging/
    ...
```

## 1. Enable the package

Set `manifestsDir` where the render packages are created:

```nix
packages.x86_64-linux =
  k8s-modules.lib.mkRenderPackages {
    inherit pkgs environments;
    manifestsDir = "rendered";
  }
  // k8s-modules.lib.mkScripts pkgs;
```

`manifestsDir` is relative to where the script is run, so run it from the
repository root.

## 2. Check environment names

Paths use the name of the environment folder, while applications see
`k8s.environment.name`. `evalEnvironments` fails if the two differ, so make
sure `environments/prod/default.nix` has:

```nix
k8s.environment.name = "prod";
```

## 3. Point the applications at the files

A bootstrap application generates one ArgoCD `Application` per application in
the environment, plus one for itself. Each one points at the directory of its
environment and application:

```nix
# applications/bootstrap-app/default.nix
{ config, lib, ... }:
let
  env = config.k8s.environment;
  self = "bootstrap-app";

  mkApplication = app: {
    apiVersion = "argoproj.io/v1alpha1";
    kind = "Application";
    metadata = {
      name = app.name;
      namespace = "argocd";
    };
    spec = {
      project = "default";
      destination = {
        server = "https://kubernetes.default.svc";
        namespace = app.namespace.name;
      };
      source = {
        repoURL = "https://git.example.com/k8s.git";
        targetRevision = "HEAD";
        path = "rendered/${env.name}/${app.name}";
      };
      ignoreDifferences = app.deployment.ignoreDifferences;
      syncPolicy = {
        syncOptions =
          lib.optional app.deployment.syncPolicy.respectIgnoreDifferences "RespectIgnoreDifferences=true"
          ++ lib.optional app.deployment.syncPolicy.useServerSideApply "ServerSideApply=true";
      }
      # an empty `automated` still enables automatic sync, so leave it out
      # entirely for disabled applications
      // lib.optionalAttrs app.enable {
        automated = {
          prune = true;
          selfHeal = true;
        };
      };
    };
  };
in
{
  applications.${self} = {
    namespace.name = "argocd";
    dependencies.manifests = map mkApplication (
      builtins.filter (a: a.name != self) env.applications
    );
    application.manifests = [ (mkApplication config.applications.${self}) ];
  };
}
```

Add `bootstrap-app` to `k8s.environment.applications` in each environment.

## 4. Generate and commit

```sh
nix run .#manifests-generate-all
git add rendered
git commit -m "Render manifests"
```

Run it after every change to applications, environments or flake inputs, and
commit the result together with the change. `update-charts` already does this
when it bumps inputs.

To have diffs of the rendered files collapsed in review, add this to
`.gitattributes`:

```
rendered/** linguist-generated=true
```

## 5. Bootstrap the cluster

Once ArgoCD is running, apply the bootstrap application once by hand:

```sh
kubectl apply -f rendered/prod/bootstrap-app/manifests.yaml
```

From then on the bootstrap application manages itself and all the other
applications from the files in the repository.

## 6. Check in CI

Make CI fail when someone forgot to regenerate:

```sh
nix run .#manifests-generate-all
nix run .#git-check-changes
```

## Migrating from a config management plugin

Switching an application only changes its `source`: replace `source.plugin`
with `source.path`. Applications can be moved one at a time, and the plugin
can be removed from ArgoCD once nothing uses it. ArgoCD sees the same
manifests either way, as `manifests-generate-all` writes exactly what
`render-<app>-<env>` prints.

## Things to keep in mind

- Everything rendered is committed in plain text. Keep secrets out of the
  manifests, using e.g. SealedSecrets or ExternalSecrets.
- Charts using Helm's random functions (`randAlphaNum` and friends) render
  differently on each build and show up as changes. Set those values
  explicitly, or discard the resources.
- The script replaces the whole `rendered` directory. Don't keep anything else
  in it.
