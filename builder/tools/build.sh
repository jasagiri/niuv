#!/bin/bash
# tools/build.sh KITE_SRC OUT
# Compiles tools/imagetree.nim into OUT/imagetree. imagetree reads layers with
# kite's own code (oci/*), so it is built against the kite source tree
# KITE_SRC (foundation/kite-container) with the module paths that tree's
# nim.cfg and nimble.paths give. OUT and its nimcache are outside this
# repository.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src=${1:?KITE_SRC}; out=${2:?OUT}
paths=()
for cfg in "$src/nim.cfg" "$src/nimble.paths"; do
  while IFS= read -r line; do
    case $line in
      --path:*)
        p=${line#--path:}; p=${p//\"/}; p=${p//\$home/$HOME}
        case $p in /*) ;; *) p=$src/$p ;; esac
        paths+=("--path:$p") ;;
    esac
  done < "$cfg"
done
mkdir -p "$out/nimcache"
nim c -d:release --hints:off --mm:orc --threads:on --nimcache:"$out/nimcache/imagetree" \
  "${paths[@]}" -o:"$out/imagetree" "$here/imagetree.nim"
echo "built $out/imagetree"
