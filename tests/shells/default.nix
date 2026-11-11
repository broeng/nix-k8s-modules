{
  pkgs,
  lib,
  k8sLib,
  runCommand,
  writeText,
}:
let
  shells = k8sLib.mkEnvironmentShells {
    inherit pkgs;
    # only the names are used by the shells, besides passing conf to shellHook
    environments = {
      test.marker = "conf-test";
      other.marker = "conf-other";
    };
    inputs.nixpkgs-env-test = ./fake-nixpkgs;
    nixpkgsConfig.allowUnfree = true;
    packages =
      envPkgs:
      lib.optional (envPkgs ? config) (
        writeText "config-${builtins.toJSON envPkgs.config.allowUnfree}" ""
      );
    shellHook = env: conf: ''
      export TEST_HOOK=${env}-${conf.marker}
    '';
  };

  names = shell: map (d: d.name) shell.nativeBuildInputs;

  devShell = k8sLib.mkDevShell { inherit pkgs; };

  tools = k8sLib.mkTools pkgs;
in
# env with a matching input uses it, and gets nixpkgsConfig
assert lib.assertMsg (builtins.elem "kubectl-env-test" (
  names shells.test
)) "test: kubectl not from input";
assert lib.assertMsg (builtins.elem "config-true" (names shells.test)) "test: config not passed";
# env without a matching input falls back to pkgs
assert lib.assertMsg (builtins.elem pkgs.kubectl.name (
  names shells.other
)) "other: kubectl not from pkgs";
assert lib.assertMsg (!builtins.elem "config-true" (names shells.other)) "other: unexpected config";
# base tools are in all shells
assert lib.assertMsg (lib.all (s: builtins.elem tools.maketemp.name (names s)) [
  devShell
  shells.test
  shells.other
]) "base tools missing";
runCommand "nix-k8s-modules-shells"
  {
    nativeBuildInputs = [
      tools.maketemp
      tools.seal-secret
    ];
    hook = shells.test.shellHook;
    passAsFile = [ "hook" ];
  }
  ''
    fail() { echo "FAIL: $*"; exit 1; }

    # run the hook as nix develop would, then exit
    bash -e -c '
      source "$1"
      echo "$K8S_ENVIRONMENT" > env
      echo "$TEST_HOOK" > hook
      echo "$PS1" > ps1
      echo secret | maketemp > tmpfile
      echo "$K8S_SHELL_TMPDIR" > tmpdir
      on_exit "touch $PWD/on-exit-ran"
    ' _ "$hookPath"

    [ "$(cat env)" = test ] || fail "K8S_ENVIRONMENT: $(cat env)"
    [ "$(cat hook)" = test-conf-test ] || fail "shellHook: $(cat hook)"
    grep -q ' test ' ps1 || fail "PS1: $(cat ps1)"
    case "$(cat tmpfile)" in
      "$(cat tmpdir)"/*) ;;
      *) fail "maketemp did not use K8S_SHELL_TMPDIR" ;;
    esac
    [ ! -e "$(cat tmpfile)" ] || fail "temp file not removed on exit"
    [ ! -e "$(cat tmpdir)" ] || fail "K8S_SHELL_TMPDIR not removed on exit"
    [ -e on-exit-ran ] || fail "on_exit command did not run"

    # maketemp outside a shell, file is private
    f=$(echo secret | maketemp)
    [ "$(cat "$f")" = secret ] || fail "maketemp content"
    [ "$(stat -c %a "$f")" = 600 ] || fail "maketemp mode $(stat -c %a "$f")"

    # seal-secret argument handling (no cluster needed)
    seal-secret --help | grep -q 'Usage: seal-secret' || fail "seal-secret --help"
    ! seal-secret 2>/dev/null || fail "seal-secret without arguments should fail"
    ! seal-secret --scope bogus a=b 2>/dev/null || fail "invalid scope should fail"
    msg=$(seal-secret --scope strict a=b 2>&1) && fail "strict scope without namespace should fail"
    grep -q -- '--namespace is required' <<<"$msg" || fail "unexpected error: $msg"

    touch $out
  ''
