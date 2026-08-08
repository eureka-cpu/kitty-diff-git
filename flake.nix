{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vm-test = {
      url = "github:numtide/nix-vm-test";
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

      apps = eachSystem (pkgs:
        {
          default = {
            type = "app";
            program = "${pkgs.git-kitten}/bin/git-kitten";
            meta.description = "An opt-in kitty-diff git plugin.";
          };
        }
        # The install.sh VM test is a runnable driver (needs an Ubuntu image +
        # network + KVM), so it is an app you `nix run`, not a hermetic check.
        # nix-vm-test only supports x86_64-linux, so gate it there.
        // nixpkgs.lib.optionalAttrs (pkgs.stdenv.buildPlatform.system == "x86_64-linux") {
          install-script-test = {
            type = "app";
            program = "${import ./tests/install-script.nix {
              system = pkgs.stdenv.buildPlatform.system;
              nix-vm-test = inputs.nix-vm-test;
            }}/bin/test-driver";
            meta.description = "Run install.sh on an Ubuntu VM (needs KVM).";
          };
        });

      checks = eachSystem (pkgs: {
        treefmt-check =
          ((import inputs.treefmt).evalModule pkgs fmtOpts).config.build.check ./.;
      });

      formatter = eachSystem (pkgs: (inputs.treefmt.lib).mkWrapper pkgs fmtOpts);

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
