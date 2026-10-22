#!/bin/sh
# The guest's program for bootstrap-alpine.sh, stage "initrd": guest/Dockerfile of
# kite-container done by hand in an Alpine guest with a network. Mounts: /ctl (ro, this
# script as run.sh), /in (ro, kite-container's guest/ files init, udhcpc.script,
# nftables.conf), /out (rw, gets initramfs-kite.cpio.gz). Alpine 3.22 as the Dockerfile has it.
set -eu
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
printf 'https://dl-cdn.alpinelinux.org/alpine/v3.22/main\nhttps://dl-cdn.alpinelinux.org/alpine/v3.22/community\n' > /tmp/repos
rm -rf /guest; mkdir /guest
apk add --no-cache --root /guest --initdb --keys-dir /usr/share/apk/keys --repositories-file /tmp/repos \
    busybox-static e2fsprogs nftables
rm -rf /guest/var /guest/lib/apk /guest/etc/apk /guest/usr/share /guest/etc/nftables.d \
       /guest/usr/lib/python* /guest/etc/nftables.nft
mkdir -p /guest/dev /guest/proc /guest/sys /guest/ro /guest/rw /guest/newroot /guest/etc /guest/tmp
cp /in/init /guest/init
cp /in/udhcpc.script /guest/etc/udhcpc.script
cp /in/nftables.conf /guest/etc/kite-nftables.conf
chmod 755 /guest/init /guest/etc/udhcpc.script
cd /guest && find . | /bin/busybox cpio -o -H newc | gzip -9 > /out/initramfs-kite.cpio.gz
