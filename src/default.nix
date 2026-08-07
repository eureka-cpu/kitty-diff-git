{ lib
, stdenvNoCC
, kitty
, git
, makeWrapper
, shellcheck
}:
stdenvNoCC.mkDerivation {
  pname = "git-kitten";
  version = "0.1.0";
  src = lib.cleanSourceWith {
    filter = path: type: !lib.hasSuffix ".nix" path;
    src = lib.cleanSource ./.;
  };

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ shellcheck ];

  dontConfigure = true; # Keep the POSIX `#!/bin/sh` script intact.
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 git-kitten "$out/bin/git-kitten"
    wrapProgram "$out/bin/git-kitten" \
      --prefix PATH : ${lib.makeBinPath [ kitty git ]}
    runHook postInstall
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    shellcheck -s sh git-kitten
    runHook postCheck
  '';

  meta = {
    description = ''
      A small shell script wrapper which forwards git diff args
      to `kitten diff`, avoiding the need to configure the git
      diff command globally, or per project.
    '';
    license = lib.licenses.mit;
    platforms = lib.intersectLists kitty.meta.platforms git.meta.platforms;
    mainProgram = "git-kitten";
  };
}
