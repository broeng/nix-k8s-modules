{ pkgs, lib, ... }:
{

  #
  # Create a SHA256 hash of the given file.
  #
  # Unsafe because the input and output will be stored
  # in the nix store, so no sensitive inputs should be given.
  #
  unsafeSha256Hash =
    inputFile:
    lib.strings.trim (
      builtins.readFile (
        pkgs.stdenv.mkDerivation {
          name = "sha256hash";
          phases = [ "buildPhase" ];
          buildPhase = ''
            ${pkgs.coreutils}/bin/sha256sum ${inputFile} | \
              ${pkgs.coreutils}/bin/cut -d' ' -f1 > $out
          '';
        }
      )
    );

}
