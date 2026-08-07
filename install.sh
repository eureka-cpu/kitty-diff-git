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
dest_dir="${PREFIX:-$HOME/.local/bin}"

[ -f "$src" ] || {
  echo "install: cannot find git-kitten next to this script ($src)" >&2
  exit 1
}

mkdir -p -- "$dest_dir"
cp -- "$src" "$dest_dir/git-kitten"
chmod +x "$dest_dir/git-kitten" # no `--`: BSD/macOS chmod rejects it
echo "installed: $dest_dir/git-kitten"

# Warn if the destination isn't on PATH (so `git kitten` won't resolve yet).
case ":$PATH:" in
  *":$dest_dir:"*) ;;
  *)
    echo "note: $dest_dir is not on your PATH." >&2
    echo "      add it, e.g.:  export PATH=\"$dest_dir:\$PATH\"" >&2
    ;;
esac

echo "try: git kitten diff HEAD~1 HEAD"
