#!/bin/sh

# Install git-kitten onto PATH.
#
#   ./install.sh # -> ~/.local/bin/git-kitten
#   PREFIX=/usr/local/bin ./install.sh
#
# After install, use it as: git kitten diff <A> <B>

set -eu

src_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
src="$src_dir/src/git-kitten"
man_src="$src_dir/src/git-kitten.1"
dest_dir="${PREFIX:-$HOME/.local/bin}"
# Man dir alongside bin: ~/.local/bin -> ~/.local/share/man, etc.
man_dir="${MANPREFIX:-${dest_dir%/bin}/share/man}/man1"

[ -f "$src" ] || {
  echo "install: cannot find git-kitten next to this script ($src)" >&2
  exit 1
}

mkdir -p -- "$dest_dir"
cp -- "$src" "$dest_dir/git-kitten"
chmod +x "$dest_dir/git-kitten" # no `--`: BSD/macOS chmod rejects it
echo "installed: $dest_dir/git-kitten"

# Man page so `git kitten --help` (which runs `man git-kitten`) works.
if [ -f "$man_src" ]; then
  mkdir -p -- "$man_dir"
  cp -- "$man_src" "$man_dir/git-kitten.1"
  echo "installed: $man_dir/git-kitten.1"
fi

# Warn if the destination isn't on PATH (so `git kitten` won't resolve yet).
case ":$PATH:" in
  *":$dest_dir:"*) ;;
  *)
    echo "note: $dest_dir is not on your PATH." >&2
    echo "      add it, e.g.:  export PATH=\"$dest_dir:\$PATH\"" >&2
    ;;
esac

echo "try: git kitten diff HEAD~1 HEAD"
