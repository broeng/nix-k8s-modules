{ lib, ... }:
rec {

  #
  # Will recursively check, if everything in given attrset 'other'
  # matches the given attrset 'obj'. Returns true if everything in
  # 'other' matches 'obj', starting at the root of 'obj'.
  #
  # Can be used to match against kubernetes manifests.
  #
  # Given:
  #   obj = { api = "..."; kind = "Secret"; manifest.name = "foo"; data = { ... }}
  #   other = { kind = "Secret"; manifest.name = "foo"; }
  #
  # Running:
  #   attrSetContains obj other
  #
  # Should return 'true'.
  #
  attrSetContains =
    obj: other:
    builtins.all (r: r) (
      lib.mapAttrsToList (
        k: v:
        if (builtins.hasAttr k obj) then
          (
            if ((builtins.isAttrs obj."${k}") && (builtins.isAttrs v)) then
              attrSetContains obj."${k}" v
            else
              obj."${k}" == v
          )
        else
          false
      ) other
    );

  #
  # Uses attrSetContains to check if obj contains any of the attrsets in others.
  #
  attrSetContainsAnyOf = obj: others: builtins.any (attrSetContains obj) others;

}
