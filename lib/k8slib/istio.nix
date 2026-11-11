{ lib, ... }:
{

  gateway =
    args@{ name, ... }:
    {
      apiVersion = "networking.istio.io/v1";
      kind = "Gateway";
      metadata = {
        name = name;
        namespace = args.namespace;
      };
      spec = args.spec;
    };

}
