{
  config,
  k8slib,
  greeter,
  ...
}:
{

  applications.hello = {
    namespace = {
      name = "hello";
      create = true;
    };

    application.manifests = [
      (k8slib.resources.configMap {
        name = "hello";
        data.greeting = config.resources.greeting.content;
        data.base64 = k8slib.base64.unsafeEncodeBase64 greeter;
      })
      {
        apiVersion = "bitnami.com/v1alpha1";
        kind = "SealedSecret";
        metadata.name = "hello";
        spec.encryptedData.token = "AgBy3i4OJSWK+PiTySYZZA==";
      }
      {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata.name = "hello";
        spec.template.spec.containers = [
          {
            name = "hello";
            image = "busybox";
            resources.requests.memory = "16Mi";
          }
        ];
      }
    ];
  };

}
