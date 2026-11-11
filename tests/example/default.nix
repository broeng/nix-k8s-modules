{
  pkgs,
  lib,
  k8sLib,
  runCommand,
  yq-go,
}:
let
  environments = k8sLib.evalEnvironments {
    inherit pkgs;
    environmentsDir = ./environments;
    applicationDirs = [ ./applications ];
    moduleArgs.greeter = "nix";
  };

  env = environments.test;

  packages = k8sLib.mkRenderPackages { inherit pkgs environments; };

  failedAssertions = lib.filter (a: !a.assertion) env.assertions;
in
assert lib.assertMsg (failedAssertions == [ ]) (
  lib.concatMapStringsSep "\n" (a: a.message) failedAssertions
);
assert lib.assertMsg (packages ? "render-hello-test") "missing render-hello-test package";
assert lib.assertMsg (packages ? "render-web-test") "missing render-web-test package";
runCommand "nix-k8s-modules-example" { nativeBuildInputs = [ yq-go ]; } ''
  ${packages.render-all}/bin/render-all > all.yaml
  ${packages.render-hello-test}/bin/render-hello-test > hello.yaml
  ${packages.render-web-test}/bin/render-web-test > web.yaml

  checkFile() {
    test "$(yq ea "$2" "$1")" = "$3" || {
      echo "check failed in $1: $2 != $3"
      cat "$1"
      exit 1
    }
  }
  check() { checkFile hello.yaml "$@"; }
  web() { checkFile web.yaml "$@"; }

  check 'select(.kind == "Namespace") | .metadata.name' hello
  check 'select(.kind == "ConfigMap") | .data.greeting' "hello world"
  check 'select(.kind == "ConfigMap") | .data.base64' "bml4"
  check 'select(.kind == "Deployment") | .spec.template.metadata.annotations | keys | .[0]' \
    hello.k8s.example.com/config-hash

  # certificate
  cert='select(.kind == "Certificate")'
  web "$cert | .spec.issuerRef | [.group, .kind, .name] | join(\",\")" \
    "cert-manager.io,ClusterIssuer,test-issuer"
  web "$cert | .spec.dnsNames | join(\",\")" "web.example.com,www.example.com"
  web "$cert | .spec | has(\"privateKey\")" false
  web "$cert | .metadata.labels.app" web

  # internal ingress
  int='select(.metadata.name == "web-internal")'
  web "$int | .spec.ingressClassName" traefik-int
  web "$int | .metadata.annotations.\"traefik.ingress.kubernetes.io/router.middlewares\"" \
    traefik-int-force-https@kubernetescrd
  web "$int | .spec.tls[0].secretName" web-tls
  web "$int | .spec.tls[0].hosts | join(\",\")" "web.example.com,www.example.com"

  # external ingress
  ext='select(.metadata.name == "web-external")'
  web "$ext | .spec.ingressClassName" traefik-ext
  web "$ext | .spec | has(\"tls\")" false
  web "$ext | .metadata | has(\"annotations\")" false

  # default class ingress
  def='select(.metadata.name == "web-default")'
  web "$def | .spec | has(\"ingressClassName\")" false
  web "$def | .metadata.labels.app" web
  web "$def | .metadata.namespace" web

  # nothing nginx specific
  web '[.. | select(tag == "!!str") | select(test("nginx"))] | length' 0

  mkdir $out
  cp all.yaml hello.yaml web.yaml $out/
''
