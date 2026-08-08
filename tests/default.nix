let
  # TODO: Add nix-vm-test and nixpkgs
in
{
  install-script-test = import ./tests/install-script.nix {
    system = pkgs.stdenv.buildPlatform.system;
    nix-vm-test = inputs.nix-vm-test;
  };
}
