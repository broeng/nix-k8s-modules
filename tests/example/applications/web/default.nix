{ lib, k8slib, ... }:
let
  rule = host: {
    inherit host;
    http.paths = [
      {
        backend.service = {
          name = "web";
          port.number = 8080;
        };
        path = "/";
        pathType = "Prefix";
      }
    ];
  };
in
{

  applications.web = {
    namespace.name = "web";

    deployment.embedConfigurationHash = false;

    application.manifests = [
      (k8slib.resources.certificate {
        name = "web";
        namespace = "web";
        secretName = "web-tls";
        commonName = "web.example.com";
        extraNames = [ "www.example.com" ];
        issuerRef.name = "test-issuer";
        metadata.labels.app = "web";
      })

      # internal ingress, TLS terminated by traefik with a https redirect
      (k8slib.resources.ingress {
        name = "web-internal";
        namespace = "web";
        ingressClassName = "traefik-int";
        annotations."traefik.ingress.kubernetes.io/router.middlewares" =
          "traefik-int-force-https@kubernetescrd";
        rules = [
          (rule "web.example.com")
          (rule "www.example.com")
        ];
        tlsSecretName = "web-tls";
      })

      # external ingress, without TLS
      (k8slib.resources.ingress {
        name = "web-external";
        namespace = "web";
        ingressClassName = "traefik-ext";
        rules = [ (rule "web.example.org") ];
      })

      # ingress using the cluster default IngressClass
      (k8slib.resources.ingress {
        name = "web-default";
        namespace = "web";
        ingressClassName = null;
        metadata.labels.app = "web";
        rules = [ (rule "web.example.net") ];
      })
    ];
  };

}
