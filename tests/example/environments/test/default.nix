{ config, ... }:
{

  k8s.environment = {
    name = "test";
    kubeVersion = "v1.33.0";
    domainTLD = "example.com";
    applications = with config.applications; [
      hello
      web
    ];
  };

  k8s.annotationDomain = "k8s.example.com";

  resources.greeting.content = "hello world";

}
