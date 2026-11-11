{ pkgs, lib, ... }:
{

  #
  # Encode given string to base64
  # Unsafe because the input and output will be stored
  # in the nix store, so no sensitive inputs should be given.
  #
  unsafeEncodeBase64 =
    textInput:
    builtins.readFile (
      pkgs.stdenv.mkDerivation {
        inherit textInput;
        passAsFile = [ "textInput" ];
        name = "b64-encode";
        phases = [ "buildPhase" ];
        buildPhase = "${pkgs.coreutils}/bin/base64 -w 0 $textInputPath > $out";
      }
    );

}
