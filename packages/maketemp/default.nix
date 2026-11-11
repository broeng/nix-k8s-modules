{ writeShellApplication, coreutils }:
#
# Write stdin to a new temporary file, readable only by the current user,
# and print its path. Inside shells from mkDevShell/mkEnvironmentShells the
# file is created in $K8S_SHELL_TMPDIR, which is removed when the shell exits.
#
#   export KUBECONFIG=$(some-secret-command | maketemp)
#
writeShellApplication {
  name = "maketemp";
  runtimeInputs = [ coreutils ];
  text = ''
    if [ -n "''${K8S_SHELL_TMPDIR:-}" ]; then
      OUT=$(mktemp -p "$K8S_SHELL_TMPDIR")
    else
      OUT=$(mktemp)
    fi
    chmod 600 "$OUT"
    cat > "$OUT"
    echo "$OUT"
  '';
}
