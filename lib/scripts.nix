{ pkgs, lib, ... }:
rec {

  gitFailIfChanges = pkgs.writeShellScriptBin "git-check-changes" ''
    if [[ `${pkgs.git}/bin/git status --porcelain` ]]; then
      # found changes
      echo "[error] Changes found:"
      echo "[error]"
      ${pkgs.git}/bin/git status | ${pkgs.findutils}/bin/xargs -d'\n' -I{} echo "[error] {}"
      echo "[error]"
      echo "[error] You may need to run:"
      echo "[error]"
      echo "[error] > nix run .#values-generate-all"
      echo "[error] OR"
      echo "[error] > nix run .#crd-schemas-generate-all"
      echo "[error]"
      echo "[error] Review if any changes are relevant, and commit the result."
      exit 1
    else
      # no changes found
      exit 0
    fi
  '';

  # Bump each flake input in turn, committing the ones that change the rendered manifests
  updateCharts = pkgs.writeShellScriptBin "update-charts" ''
    set -euo pipefail

    GIT=${pkgs.git}/bin/git
    cd "$($GIT rev-parse --show-toplevel)"

    # refuse to run with local changes, using the same check as CI
    ${gitFailIfChanges}/bin/git-check-changes

    WORKDIR=$(${pkgs.coreutils}/bin/mktemp -d)
    trap '${pkgs.coreutils}/bin/rm -rf "$WORKDIR"' EXIT

    INPUTS=$(${pkgs.jq}/bin/jq -r '.nodes.root.inputs | keys[]' flake.lock)
    BUMPED=()
    UNCHANGED=()
    FAILED=()

    revert() {
      $GIT reset --hard HEAD
      # remove any new files generated during the update
      $GIT clean -fd
    }

    for INPUT in $INPUTS; do
      echo "[info] ===== $INPUT ====="

      if ! nix run .#render-all > "$WORKDIR/baseline.yaml"; then
        echo "[error] Failed to render baseline for $INPUT, aborting"
        exit 1
      fi

      if nix flake update "$INPUT" \
        && nix run .#values-generate-all \
        && nix run .#crd-schemas-generate-all \
        && nix run .#render-all > "$WORKDIR/updated.yaml"; then
        if ${pkgs.diffutils}/bin/cmp -s "$WORKDIR/baseline.yaml" "$WORKDIR/updated.yaml"; then
          echo "[info] No changes to rendered manifests for $INPUT, reverting"
          revert
          UNCHANGED+=("$INPUT")
        else
          echo "[info] Rendered manifests changed for $INPUT, committing"
          $GIT add -A
          $GIT commit -m "$INPUT: bump to latest version"
          BUMPED+=("$INPUT")
        fi
      else
        echo "[error] Failed to update $INPUT, reverting"
        revert
        FAILED+=("$INPUT")
      fi
    done

    echo ""
    echo "[info] Bumped:    ''${BUMPED[*]:-none}"
    echo "[info] Unchanged: ''${UNCHANGED[*]:-none}"
    echo "[info] Failed:    ''${FAILED[*]:-none}"
    [[ ''${#FAILED[@]} -eq 0 ]]
  '';

  all = {
    "git-check-changes" = gitFailIfChanges;
    "update-charts" = updateCharts;
  };

}
