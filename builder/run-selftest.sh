#!/bin/bash
# run-selftest.sh --home DIR --image REPO@DIGEST --signature FILE --kite BIN
#                 --kernel FILE --initrd FILE --source DIR --out DIR [--memory MB] [--cpu N]
# Starts the builder image in a kite guest with no network: SOURCE read-only at
# /work, OUT read-write at /out, builder-selftest as the guest's program, and
# prints kite's exit status (--exit-status) and OUT/selftest.txt. Exits with the
# guest program's status.
set -uo pipefail
home=""; image=""; sig=""; kite=""; kernel=""; initrd=""; src=""; out=""; mem=1024; cpu=2
while [ "$#" -gt 0 ]; do
  case "$1" in
    --home) home=$2; shift 2 ;; --image) image=$2; shift 2 ;; --signature) sig=$2; shift 2 ;;
    --kite) kite=$2; shift 2 ;; --kernel) kernel=$2; shift 2 ;; --initrd) initrd=$2; shift 2 ;;
    --source) src=$2; shift 2 ;; --out) out=$2; shift 2 ;; --memory) mem=$2; shift 2 ;; --cpu) cpu=$2; shift 2 ;;
    *) echo "run-selftest.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
id="niuv-builder-k4-$$"
rm -f "$out/selftest.txt"
HOME="$home" "$kite" run --id:"$id" --image:"$image" --signature:"$sig" --kernel:"$kernel" --initrd:"$initrd" \
  --memory:"$mem" --cpu:"$cpu" --cmdline:init=/usr/local/bin/builder-selftest --exit-status \
  --mount:"$src":/work:ro --mount:"$out":/out:rw </dev/null
code=$?
echo "kite exit status: $code"
cat "$out/selftest.txt" 2>/dev/null || echo "no selftest.txt in $out"
exit "$code"
