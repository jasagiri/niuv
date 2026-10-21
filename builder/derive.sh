#!/bin/bash
# derive.sh --home DIR --base NAME@sha256:D --niuv FILE --out DIR --repo NAME
#           --kite BIN --kite-sign BIN --key FILE --imagetree BIN
# Makes the next builder image from the one before it, without podman
# (ADR-NIUV-0002, "K5 の続き"): the base image's root is unpacked by kite's own
# reader, three files are replaced, and `kite pack` makes the one-layer image.
#   /usr/local/bin/niuv        FILE (a niuv built for aarch64-linux-musl, by the
#                              base image's niuv or by a host, then locked)
#   /usr/local/bin/builder-run builder/builder-run (the host name, see there)
#   /etc/hosts                 the same name on its 127.0.0.1 line
# Everything else is the base, byte for byte. Each step stops the script on failure:
#   1. unpack the base from the store of HOME into OUT/tree and list it
#   2. replace the three files, list the tree again, and require that the two
#      lists differ in those three paths and nowhere else
#   3. `kite pack` twice, into OUT/layout-1 and OUT/layout-2, and require the
#      same manifest digest (PCK-19)
#   4. `kite import` the layout, unpack the image from the store and require
#      that its list is the list of step 2 (what was packed is what is in the image)
#   5. sign REPO@digest with the key (the development key: fukai roadmap 118)
# It prints the image reference and the signature file. OUT/records/ holds the
# lists and the SHA-256 of the three files. The unpacked trees are removed at
# the end (--keep-trees keeps them); the layout stays for `kite import` elsewhere.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
home=""; base=""; niuv=""; out=""; repo=""; kite=""; sign=""; key=""; tool=""; keep=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --home) home=$2; shift 2 ;; --base) base=$2; shift 2 ;; --niuv) niuv=$2; shift 2 ;;
    --out) out=$2; shift 2 ;; --repo) repo=$2; shift 2 ;; --kite) kite=$2; shift 2 ;;
    --kite-sign) sign=$2; shift 2 ;; --key) key=$2; shift 2 ;; --imagetree) tool=$2; shift 2 ;;
    --keep-trees) keep=1; shift ;;
    *) echo "derive.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
for v in home base niuv out repo kite sign key tool; do
  [ -n "${!v}" ] || { echo "derive.sh: --${v//_/-} is required" >&2; exit 2; }
done
case "$repo" in */*) ;; *) echo "derive.sh: the name must contain a '/' (ADR-NIUV-0002)" >&2; exit 2 ;; esac
case "$base" in *@sha256:*) ;; *) echo "derive.sh: --base is NAME@sha256:DIGEST" >&2; exit 2 ;; esac
digest_base=${base#*@}
host=niuv-builder
grep -q "^hostname $host || " "$here/builder-run" \
  || { echo "derive.sh: builder-run does not set the host name $host" >&2; exit 1; }
[ -f "$niuv" ] || { echo "derive.sh: $niuv is not a file" >&2; exit 2; }
[ ! -e "$out" ] || { echo "derive.sh: $out exists" >&2; exit 2; }
mkdir -p "$out/records"
tree=$out/tree
at() { printf '%s\n' "$*" >&2; }

# 1
HOME=$home "$tool" unpack "$digest_base" "$tree"
"$tool" list "$tree" > "$out/records/list-base.txt"
for p in usr/local/bin/niuv usr/local/bin/builder-run etc/hosts; do
  [ -f "$tree/$p" ] && [ ! -L "$tree/$p" ] || { echo "derive.sh: the base has no regular file /$p" >&2; exit 1; }
done
hosts_old=$(cat "$tree/etc/hosts")
case "$hosts_old" in *"$host"*) echo "derive.sh: the base's /etc/hosts already names $host" >&2; exit 1 ;; esac
# the IPv4 line gets the name; there must be exactly one such line
n=$(grep -c '^127\.0\.0\.1[[:space:]]' "$tree/etc/hosts" || true)
[ "$n" = 1 ] || { echo "derive.sh: /etc/hosts has $n lines for 127.0.0.1, expected 1" >&2; exit 1; }

# 2
chmod u+w "$tree/etc" "$tree/usr/local/bin" "$tree/etc/hosts" "$tree/usr/local/bin/niuv" "$tree/usr/local/bin/builder-run"
sed "s/^\(127\.0\.0\.1[[:space:]].*\)\$/\1 $host/" "$tree/etc/hosts" > "$out/hosts.new"
cp "$out/hosts.new" "$tree/etc/hosts"; chmod 644 "$tree/etc/hosts"
cp "$here/builder-run" "$tree/usr/local/bin/builder-run"; chmod 755 "$tree/usr/local/bin/builder-run"
cp "$niuv" "$tree/usr/local/bin/niuv"; chmod 755 "$tree/usr/local/bin/niuv"
rm "$out/hosts.new"
"$tool" list "$tree" > "$out/records/list-derived.txt"
diff "$out/records/list-base.txt" "$out/records/list-derived.txt" > "$out/records/diff-base-derived.txt" || true
changed=$(grep '^[<>]' "$out/records/diff-base-derived.txt" | awk '{print $NF}' | sort -u | tr '\n' ' ')
[ "$changed" = "/etc/hosts /usr/local/bin/builder-run /usr/local/bin/niuv " ] \
  || { echo "derive.sh: the lists differ in [$changed], expected exactly the three files" >&2; exit 1; }
at "step 2: only /etc/hosts, /usr/local/bin/builder-run and /usr/local/bin/niuv differ from the base ($(wc -l < "$out/records/list-base.txt") entries)"
{ (cd "$tree" && shasum -a 256 usr/local/bin/niuv usr/local/bin/builder-run etc/hosts); } > "$out/records/replaced-sha256.txt"

# 3
d1=$("$kite" pack --root:"$tree" --layout:"$out/layout-1" --name:"$repo" 2> "$out/records/pack-1.log")
d2=$("$kite" pack --root:"$tree" --layout:"$out/layout-2" --name:"$repo" 2> "$out/records/pack-2.log")
[ "$d1" = "$d2" ] || { echo "derive.sh: two packs of one tree gave $d1 and $d2" >&2; exit 1; }
at "step 3: two packs of the same tree: $d1 both times"
rm -rf "$out/layout-2"

# 4
HOME=$home "$kite" import --layout:"$out/layout-1" --digest:"$d1" > "$out/records/import.log" 2>&1 \
  || { cat "$out/records/import.log" >&2; exit 1; }
HOME=$home "$tool" unpack "$d1" "$out/tree-image"
"$tool" list "$out/tree-image" > "$out/records/list-image.txt"
cmp -s "$out/records/list-derived.txt" "$out/records/list-image.txt" \
  || { echo "derive.sh: the image differs from the tree it was packed from:" >&2
       diff "$out/records/list-derived.txt" "$out/records/list-image.txt" | head -20 >&2; exit 1; }
at "step 4: the image holds the tree: $(wc -l < "$out/records/list-image.txt") entries, no difference"
if [ "$keep" = 0 ]; then chmod -R u+w "$tree" "$out/tree-image"; rm -rf "$tree" "$out/tree-image"; fi

# 5
sig=$home/${repo//\//_}.sig
"$sign" image --key-file:"$key" --repo:"$repo" --digest:"$d1" --out:"$sig"
echo "image: $repo@$d1"
echo "signature: $sig"
