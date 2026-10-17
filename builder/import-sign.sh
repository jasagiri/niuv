#!/bin/bash
# import-sign.sh --oci DIR --repo NAME --home DIR --key FILE --kite BIN --kite-sign BIN
# Puts the image of an OCI layout (podman save --format oci-dir) in kite's store
# under HOME and signs NAME@<manifest digest> with the key (ADR-KITE-0009,
# ADR-KITE-0010 IMP-01..05). Prints the image reference and the signature path.
#
# The key is a DEVELOPMENT key until the ceremony for the image key exists
# (fukai roadmap 118): the HOME's trust.json lists it under "dev_keys", so every
# run of the image prints kite's development-key warning. This script is not
# the ceremony and does not pretend to be.
set -euo pipefail
oci=""; repo=""; home=""; key=""; kite=""; sign=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --oci) oci=$2; shift 2 ;; --repo) repo=$2; shift 2 ;; --home) home=$2; shift 2 ;;
    --key) key=$2; shift 2 ;; --kite) kite=$2; shift 2 ;; --kite-sign) sign=$2; shift 2 ;;
    *) echo "import-sign.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
for v in oci repo home key kite sign; do
  [ -n "${!v}" ] || { echo "import-sign.sh: --${v//_/-} is required" >&2; exit 2; }
done
case "$repo" in */*) ;; *) echo "import-sign.sh: the name must contain a '/' (ADR-NIUV-0002)" >&2; exit 2 ;; esac
# index.json of a podman oci-dir holds one manifest descriptor: that is the digest.
digest=$(python3 -I -c '
import json, sys
idx = json.load(open(sys.argv[1] + "/index.json"))
m = idx["manifests"]
if len(m) != 1: sys.exit("index.json holds %d manifests, expected 1" % len(m))
print(m[0]["digest"])' "$oci")
echo "manifest: $digest"
HOME="$home" "$kite" import --layout:"$oci" --digest:"$digest"
sig="$home/${repo//\//_}.sig"
"$sign" image --key-file:"$key" --repo:"$repo" --digest:"$digest" --out:"$sig"
echo "image: $repo@$digest"
echo "signature: $sig"
