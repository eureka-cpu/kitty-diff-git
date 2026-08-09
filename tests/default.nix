let
  /** Get a node from the flake lock file.

  getFlake' :: String -> Attrset */
  getFlake' = node:
    let source = (builtins.fromJSON (builtins.readFile ../flake.lock)).nodes.${node}.locked; in
    {
      inherit (source) rev;
      outPath = fetchTarball
        (
          let inherit (source) owner repo rev narHash; in {
            url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
            sha256 = narHash;
          }
        );
    };
in
{ nixpkgs ? getFlake' "nixpkgs" }:
let
  inputs = import ../nix/tamal { bootstrap-nixpkgs = nixpkgs; };
  pkgs = import nixpkgs {
    overlays = [ (import "${inputs.nix-vm-test}/overlay.nix") ];
  };
in
{
  install-script-test = pkgs.testers.nonNixOSDistros.ubuntu."24_04" {
    # Mount the project source.
    sharedDirs.gitKitten = {
      source = "${../.}";
      target = "/mnt/git-kitten";
    };
    sharedDirs.kittenPkg = {
      source = "${pkgs.kitty.kitten}";
      target = "/mnt/kitten-pkg";
    };

    testScript = ''
      vm.wait_for_unit("multi-user.target")

      # Run the installer into /usr/local (on the default PATH and MANPATH).
      vm.succeed("PREFIX=/usr/local/bin sh /mnt/git-kitten/install.sh")
      # Installing to a directory that is not on PATH warns on stderr.
      out = vm.succeed("PREFIX=/opt/xyz/bin sh /mnt/git-kitten/install.sh 2>&1")
      assert "not on your path" in out.lower(), f"expected PATH warning:\n{out}"

      # Installer results: binary + man page landed where expected.
      vm.succeed("test -x /usr/local/bin/git-kitten")
      vm.succeed("test -f /usr/local/share/man/man1/git-kitten.1")

      # Without `kitten` on PATH, git-kitten fails fast with exit 127.
      # The `command -v kitten` guard runs before any argument parsing, so
      # this must be checked before the real binary below is installed.
      status, out = vm.execute("git kitten -h 2>&1")
      assert status == 127, f"expected exit 127, got {status}:\n{out}"
      assert "'kitten' not found" in out, f"expected 'kitten' not found message:\n{out}"

      # Symlink the kitten binary from the shared directory mount.
      vm.succeed("ln -s /mnt/kitten-pkg/bin/kitten /usr/local/bin/kitten")

      # Check help output and man pages work correctly.
      out = vm.succeed("git kitten -h")
      assert "usage: git kitten diff" in out, f"expected usage text:\n{out}"

      out = vm.succeed("git kitten")
      assert "usage: git kitten diff" in out, f"expected usage text:\n{out}"

      out = vm.succeed("git kitten diff -h")
      assert "usage: git kitten diff" in out, f"expected usage text:\n{out}"

      out = vm.succeed("MANPAGER=cat git kitten --help | col -b")
      assert "GIT-KITTEN" in out, f"expected man page title:\n{out}"
      assert "SYNOPSIS" in out, f"expected man page SYNOPSIS section:\n{out}"
      assert "EXAMPLES" in out, f"expected man page EXAMPLES section:\n{out}"

      # Use Ubuntu's pre-installed dash and git.
      vm.succeed(
        "git init -q /tmp/r && cd /tmp/r && "
        "git config user.email t@t && git config user.name t && "
        "printf 'a\n' > f && git add . && git commit -m c1"
      )

      # Check no-op output when there is no diff.
      out = vm.succeed("cd /tmp/r && git kitten diff HEAD HEAD 2>&1")
      assert "no differences between the given inputs" in out, f"expected no-differences message:\n{out}"

      # Failure cases. All three are usage errors with exit 2.
      out = vm.fail("cd / && git kitten diff 2>&1")
      assert "not inside a git repository" in out, f"expected not-a-repo message:\n{out}"

      out = vm.fail("git kitten frobnicate 2>&1")
      assert "unknown subcommand 'frobnicate'" in out, f"expected unknown-subcommand message:\n{out}"

      vm.succeed("cd /tmp/r && touch x y")
      out = vm.fail("cd /tmp/r && git kitten diff x y 2>&1")
      assert "look like files, not git revisions" in out, f"expected two-plain-files message:\n{out}"

      # --uninstall removes the binary and man page.
      vm.succeed("PREFIX=/usr/local/bin sh /mnt/git-kitten/install.sh --uninstall")
      vm.fail("test -e /usr/local/bin/git-kitten")
      vm.fail("test -e /usr/local/share/man/man1/git-kitten.1")

      # Uninstalling again is a no-op that says so, rather than failing.
      out = vm.succeed("PREFIX=/usr/local/bin sh /mnt/git-kitten/install.sh --uninstall 2>&1")
      assert "not installed" in out.lower(), f"expected not-installed message:\n{out}"
    '';
  };
}
  
