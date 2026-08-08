{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      inputs = import ./nix/tamal { bootstrap-nixpkgs = nixpkgs; };
      overlays.default = import ./overlay.nix;

      eachSystem = f: nixpkgs.lib.genAttrs [
        # Should work on any system with a POSIX compliant shell
        # that is supported by both kitty and git.
        #
        # <https://search.nixos.org/packages?channel=unstable&query=kitty#show=kitty>
        "aarch64-darwin"
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ]
        (system: f (import nixpkgs {
          inherit system;
          overlays = [ overlays.default ];
        }));

      treefmt = import inputs.treefmt;
      fmtOpts = {
        projectRootFile = "flake.lock";
        programs = {
          nixpkgs-fmt.enable = true;
          shfmt.enable = true;
          kdlfmt.enable = true;
          mdformat.enable = true;
        };
        settings.formatter = {
          nixpkgs-fmt.excludes = [ "nix/tamal/*.nix" ];
          shfmt.options = [ "-ci" ];
        };
      };
    in
    {
      inherit overlays;

      packages = eachSystem (pkgs: {
        inherit (pkgs) git-kitten;
        default = pkgs.git-kitten;
      });

      apps = eachSystem (pkgs: {
        default = {
          type = "app";
          program = "${pkgs.git-kitten}/bin/git-kitten";
          meta.description = "An opt-in kitty-diff git plugin.";
        };
      });

      checks = eachSystem (pkgs: {
        treefmt-check =
          (treefmt.evalModule pkgs fmtOpts).config.build.check ./.;
      });

      formatter = eachSystem (pkgs: treefmt.mkWrapper pkgs fmtOpts);

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [
            pkgs.git-kitten
            self.checks.${pkgs.stdenv.buildPlatform.system}.treefmt-check
          ];
          packages = with pkgs; [ nil ];
        };
      });
    };
}
