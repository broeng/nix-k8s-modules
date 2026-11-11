{ lib, ... }:
{

  application = args: {
    apiVersion = "argoproj.io/v1alpha1";
    kind = "Application";
    metadata = {
      name = args.name;
      namespace = args.namespace;
    };
    spec = {
      project = args.project;
      source = {
        repoURL = args.repoUrl;
        targetRevision = "HEAD";
        path = args.path;
      }
      // args.source;
      destination = {
        server = "https://kubernetes.default.svc";
        namespace = args.targetNamespace;
      };
      ignoreDifferences = args.ignoreDifferences;
      syncPolicy = args.syncPolicy;
    };
  };

}
