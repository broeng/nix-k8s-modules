{ lib, ... }:
rec {

  #
  # Recursively traverses an attrset, looking for keys in obj,
  # or it's decendants, which are present in rep. If found, it will
  # replace the value with the value for the same key in rep.
  #
  # Can for instance be used to clear descriptions in manifests:
  #
  # Given:
  # v = { a = { description = "foo" }}
  #
  # Running:
  # traverseReplace v { description = "" }
  #
  # Will result in:
  # res = { a = { description = "" }}
  #
  traverseReplace = obj: rep: traverseReplacePred obj (o: true) rep;

  #
  # Like traverseReplace, but takes a predicate as it's second argument,
  # which must return true for the replacement to take place.
  #
  traverseReplacePred =
    obj: pred: rep:
    if builtins.isAttrs obj then
      (lib.mapAttrs (
        k: v:
        if ((builtins.hasAttr k rep) && (pred obj)) then rep."${k}" else (traverseReplacePred v pred rep)
      ) obj)
    else if builtins.isList obj then
      (lib.map (e: traverseReplacePred e pred rep) obj)
    else
      obj;

}
