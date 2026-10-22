#!/bin/sh
# The guest's program for bootstrap-alpine.sh, stage "base": the Containerfile
# done by hand, in a kite guest that has a network and no podman. It runs as root in an
# Alpine guest and sees these mounts:
#   /ctl   (ro)  this script as run.sh, apk-info.txt (the packages the image must hold)
#   /ctx   (ro)  the context build.sh --stage-only staged: the three tarballs, inputs.sha256,
#                 ws/ and ext/ (niuv's sources), selftest.sh, builder-run, LICENSES.md
#   /base  (ro)  the pinned Alpine image's root, unpacked by `imagetree unpack`
#   /out   (rw)  gets tree.tar (the new root), records/ and log lines
#   /mnt/disk    (a --disk) where the long builds happen: the guest's own root is memory
# Every step stops the script (set -e). The tree it writes is the Alpine base, the
# runtime packages of the Containerfile, /opt/nim, /opt/otp, gleam, niuv, builder-run and
# builder-selftest; none of the build-only packages (perl, autoconf, *-dev, xz).
set -eu
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
say() { printf '== %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
W=/mnt/disk/work
T=/mnt/disk/tree
mkdir -p "$W" "$T" /out/records

say "inputs: sha256sum -c"
(cd /ctx && sha256sum -c inputs.sha256)

# name=version from the recorded list: the Alpine index drops old versions, and a newer
# musl-dev pulls a newer musl than the pinned base holds (seen 2026-10-22: musl-1.2.6-r3).
pin() { for n in "$@"; do grep -E "^$n-[0-9]" /ctl/apk-info.txt | sed "s/^$n-/$n=/"; done; }

say "build packages (this guest's own root, not the image)"
apk add --no-cache $(pin gcc musl-dev linux-headers make) xz build-base perl ncurses-dev openssl-dev zlib-dev autoconf >/dev/null
apk info -v | grep -E '^(gcc|musl-dev|linux-headers|make)-[0-9]' | tee /out/records/build-host-apk.txt

say "nim: csources build, koch boot"
cd "$W"
tar xf /ctx/nim-2.2.12.tar.xz
cd nim-2.2.12
sh build.sh >/dev/null
bin/nim c --skipUserCfg --skipParentCfg -d:release koch >/dev/null
./koch boot -d:release >/dev/null
mkdir -p /opt/nim
cp -R bin config lib copying.txt /opt/nim/
rm -f /opt/nim/bin/nim_dbg

say "otp: configure, make -j$(nproc), make install"
cd "$W"
tar xzf /ctx/otp_src_29.1.1.tar.gz
cd otp_src_29.1.1
./configure --prefix=/opt/otp --without-javac --without-wx --without-odbc \
    --without-debugger --without-observer --without-et >/dev/null
make -j"$(nproc)" >/dev/null
make install >/dev/null

say "niuv: nim c, as the Containerfile's niuv stage"
cp -R /ctx/ws /ws
cp -R /ctx/ext /ext
cd /ws/niuv
/opt/nim/bin/nim c -d:release --hints:off --mm:orc \
    --path:/ext/parsetoml-0.7.2 --path:/ext/results-0.5.1 --path:/ext/checksums-0.2.1 \
    -o:/niuv src/niuv.nim

say "tree: the base, then the runtime packages"
cp -a /base/. "$T"/
apk add --root "$T" --no-cache $(pin gcc musl-dev linux-headers make libcrypto3 ncurses-libs zlib libstdc++)
mkdir -p "$T/opt"
cp -a /opt/nim "$T/opt/nim"
cp -a /opt/otp "$T/opt/otp"
tar xzf /ctx/gleam-v1.19.1-aarch64-unknown-linux-musl.tar.gz -C "$T/usr/local/bin" gleam
install -m 755 /niuv "$T/usr/local/bin/niuv"
ln -s /opt/nim/bin/nim "$T/usr/local/bin/nim"
for b in erl erlc escript epmd; do ln -s "/opt/otp/bin/$b" "$T/usr/local/bin/$b"; done
install -m 755 /ctx/selftest.sh "$T/usr/local/bin/builder-selftest"
install -m 755 /ctx/builder-run "$T/usr/local/bin/builder-run"
mkdir -p "$T/usr/share/niuv-builder"
cp /ctx/LICENSES.md "$T/usr/share/niuv-builder/LICENSES.md"

say "records: what went in, written from the tree"
apk info -v --root "$T" | sort > "$T/usr/share/niuv-builder/apk-info.txt"
{ echo "nim: $("$T/opt/nim/bin/nim" -v | head -1)"
  echo "otp_version: $(cat "$T"/opt/otp/lib/erlang/releases/*/OTP_VERSION)"
  echo "erts: $(ls "$T/opt/otp/lib/erlang" | grep '^erts-')"
  echo "gleam: $("$T/usr/local/bin/gleam" --version)"; } > "$T/usr/share/niuv-builder/tools.txt"
( cd "$T" && for f in opt/nim/bin/nim usr/local/bin/gleam usr/local/bin/niuv \
      opt/otp/lib/erlang/erts-*/bin/beam.smp opt/otp/lib/erlang/erts-*/bin/erlexec; do sha256sum "$f"; done ) \
  > /out/records/exe-sha256.txt
cp "$T/usr/share/niuv-builder/apk-info.txt" "$T/usr/share/niuv-builder/tools.txt" /out/records/
if ! cmp -s /ctl/apk-info.txt "$T/usr/share/niuv-builder/apk-info.txt"; then
  echo "guest-base.sh: the installed packages differ from the recorded ones:" >&2
  diff /ctl/apk-info.txt "$T/usr/share/niuv-builder/apk-info.txt" >&2 || true
  exit 3
fi

say "tar of the tree"
tar -C "$T" -cf /out/tree.tar .
ls -l /out/tree.tar
say "done"
