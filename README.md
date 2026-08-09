# git-kitten

Open your git diffs in kitty's side-by-side viewer. It's opt-in: a `git kitten`
subcommand you run when you want it, with no changes to your git config.

```sh
git kitten diff <A> <B>
```

`<A>` and `<B>` are anything you'd give `git diff`: commits, branches, ranges,
or paths.

## Usage

```sh
git kitten diff                      # unstaged changes
git kitten diff --staged             # staged changes
git kitten diff HEAD                 # all uncommitted changes
git kitten diff HEAD~1 HEAD          # between two commits
git kitten diff main feature         # between two branches
git kitten diff HEAD~3..HEAD         # a range
git kitten diff HEAD~1 HEAD -- path  # scoped to a path
```

To compare two arbitrary files or directories, use kitty directly:
`kitten diff a.txt b.txt`.

## Install

Requires [kitty](https://sw.kovidgoyal.net/kitty/) (for `kitten`) and git.

### Script

```sh
./install.sh # -> ~/.local/bin/git-kitten
PREFIX=/usr/local/bin ./install.sh
```

Make sure the target directory is on your `PATH`, then run `git kitten diff`
in any repo.

To remove it again, run the same script with `--uninstall` (and the same
`PREFIX`/`MANPREFIX` you installed with, if any):

```sh
./install.sh --uninstall
```

### Nix

Try it from anywhere (requires flakes):

```sh
nix run github:eureka-cpu/kitty-diff-git -- diff
```

Add it to your profile:

```sh
nix profile add github:eureka-cpu/kitty-diff-git
git kitten diff
```

Add it to your configuration:

```nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.git-kitten = {
    url = "github:eureka-cpu/kitty-diff-git";
    flake = false;
  };
  outputs = { nixpkgs, git-kitten, ... }: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            # Add git-kitten to your package set
            (import "${git-kitten}/overlay.nix")
          ];
          environment.systemPackages = with pkgs; [
            git
            kitty
            git-kitten # Add git-kitten to your system
          ];
        })
      ];
    };
  };
}
```
