#!/bin/sh
# tree-hash.sh DIR [PATH...]
# The sha256 of the sorted "<file sha256>  <relative path>" lines of the
# regular files under DIR (or only under the PATHs given, relative to DIR).
set -eu
dir=$1; shift
[ "$#" -gt 0 ] || set -- .
cd "$dir"
for p in "$@"; do find "$p" -type f; done | sed 's|^\./||' | LC_ALL=C sort |
  while read -r f; do printf '%s  %s\n' "$(shasum -a 256 "$f" | cut -d' ' -f1)" "$f"; done |
  shasum -a 256 | cut -d' ' -f1
