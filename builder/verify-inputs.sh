#!/bin/sh
# verify-inputs.sh DIR HASHFILE
# Every line of HASHFILE is "<sha256 hex>  <name>"; the file DIR/<name> must
# exist and hash to that value. Stops (exit 1) on the first file that does not,
# and prints which one. Nothing is skipped: a missing file is a failure.
set -eu
[ "$#" -eq 2 ] || { echo "usage: verify-inputs.sh DIR HASHFILE" >&2; exit 2; }
dir=$1; list=$2
[ -s "$list" ] || { echo "verify-inputs: '$list' is missing or empty" >&2; exit 2; }
n=0
while read -r want name; do
  [ -n "$want" ] || continue
  [ -f "$dir/$name" ] || { echo "verify-inputs: $dir/$name is missing" >&2; exit 1; }
  got=$(shasum -a 256 "$dir/$name" | cut -d' ' -f1)
  if [ "$got" != "$want" ]; then
    echo "verify-inputs: $name has sha256 $got, the list says $want" >&2
    exit 1
  fi
  n=$((n + 1))
done < "$list"
echo "verify-inputs: $n files match $list"
