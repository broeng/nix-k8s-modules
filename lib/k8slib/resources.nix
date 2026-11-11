{ lib, ... }:
{

  #
  # cert-manager Certificate for commonName (and extraNames), stored in
  # secretName.
  #
  # issuerRef:  required, { name; kind ? "ClusterIssuer"; group ? "cert-manager.io"; }
  # privateKey: privateKey spec, cert-manager defaults are used when null
  # metadata:   extra metadata (labels, annotations, ...)
  # spec:       merged recursively into the generated spec (duration, usages, ...)
  #
  certificate =
    {
      name,
      namespace,
      secretName,
      commonName,
      issuerRef,
      extraNames ? [ ],
      privateKey ? null,
      metadata ? { },
      spec ? { },
    }:
    {
      apiVersion = "cert-manager.io/v1";
      kind = "Certificate";
      metadata = metadata // {
        inherit name namespace;
      };
      spec = lib.recursiveUpdate (
        {
          inherit commonName secretName;
          dnsNames = [ commonName ] ++ extraNames;
          issuerRef = {
            group = "cert-manager.io";
            kind = "ClusterIssuer";
          }
          // issuerRef;
        }
        // lib.optionalAttrs (privateKey != null) { inherit privateKey; }
      ) spec;
    };

  configMap =
    args@{ name, ... }:
    {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = name;
      };
      data = args.data;
    };

  namespace =
    args@{ name, ... }:
    {
      apiVersion = "v1";
      kind = "Namespace";
      metadata = {
        name = name;
      }
      // (lib.optionalAttrs (builtins.hasAttr "labels" args && args.labels != { }) {
        labels = args.labels;
      });
    };

  #
  # Ingress for the given rules, independent of ingress controller.
  #
  # ingressClassName: required, null omits it so the cluster's default
  #                   IngressClass is used
  # tlsSecretName:    when set, a tls section for all hosts in rules is
  #                   added using this secret
  # annotations:      merged into metadata.annotations, e.g. for ingress
  #                   controller specific settings
  # metadata:         extra metadata (labels, annotations, ...)
  # spec:             merged recursively into the generated spec
  #
  ingress =
    {
      name,
      namespace,
      rules,
      ingressClassName,
      tlsSecretName ? null,
      annotations ? { },
      metadata ? { },
      spec ? { },
    }:
    {
      apiVersion = "networking.k8s.io/v1";
      kind = "Ingress";
      metadata =
        lib.recursiveUpdate metadata (lib.optionalAttrs (annotations != { }) { inherit annotations; })
        // {
          inherit name namespace;
        };
      spec = lib.recursiveUpdate (
        {
          inherit rules;
        }
        // lib.optionalAttrs (ingressClassName != null) { inherit ingressClassName; }
        // lib.optionalAttrs (tlsSecretName != null) {
          tls = [
            {
              hosts = lib.map (r: r.host) rules;
              secretName = tlsSecretName;
            }
          ];
        }
      ) spec;
    };

}
