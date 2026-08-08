let
  /**
    Get a node from the flake lock file.

    Type: getFlake' :: String -> Attrset

    :::example getFlake' "nixpkgs"
  */
  getFlake' = node:
    let source = (builtins.fromJSON (builtins.readFile ../flake.lock)).nodes.${node}.locked; in
      {
        inherit (source) rev;
        outPath = fetchTarball
          (let inherit (source) owner repo rev narHash; in {
            url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
            sha256 = narHash;
          });
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
    # Mount the project source (install.sh + src/) read-only. Referenced by a
    # relative path rather than the flake's `self` so this stays a plain function
    # that does not depend on flake evaluation.
    sharedDirs.gitKitten = {
      source = "${../.}";
      target = "/mnt/git-kitten";
    };
  
    testScript = ''
      vm.wait_for_unit("multi-user.target")

      # git and man are already present on the base image; nothing to apt-get.
      # Run the installer into /usr/local (on the default PATH and MANPATH).
      vm.succeed("PREFIX=/usr/local/bin sh /mnt/git-kitten/install.sh")

      # Installer results: binary + man page landed where expected.
      vm.succeed("test -x /usr/local/bin/git-kitten")
      vm.succeed("test -f /usr/local/share/man/man1/git-kitten.1")

      # Without `kitten` (kitty) on PATH, git-kitten fails fast with exit 127
      # -- the `command -v kitten` guard runs before any argument parsing, so
      # this must be checked before the stub below is created. 127 is the
      # meaningful signal here (a missing dependency, distinct from the usage
      # errors below which all use exit 2), so check the status explicitly
      # via `execute` rather than the plain "did it fail" of `vm.fail`.
      status, out = vm.execute("git kitten -h 2>&1")
      assert status == 127, f"expected exit 127, got {status}:\n{out}"
      assert "'kitten' not found" in out, f"expected 'kitten' not found message:\n{out}"

      # Stub `kitten` (real kitty needs a GPU/terminal we don't have here) that
      # records the two dir-diff directories git difftool hands it, so we can
      # later prove git-kitten materializes the *correct* diff content, not
      # just that dispatch reaches some binary.
      vm.succeed(
        "printf '#!/bin/sh\\n"
        "echo KITTEN-RAN\\n"
        "test $1 = diff && cp $2/f /tmp/kitten-local-f 2>/dev/null\\n"
        "test $1 = diff && cp $3/f /tmp/kitten-remote-f 2>/dev/null\\n"
        "exit 0\\n"
        "' > /usr/local/bin/kitten"
      )
      vm.succeed("chmod +x /usr/local/bin/kitten")

      # Help: short usage (bare and -h), long help via the installed man page,
      # and `diff -h` showing our own usage rather than forwarding to `git
      # difftool`'s help.
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

      # Real end-to-end on Ubuntu's dash + git.
      vm.succeed(
        "git init /tmp/r && cd /tmp/r && "
        "git config user.email t@t && git config user.name t && "
        "printf 'a\n' > f && git add . && git commit -m c1"
      )

      # Comparing a commit to itself is a no-op, not an error.
      out = vm.succeed("cd /tmp/r && git kitten diff HEAD HEAD 2>&1")
      assert "no differences between the given inputs" in out, f"expected no-differences message:\n{out}"

      # An actual change: dispatch reaches `kitten diff <LOCAL> <REMOTE>` with
      # the real old/new contents, proving the --dir-diff wiring works end to
      # end, not just that dispatch reaches the binary.
      vm.succeed("cd /tmp/r && printf 'b\n' > f")

      out = vm.succeed("cd /tmp/r && git kitten diff HEAD")
      assert "KITTEN-RAN" in out, f"expected dispatch to reach the kitten stub:\n{out}"

      local_content = vm.succeed("cat /tmp/kitten-local-f").strip()
      assert local_content == "a", f"expected LOCAL dir-diff content 'a', got {local_content!r}"

      remote_content = vm.succeed("cat /tmp/kitten-remote-f").strip()
      assert remote_content == "b", f"expected REMOTE dir-diff content 'b', got {remote_content!r}"

      # Failure cases. All three are usage errors (exit 2); the message is
      # what distinguishes them, so `vm.fail` (the counterpart to `succeed`)
      # is enough -- no need to pin the exact status like the 127 case above.
      out = vm.fail("cd / && git kitten diff 2>&1")
      assert "not inside a git repository" in out, f"expected not-a-repo message:\n{out}"

      out = vm.fail("git kitten frobnicate 2>&1")
      assert "unknown subcommand 'frobnicate'" in out, f"expected unknown-subcommand message:\n{out}"

      vm.succeed("cd /tmp/r && touch x y")
      out = vm.fail("cd /tmp/r && git kitten diff x y 2>&1")
      assert "look like files, not git revisions" in out, f"expected two-plain-files message:\n{out}"

      # Installing to a directory that is not on PATH warns on stderr.
      out = vm.succeed("PREFIX=/opt/xyz/bin sh /mnt/git-kitten/install.sh 2>&1")
      assert "not on your path" in out.lower(), f"expected PATH warning:\n{out}"
    '';
  };
}
  
