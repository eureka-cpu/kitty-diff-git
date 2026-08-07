{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
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

      fmtOpts = {
        projectRootFile = "flake.lock";
        programs = {
          nixpkgs-fmt.enable = true;
          shfmt.enable = true;
          mdformat.enable = true;
        };
        # The shfmt module only exposes indent_size/simplify, so append -ci
        # (indent switch-case bodies, i.e. the `*)` patterns) to its args.
        settings.formatter.shfmt.options = [ "-ci" ];
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
          ((import inputs.treefmt).evalModule pkgs fmtOpts).config.build.check ./.;
      });

      formatter = eachSystem (pkgs: (inputs.treefmt.lib).mkWrapper pkgs fmtOpts);

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          inputsFrom =
            [
              pkgs.git-kitten
            ] ++ builtins.attrValues self.checks.${pkgs.stdenv.buildPlatform.system};
          packages = with pkgs; [ nil ];
        };
      });
    };
}
