#!/bin/bash
# bootstrap-alpine.sh [--site DIR] STAGE...
# Makes the whole scaffold the builder image needs, without podman and without a
# temporary directory (ADR-NIUV-0002, "作り直し (2026-10-22)"). Everything lives under
# SITE (default ~/.local/share/godsgolem/kite-site, mode 0700), which no repository holds.
# The stages, in order; each stops the script on failure and can be run again
# (a finished product is not made twice: remove it to make it again):
#   site      the directories, the development key (keys/dev-key.hex, 0600), trust.json
#   kite      kite and kite_sign, built from a COMMITTED version of kite-container
#             (KITE_REV, default @-): the working copy of that repository is not read.
#             They go to SITE/bin-<first 8 of the commit>/ (the directory holds `kite`, the name
#             niuv looks for on PATH) and the source to SITE/src/kite-container-<8>/, so that a
#             newer kite never overwrites the one an earlier run used; a finished one is not built again
#   assets    the kernels and the Alpine image (pulled by digest from inputs.env), signed
#   initrd    SITE/assets/initramfs-kite-<8>, made from the guest/ of that same kite-container
#             commit by bootstrap/guest-initrd.sh in an Alpine guest that has a network (the init
#             has to be the one of the kite that runs it: `--clock-offset` is read by it)
#   base      the first builder image niuv/builder-base: the Containerfile's content, made by
#             bootstrap/guest-base.sh in an Alpine guest that has a network, packed with kite pack
#   builder   niuv built in that image's guest (niuv build niuv --in-builder) and derive.sh:
#             niuv/builder, the image `[builder]` pins; prints its digest
#   site-env  writes SITE/site.env for services/island-node/image (kite, initramfs and the kernel
#             with AF_VSOCK of the commit chosen by the stage "kite")
# The network is open only in the guests of "initrd" and "base" (and kite's own pull of the
# Alpine image by digest); every download is checked against a SHA-256 or a digest.
# The key is a DEVELOPMENT key (fukai roadmap 118): the ceremony does not exist.
# A kernel with nf_tables is needed for --net (kite's init loads a firewall), and AF_VSOCK for
# the island guests (ADR-IND-0002): NET_KERNEL_SRC names it (default:
# kite-container/build/assets/Image-vsock), and it is kept as SITE/assets/Image-vsock; the builder
# guests use Image-custom (KERNEL_SRC).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
found=$(cd "$here/../.." && pwd)
site=$HOME/.local/share/godsgolem/kite-site
kite_rev=${KITE_REV:-@-}
kite_repo=${KITE_REPO:-$found/kite-container}
kernel_src=${KERNEL_SRC:-$kite_repo/build/assets/Image-custom}
net_kernel_src=${NET_KERNEL_SRC:-$kite_repo/build/assets/Image-vsock}
if [ "${1:-}" = --site ]; then site=$2; shift 2; fi
[ "$#" -gt 0 ] || { sed -n '2,/^set -euo/p' "$0" | sed '$d' >&2; exit 2; }
# shellcheck source=inputs.env
. "$here/inputs.env"
umask 077
S=$site
KEY=$S/keys/dev-key.hex; HOME_K=$S/home
W=$S/work
# The kite of the commit the stage "kite" built last (SITE/kite-commit.txt names it): its
# directory (the binary must be called `kite`), kite_sign, its source and its initramfs.
select_kite() {
  [ -f "$S/kite-commit.txt" ] || { echo "bootstrap-alpine.sh: no kite-commit.txt: run the stage kite first" >&2; exit 1; }
  kite_short=$(cut -c1-8 "$S/kite-commit.txt")
  KITE_DIR=$S/bin-$kite_short; KITE=$KITE_DIR/kite; SIGN=$KITE_DIR/kite_sign
  KSRC=$S/src/kite-container-$kite_short
  INITRD=$S/assets/initramfs-kite-$kite_short
}
k() { HOME=$HOME_K "$KITE" "$@"; }
alpine_index=${ALPINE_REF##*@}

# guest NAME KERNEL INITRD IMAGE SIG CTL OUT [kite run args...]: one guest, one job (/ctl/run.sh)
guest() {
  local n=$1 kern=$2 ird=$3 img=$4 sig=$5 ctl=$6 out=$7; shift 7
  rm -rf "$HOME_K/.kite/runs/$n"
  k run --id:"$n" --image:"$img" --signature:"$sig" --kernel:"$kern" --initrd:"$ird" \
    --cmdline:init=/usr/local/bin/builder-run --exit-status \
    --mount:"$ctl":/ctl:ro --mount:"$out":/out:rw "$@" </dev/null
  rm -rf "$HOME_K/.kite/runs/$n"
}

stage_site() {
  mkdir -p "$S"/{src,bin,home/.config/kite,home/.kite,assets,work,keys,stage,island-work}
  chmod 700 "$S" "$S/keys"
  [ -f "$KEY" ] || { openssl rand -hex 32 > "$KEY"; chmod 600 "$KEY"; }
}
stage_kite() {
  local full short
  # jj prints paths relative to the current directory: work from the repository's root
  full=$(cd "$kite_repo" && jj log --ignore-working-copy -r "$kite_rev" --no-graph -T 'commit_id')
  short=${full:0:8}
  local src=$S/src/kite-container-$short
  KITE_DIR=$S/bin-$short; KITE=$KITE_DIR/kite; SIGN=$KITE_DIR/kite_sign
  mkdir -p "$KITE_DIR"
  if [ ! -x "$KITE" ] || [ ! -x "$SIGN" ]; then
    rm -rf "$src"; mkdir -p "$src"
    ( cd "$kite_repo"
      jj file list --ignore-working-copy -r "$kite_rev" | while IFS= read -r f; do
        mkdir -p "$src/$(dirname "$f")"
        jj file show --ignore-working-copy -r "$kite_rev" "$f" > "$src/$f"
      done )
    # nimble.paths is not committed (it names this machine's nimble packages)
    cp "$kite_repo/nimble.paths" "$src/"
    for p in nim-virtio nim-fdt nim-outcome ig-verify nim-propcheck nim-cose-sign1 nim-cbor-det \
             nim-hpke nim-secret nim-mlkem nim-vendor-lib; do ln -sfn "$found/$p" "$S/src/$p"; done
    (cd "$src" && nim c --hints:off -d:release -o:"$KITE" src/kite.nim \
       && nim c --hints:off -d:release -o:"$SIGN" tools/kite_sign.nim \
       && codesign --entitlements entitlements.plist --force -s - "$KITE")
  fi
  echo "$full" > "$S/kite-commit.txt"
  select_kite
  "$KITE" version
  local pub; pub=$("$SIGN" pubkey --key-file:"$KEY")
  python3 -I -c '
import json, sys
e = json.loads(sys.argv[1]); e["name"] = "godsgolem-kite-site-dev"
print(json.dumps({"keys": [], "dev_keys": [e]}))' "$pub" > "$HOME_K/.config/kite/trust.json"
  bash "$here/tools/build.sh" "$KSRC" "$W/tools"
  echo "kite commit: $(cat "$S/kite-commit.txt")"
}
stage_assets() {
  [ -f "$S/assets/Image-custom" ] || cp "$kernel_src" "$S/assets/Image-custom"
  [ -f "$S/assets/Image-vsock" ] || cp "$net_kernel_src" "$S/assets/Image-vsock"
  for f in Image-custom Image-vsock; do "$SIGN" boot --key-file:"$KEY" --role:kernel --file:"$S/assets/$f"; done
  shasum -a 256 "$S/assets/Image-custom" "$S/assets/Image-vsock" | tee "$S/assets/kernels.sha256"
  mkdir -p "$W/boot"
  "$SIGN" image --key-file:"$KEY" --repo:library/alpine --digest:"$alpine_index" --out:"$W/boot/alpine.sig"
  k pull --image:alpine@"$alpine_index" --signature:"$W/boot/alpine.sig"
}
# The platform manifest of the pinned Alpine index (arm64), for imagetree
alpine_manifest() {
  python3 -I -c '
import json, sys
for m in json.load(open(sys.argv[1]))["manifests"]:
    if m["platform"]["architecture"] == "arm64": print(m["digest"])' "$HOME_K/.kite/blobs/sha256/${alpine_index#sha256:}"
}
# A first image to start the network guests in: the pinned Alpine plus builder-run.
stage_boot_image() {
  [ -f "$W/boot/bootstrap-alpine.digest" ] && return
  rm -rf "$W/boot-tree" "$W/boot-layout"
  HOME=$HOME_K "$W/tools/imagetree" unpack "$(alpine_manifest)" "$W/boot-tree"
  chmod -R u+w "$W/boot-tree"
  mkdir -p "$W/boot-tree/usr/local/bin"
  install -m 755 "$here/builder-run" "$W/boot-tree/usr/local/bin/builder-run"
  d=$("$KITE" pack --root:"$W/boot-tree" --layout:"$W/boot-layout" --name:niuv/bootstrap-alpine 2>/dev/null)
  k import --layout:"$W/boot-layout" --digest:"$d"
  "$SIGN" image --key-file:"$KEY" --repo:niuv/bootstrap-alpine --digest:"$d" --out:"$W/boot/bootstrap-alpine.sig"
  echo "$d" > "$W/boot/bootstrap-alpine.digest"
}
# The first initramfs has to come from somewhere that already runs guests: a guest needs an
# initramfs to start in, and this one is made in a guest. The bootstrap one is the old
# one if the site has it, else kite-container's own build/assets/initramfs-kite.
stage_initrd() {
  stage_boot_image
  local boot=$W/boot/bootstrap-initramfs-kite
  [ -f "$boot" ] || cp "${BOOT_INITRD:-$kite_repo/build/assets/initramfs-kite}" "$boot"
  "$SIGN" boot --key-file:"$KEY" --role:initrd --file:"$boot"
  rm -rf "$W/ctl-initrd" "$W/out-initrd" "$W/in-initrd"; mkdir -p "$W/ctl-initrd" "$W/out-initrd" "$W/in-initrd"
  cp "$here/bootstrap/guest-initrd.sh" "$W/ctl-initrd/run.sh"
  cp "$KSRC/guest/"{init,udhcpc.script,nftables.conf} "$W/in-initrd/"
  guest initrd-1 "$S/assets/Image-vsock" "$boot" "niuv/bootstrap-alpine@$(cat "$W/boot/bootstrap-alpine.digest")" \
    "$W/boot/bootstrap-alpine.sig" "$W/ctl-initrd" "$W/out-initrd" --memory:2048 --cpu:2 --net --mount:"$W/in-initrd":/in:ro
  [ ! -e "$INITRD" ] || { echo "bootstrap-alpine.sh: $INITRD exists: remove it to make it again" >&2; exit 1; }
  cp "$W/out-initrd/initramfs-kite.cpio.gz" "$INITRD"
  "$SIGN" boot --key-file:"$KEY" --role:initrd --file:"$INITRD"
  gunzip -c "$INITRD" | grep -aq 'kite.clock' || { echo "bootstrap-alpine.sh: the initramfs does not read kite.clock (--clock-offset): the guest/init of $kite_short is older than ADR-KITE-0013" >&2; exit 1; }
  shasum -a 256 "$INITRD"
}
stage_base() {
  stage_boot_image
  local boot=$W/boot/bootstrap-initramfs-kite
  rm -rf "$W/builder-stage" "$W/ctl-base" "$W/out-base" "$W/alpine-base" "$W/base-tree"
  mkdir -p "$W/ctl-base" "$W/out-base"
  "$here/build.sh" --out "$W/builder-stage" --stage-only
  HOME=$HOME_K "$W/tools/imagetree" unpack "$(alpine_manifest)" "$W/alpine-base"
  cp "$here/bootstrap/guest-base.sh" "$W/ctl-base/run.sh"
  # RECORDED_APK: the list the image must hold. Alpine's index drops old versions: when it does,
  # copy records/apk-info.txt, change the versions that are gone, and say so in the ADR.
  cp "${RECORDED_APK:-$here/records/apk-info.txt}" "$W/ctl-base/apk-info.txt"
  guest base-1 "$S/assets/Image-vsock" "$boot" "niuv/bootstrap-alpine@$(cat "$W/boot/bootstrap-alpine.digest")" \
    "$W/boot/bootstrap-alpine.sig" "$W/ctl-base" "$W/out-base" --memory:12288 --cpu:6 --net --disk:24G \
    --mount:"$W/builder-stage/ctx":/ctx:ro --mount:"$W/alpine-base":/base:ro
  mkdir -p "$W/base-tree"
  tar -xf "$W/out-base/tree.tar" -C "$W/base-tree"
  chmod -R u+w "$W/base-tree"
  local d1 d2
  d1=$("$KITE" pack --root:"$W/base-tree" --layout:"$W/bl-1" --name:niuv/builder-base 2>/dev/null)
  d2=$("$KITE" pack --root:"$W/base-tree" --layout:"$W/bl-2" --name:niuv/builder-base 2>/dev/null)
  [ "$d1" = "$d2" ] || { echo "bootstrap-alpine.sh: two packs of one tree gave $d1 and $d2" >&2; exit 1; }
  k import --layout:"$W/bl-1" --digest:"$d1"
  "$SIGN" image --key-file:"$KEY" --repo:niuv/builder-base --digest:"$d1" --out:"$HOME_K/niuv_builder-base.sig"
  echo "$d1" > "$W/base.digest"
  rm -rf "$W/bl-1" "$W/bl-2"
  echo "base image: niuv/builder-base@$d1"
}
stage_builder() {
  local base; base=niuv/builder-base@$(cat "$W/base.digest")
  local ws=$W/ws-niuv
  rm -rf "$ws"; mkdir -p "$ws/decls"
  for p in nim-cbor-det nim-frames nim-fdio; do
    mkdir -p "$ws/decls/$p"
    printf '[package]\nname = "%s"\nversion = "0.1.0"\nlicense = "Apache-2.0"\nroot = "%s/%s"\n\n[nim]\n' "$p" "$found" "$p" > "$ws/decls/$p/niuv.toml"
  done
  printf '\n[dependencies]\nworkspace = ["nim-cbor-det", "nim-fdio"]\n' >> "$ws/decls/nim-frames/niuv.toml"
  # members are relative to the workspace file
  local rel; rel=$(python3 -I -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$found/niuv" "$ws")
  printf '[workspace]\nmembers = ["decls/nim-cbor-det", "decls/nim-frames", "decls/nim-fdio", "%s"]\n[external]\nroots = ["~/.nimble/pkgcache"]\n[tools.nim]\nversion = "2.2.12"\n[tools.gleam]\nversion = "1.19.1"\n[tools.erlang]\nversion = "29.1.1"\n[tools.kite]\nversion = "0.2.0"\n' "$rel" > "$ws/niuv.workspace.toml"
  # the host niuv, from the repository's last commit (the working copy is read as it is)
  mkdir -p "$W/nimcache"
  (cd "$found/niuv" && nim c -d:release --hints:off --mm:orc --nimcache:"$W/nimcache/niuv" -o:"$S/bin/niuv" src/niuv.nim)
  mkdir -p "$S/home/.nimble" "$S/hex/hexpm"
  rsync -a "$HOME/.nimble/pkgcache" "$S/home/.nimble/"
  rsync -a "$HOME/Library/Caches/gleam/hex/hexpm/packages" "$S/hex/hexpm/"
  local g=(--signature "$HOME_K/niuv_builder-base.sig" --kernel "$S/assets/Image-custom" --initrd "$INITRD" --hex-cache "$S/hex/hexpm/packages" --stage "$S/stage")
  ( cd "$ws" && PATH=$S/bin:$PATH "$S/bin/niuv" lock --workspace "$ws/niuv.workspace.toml"
    export HOME=$HOME_K PATH=$S/bin:$PATH
    "$S/bin/niuv" lock --workspace "$ws/niuv.workspace.toml" --target aarch64-linux-musl --in-builder --builder "$base" "${g[@]}"
    rm -rf "$W/niuv-linux"
    "$S/bin/niuv" build niuv --workspace "$ws/niuv.workspace.toml" --target aarch64-linux-musl --in-builder "${g[@]}" --out "$W/niuv-linux" )
  rm -rf "$W/derive"
  "$here/derive.sh" --home "$HOME_K" --base "$base" --niuv "$W/niuv-linux/niuv" --out "$W/derive" --repo niuv/builder \
    --kite "$KITE" --kite-sign "$SIGN" --key "$KEY" --imagetree "$W/tools/imagetree" | tee "$W/derive.out"
}
stage_site_env() {
  # the builder image: what the stage "builder" printed, else what the site file already pins
  # (this stage can be run alone to point the site at another kite)
  local image=
  [ ! -f "$W/derive.out" ] || image=$(sed -n 's/^image: //p' "$W/derive.out")
  if [ -z "$image" ] && [ -f "$S/site.env" ]; then
    image=$(sed -n "s/^BUILDER_IMAGE='\(.*\)'\$/\1/p" "$S/site.env")
  fi
  [ -n "$image" ] || { echo "bootstrap-alpine.sh: no builder image: run the stage builder first" >&2; exit 1; }
  cat > "$S/site.env" <<ENV
# Written by bootstrap-alpine.sh; see services/island-node/image/site.env.example.
KITE=$KITE
KITE_SIGN=$SIGN
KITE_SRC=$KSRC
NIUV=$S/bin/niuv
KITE_HOME=$S/home
BUILDER_IMAGE='$image'
BUILDER_SIG=$S/home/niuv_builder.sig
KERNEL=$S/assets/Image-vsock
INITRD=$INITRD
HEX_CACHE=$S/hex/hexpm/packages
STAGE=$S/stage
KEY_FILE=$S/keys/dev-key.hex
WORK=$S/island-work
ENV
  chmod 600 "$S/site.env"
}
for st in "$@"; do
  case "$st" in
    site|kite) ;;
    *) select_kite ;;
  esac
  case "$st" in
    site) stage_site ;; kite) stage_kite ;; assets) stage_assets ;; initrd) stage_initrd ;;
    base) stage_base ;; builder) stage_builder ;; site-env) stage_site_env ;;
    all) stage_site; stage_kite; stage_assets; stage_initrd; stage_base; stage_builder; stage_site_env ;;
    *) echo "bootstrap-alpine.sh: unknown stage $st" >&2; exit 2 ;;
  esac
done
