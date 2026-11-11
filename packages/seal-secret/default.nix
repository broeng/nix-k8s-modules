{
  writeShellApplication,
  coreutils,
  kubectl,
  kubeseal,
  yq-go,
  yaml2nix,
  nixfmt,
}:
#
# Create a SealedSecret from key=value pairs, and print it as Nix.
#
writeShellApplication {
  name = "seal-secret";
  runtimeInputs = [
    coreutils
    kubectl
    kubeseal
    yq-go
    yaml2nix
    nixfmt
  ];
  text = ''
    usage() {
      cat <<EOF
    Usage: seal-secret [options] key=value [key=value ...]

    Create a SealedSecret from the given key=value pairs, and print it as Nix.

    Options:
      --name NAME                   Name of the secret (default: my-secret)
      -n, --namespace NS            Namespace of the secret, required unless
                                    the scope is cluster-wide
      --scope SCOPE                 cluster-wide (default), namespace-wide or strict
      --controller-name NAME        Name of the sealed-secrets controller
      --controller-namespace NS     Namespace of the sealed-secrets controller
      -h, --help                    Show this help

    The controller defaults to kubeseal's defaults, which can be set with the
    SEALED_SECRETS_CONTROLLER_NAME and SEALED_SECRETS_CONTROLLER_NAMESPACE
    environment variables.
    EOF
    }

    name=my-secret
    namespace=""
    scope=cluster-wide
    controller_args=()

    while [ $# -gt 0 ]; do
      case "$1" in
        --name) name="$2"; shift 2 ;;
        -n|--namespace) namespace="$2"; shift 2 ;;
        --scope) scope="$2"; shift 2 ;;
        --controller-name) controller_args+=(--controller-name "$2"); shift 2 ;;
        --controller-namespace) controller_args+=(--controller-namespace "$2"); shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *) break ;;
      esac
    done

    if [ $# -eq 0 ]; then
      usage >&2
      exit 1
    fi

    case "$scope" in
      cluster-wide) ;;
      namespace-wide|strict)
        if [ -z "$namespace" ]; then
          echo "--namespace is required with scope $scope" >&2
          exit 1
        fi
        ;;
      *) echo "Invalid scope: $scope" >&2; exit 1 ;;
    esac

    literals=()
    for kv in "$@"; do
      literals+=("--from-literal=$kv")
    done

    ns_args=()
    if [ -n "$namespace" ]; then
      ns_args=(--namespace "$namespace")
    fi

    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    echo "Kubernetes secret: "
    kubectl create secret generic "$name" "''${ns_args[@]}" "''${literals[@]}" \
      --dry-run=client -o json | tee "$TMP/secret.json"

    echo "Sealed Secret: "
    kubeseal --format=yaml \
      "''${controller_args[@]}" \
      --secret-file="$TMP/secret.json" \
      --scope="$scope" | yq -N . > "$TMP/sealed.yaml"

    yaml2nix "$TMP/sealed.yaml" | nixfmt
  '';
}
