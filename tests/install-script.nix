# VM test for install.sh, run on a real Ubuntu cloud image via nix-vm-test.
#
# Returns the `.driver`: an executable (`bin/test-driver`) you *run* (via
# `nix run`), rather than `.sandboxed` which runs the VM as a hermetic nix
# build. The driver runs in the normal environment, so it has the network the
# `apt-get` steps below need and /dev/kvm — no sandbox to poke holes in. It
# boots Ubuntu (whose /bin/sh is dash and whose git is the distro package) and
# asserts the installer end-to-end. x86_64-linux + KVM only (gated in flake.nix).
{ nix-vm-test, system }:
(nix-vm-test.lib.${system}.ubuntu."24_04" {
  # Mount the project source (install.sh + src/) read-only. Referenced by a
  # relative path rather than the flake's `self` so this stays a plain function
  # that does not depend on flake evaluation.
  sharedDirs.gitKitten = {
    source = "${../.}";
    target = "/mnt/git-kitten";
  };

  testScript = ''
    vm.wait_for_unit("multi-user.target")
    vm.succeed("apt-get update")
    vm.succeed("apt-get install -y git man-db")

    # Stub `kitten` so the wrapper's `command -v kitten` passes and we can prove
    # dispatch actually reaches it (real kitty would pull GL/X deps + need a tty).
    # It only needs to print a marker we can grep for.
    vm.succeed("printf '#!/bin/sh\\necho KITTEN-RAN\\n' > /usr/local/bin/kitten")
    vm.succeed("chmod +x /usr/local/bin/kitten")

    # Run the installer into /usr/local (on the default PATH and MANPATH).
    vm.succeed("PREFIX=/usr/local/bin sh /mnt/git-kitten/install.sh")

    # Installer results: binary + man page landed where expected.
    vm.succeed("test -x /usr/local/bin/git-kitten")
    vm.succeed("test -f /usr/local/share/man/man1/git-kitten.1")

    # git discovers the `kitten` subcommand; short help is our usage().
    vm.succeed("git kitten -h | grep -q 'usage: git kitten diff'")

    # `git kitten --help` -> `man git-kitten` finds the installed page.
    vm.succeed("MANPAGER=cat git kitten --help | col -b | grep -q GIT-KITTEN")

    # Real end-to-end on Ubuntu's dash + git: dispatch reaches our kitten stub.
    vm.succeed(
        "git init /tmp/r && cd /tmp/r && "
        "git config user.email t@t && git config user.name t && "
        "printf 'a\n' > f && git add . && git commit -m c1"
    )
    vm.succeed("cd /tmp/r && printf 'b\n' > f && git kitten diff HEAD | grep -q KITTEN-RAN")

    # Installing to a directory that is not on PATH warns on stderr.
    vm.succeed(
        "PREFIX=/opt/xyz/bin sh /mnt/git-kitten/install.sh 2>&1 | grep -qi 'not on your PATH'"
    )
  '';
}).driver
