#!/bin/bash
# build.sh --out DIR [--tag NAME] [--stage-only] [--no-cache]
# Builds the builder image (ADR-NIUV-0002, NIV-32) with podman and writes it as
# an OCI layout to DIR/oci. Steps, each of which stops the script on failure:
#   1. fetch the upstream tarballs missing from DIR/dl and check ALL of them
#      against inputs.sha256 (verify-inputs.sh)
#   2. stage the build context in DIR/ctx: the tarballs, the sources of niuv and
#      its workspace siblings, the third-party sources checked against deps.tree
#   3. podman build (the Containerfile checks the tarballs a second time)
#   4. podman save --format oci-dir, and the records the image wrote about itself
# --stage-only stops after step 2. The signing is not here: the key is not
# niuv's (import-sign.sh takes it as an argument).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ws=$(cd "$here/../.." && pwd)   # foundation/
out=""; tag="localhost/niuv-builder-k4:latest"; stage_only=0; cache_flag=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --out) out=$2; shift 2 ;;
    --tag) tag=$2; shift 2 ;;
    --stage-only) stage_only=1; shift ;;
    --no-cache) cache_flag="--no-cache"; shift ;;
    *) echo "build.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$out" ] || { echo "build.sh: --out DIR is required (outside this repository)" >&2; exit 2; }
mkdir -p "$out"; out=$(cd "$out" && pwd)
# shellcheck source=inputs.env
. "$here/inputs.env"
record="$out/build-record.txt"
: > "$record"
note() { printf '%s\n' "$*" | tee -a "$record"; }
t0=$(date +%s)

# 1. upstream tarballs
mkdir -p "$out/dl"
fetch() { # file url
  [ -f "$out/dl/$1" ] || { note "fetching $2"; curl -fsSL -o "$out/dl/$1" "$2"; }
}
fetch "$NIM_FILE" "$NIM_URL"
fetch "$OTP_FILE" "$OTP_URL"
fetch "$GLEAM_FILE" "$GLEAM_URL"
"$here/verify-inputs.sh" "$out/dl" "$here/inputs.sha256" | tee -a "$record"

# 2. the context
ctx="$out/ctx"
rm -rf "$ctx"; mkdir -p "$ctx/ws" "$ctx/ext"
for f in "$NIM_FILE" "$OTP_FILE" "$GLEAM_FILE"; do cp "$out/dl/$f" "$ctx/$f"; done
cp "$here/inputs.sha256" "$here/Containerfile" "$here/selftest.sh" "$here/builder-run" "$here/LICENSES.md" "$ctx/"

mkdir -p "$ctx/ws/niuv/src"
rsync -a --exclude 'tests/' "$ws/niuv/src/niuv" "$ctx/ws/niuv/src/"
cp "$ws/niuv/src/niuv.nim" "$ctx/ws/niuv/src/"
cp "$ws/niuv/nim.cfg" "$ws/niuv/config.nims" "$ctx/ws/niuv/"
for p in nim-cbor-det nim-frames nim-fdio; do
  mkdir -p "$ctx/ws/$p"
  rsync -a "$ws/$p/src" "$ctx/ws/$p/"
  cp "$ws/$p/nim.cfg" "$ctx/ws/$p/"
done
note "== trees built into the image (recorded, not pinned: this is the source being built)"
for p in niuv nim-cbor-det nim-frames nim-fdio; do
  note "$(printf '%s  %s  jj:%s' "$("$here/tree-hash.sh" "$ctx/ws/$p" src)" "$p" \
    "$(jj log -R "$ws/$p" -r @- --no-graph -T 'commit_id.short()' 2>/dev/null || echo unknown)")"
done
jj st -R "$ws/niuv" >/dev/null 2>&1 && note "niuv working copy: $(jj diff -R "$ws/niuv" --stat 2>/dev/null | tail -1 | sed 's/^$/no changes/')"

cache="${NIMBLE_PKGCACHE:-$HOME/.nimble/pkgcache}"
while read -r want name dir sub rev; do
  case "$want" in ''|'#'*) continue ;; esac
  mkdir -p "$ctx/ext/$name"
  rsync -a "$cache/$dir/$sub" "$ctx/ext/$name/"
  got=$("$here/tree-hash.sh" "$ctx/ext/$name" "$sub")
  if [ "$got" != "$want" ]; then
    echo "build.sh: $name has tree hash $got, deps.tree says $want" >&2
    exit 1
  fi
  note "tree ok: $name $want (git $rev)"
done < "$here/deps.tree"
# `--path:/ext/results-0.5.1` must see results.nim at its root, and
# `--path:/ext/parsetoml-0.7.2` parsetoml.nim: the copied path is flattened.
for name in parsetoml-0.7.2 checksums-0.2.1; do
  mv "$ctx/ext/$name/src"/* "$ctx/ext/$name/" && rmdir "$ctx/ext/$name/src"
done

note "staged in $((`date +%s` - t0)) s"
[ "$stage_only" -eq 0 ] || { note "stopped after staging (--stage-only)"; exit 0; }

# 3. build
t1=$(date +%s)
podman build $cache_flag --platform linux/arm64 --build-arg "ALPINE_REF=$ALPINE_REF" \
  -t "$tag" -f "$ctx/Containerfile" "$ctx" 2>&1 | tee "$out/podman-build.log"
t2=$(date +%s)
note "podman build: $((t2 - t1)) s"

# 4. export and records
rm -rf "$out/oci"
podman save --format oci-dir -o "$out/oci" "$tag"
mkdir -p "$out/records"
podman run --rm "$tag" cat /usr/share/niuv-builder/apk-info.txt > "$out/records/apk-info.txt"
podman run --rm "$tag" cat /usr/share/niuv-builder/tools.txt > "$out/records/tools.txt"
podman run --rm "$tag" sh -c 'cd /; for f in opt/nim/bin/nim usr/local/bin/gleam usr/local/bin/niuv opt/otp/lib/erlang/erts-*/bin/beam.smp opt/otp/lib/erlang/erts-*/bin/erlexec; do sha256sum "$f"; done' > "$out/records/exe-sha256.txt"
note "image id: $(podman image inspect "$tag" --format '{{.Id}}')"
note "image size (podman): $(podman image inspect "$tag" --format '{{.Size}}') bytes"
note "total: $(( $(date +%s) - t0 )) s"
