# The image of 2026-10-17 (K4-1)

What the build of the image signed on 2026-10-17 produced. Written by hand from
`build.sh`'s `build-record.txt` and the commands under "Checked"; it describes
this one build, not the recipe.

| | |
|---|---|
| Built with | podman 6.1.1, applehv VM (4 CPU, 6 GiB), `--platform linux/arm64`, `--no-cache` |
| Base | `docker.io/library/alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6` |
| Manifest digest (what is signed) | `sha256:f5d5b3c2185a6a248e92e86e8f0187a1dce99a6011d3f7c45498f9f2cc8b2c9d` |
| Config digest (podman image id) | `sha256:aea744fdd9eb0460bfc9aebcfc90c96de82f5227deb77d1b90c2644943e924db` |
| Name given to kite and to `kite_sign` | `niuv/builder-k4` |
| Layers | 11, all `application/vnd.oci.image.layer.v1.tar+gzip` |
| Size | 403,273,456 bytes in podman; 173,618,888 bytes of compressed layers |
| `podman build` (cold cache) | 397 s; `build.sh` total 402 s (an earlier build with the Nim and OTP stages cold: 327 s) |
| Guest run (`run-selftest.sh`) | 108 s wall, kite exit status 0 |
| Signed by | the development key `niuv-builder-dev-k4` (kid `a142bf03c29261d72646cd10c7b30965`) in kite's `dev_keys`. Not a release key: the ceremony for the image key (fukai roadmap 118) does not exist yet. The private key is not in this repository. |

Layer digests, in order:

```
sha256:6810d3b3ec9e5bac56e042757a1261b2e40a39120d0076640b5ce0f191fe96b1  4287571   (Alpine base)
sha256:c69cb718513f680e8ee611b07d2417bc6ed7fd11c591891bbdd660afc2bc6045  70179669
sha256:b093080a3543f9742e8d96628ada2d42c165c9b1819e333133ee67064c8add0f  5005252
sha256:49e4791e56caa810617d43fd7e2ead78683fe0025ded86441effe558230a8cf2  69848708
sha256:ccde29f4b1806f159b148b1b908fa308209a15bc4a8c268bd93d2b514c32701f  10124558
sha256:18ea8fd8091bc5e7d71167af87b3b434a1a3a31ef22a190e854df698f9dfbb3b  10765133
sha256:e60470883b6198dd87af0f56c314f686b806a61cd2e7933d7a901090bf2e6ee0  367647
sha256:04c9bcc2e734b73900567b946ee20b80aced30b0b7f7fed6b9bd005c1c87d307  257
sha256:41fb1972487379b324bf30c2498621770d498a51c5e33f47d7d3f5a7b3884907  1309
sha256:2a7debf7e9f0ac8736698df5c9ccfd39b4141ccb6027d275f81e13c9a9d9b947  757
sha256:2c938152af9d3b80cd0ea2d4503ba8989da11763848d8871b97682a8f7b56f25  3038027
```

Another build from the same inputs gave a different manifest digest
(`sha256:e0c8fb16…`): layers carry times. The pin is the digest of one image,
not a recipe that reproduces it.

Built-in sources (not pinned; the source being built): niuv tree
`fdbb8903…` (jj `aa0df53c3b7e`), nim-cbor-det `f0fc1d28…` (`24e7fd823db6`),
nim-frames `ff7490d0…` (`2cfd9b6ea875`), nim-fdio `2284b43d…` (`90fe2f818464`).
The third-party trees are pinned in `../deps.tree`.

## Checked

- `records/selftest.txt`: every check `ok`, `RESULT ok`, from the guest with no network (`ls /sys/class/net` is `lo`), `/work` read-only, `/out` writable.
- `records/tools.txt`, `records/apk-info.txt`, `records/exe-sha256.txt`: written from the image.
- An input list with one hex digit changed: `verify-inputs.sh` exits 1 (`test/test_verify.sh`); `podman build --target inputs` fails at `sha256sum -c` (`nim-2.2.12.tar.xz: FAILED`).
- `kite run` with an image digest that differs from the signed one: `PIN-08 … the signature is valid but vouches for something else`.

## Not checked

The tarballs' sigstore bundles (no `cosign` here; Future), `niuv`'s own test
suite in the guest (K4-3), offline `gleam` (K4-3), that `erlc` writes the same
bytes as the host's OTP 29.1.1 (K4-4), that the image can be rebuilt to the
same digest (not promised).

## The image of K4-2 (2026-10-17): K4-1's image plus the entry `builder-run`

K4-2 needs the image to start a program that reads its job from a mount
(kite starts only a program that is in the image). The recipe gained
`builder-run` (`COPY --chmod=755`), the image was built again, imported and
signed with the same development key. The first build of it had `builder-run`
without the execute bit (`chroot: can't execute … Permission denied`, exit
126); the digests below are of the second build.

| | |
|---|---|
| Manifest digest (what `[builder]` pinned in K4-2; superseded by the K4-3 image below) | `sha256:0f5f221a3ade5f25e9ccf6f5d72adc8980efd90279ea0683adfb77fb604c0287` |
| Config digest (podman image id) | `sha256:076219468308d986b40440cdb4df075b0e666f952996ce8512debcd5d0eb1272` |
| Name given to kite and to `kite_sign` | `niuv/builder-k4` (same key, same warning on every run) |
| Built with | podman 6.1.1, cache on (the first K4-2 build: `podman build` 539 s, `build.sh` 546 s; the second: 12 s) |
| Trees built in (recorded, not pinned) | niuv `9b401c3e…` (jj `9739b1762e7c`, working copy 6 files changed: the kite version probe, tests and this recipe), nim-cbor-det `f0fc1d28…` (`24e7fd823db6`), nim-frames `ff7490d0…` (`2cfd9b6ea875`), nim-fdio `2284b43d…` (`90fe2f818464`) |
| Disk of the machine | 15 GiB free before the first build, 11 GiB after it (podman's VM disk and the OCI layout), 9 GiB after the acceptance runs |

`exe-sha256.txt` is of this image (only the `niuv` line differs from K4-1's).
`selftest.txt`, `apk-info.txt` and `tools.txt` are K4-1's: the layers below the
last two are the same, and `selftest.sh` was not run again on this image. The
guest `niuv` is the one in the image (built from the trees above). It is not
rebuilt from the mounted sources in the guest: the third-party Nim sources it
needs (parsetoml, results, checksums) are not in the final image, only in the
build stage. The pin that makes the guest's niuv trusted is the image digest
(NIV-28).

## The image of K4-3 (2026-10-17): niuv compiles Gleam with `compile-package`

The same recipe, with niuv at jj `6919be9b66be` (`feat(gleam): compile each package with gleam compile-package` and `fix(gleam): start tar under its own name`). The guest's niuv no longer calls `gleam export erlang-shipment`, so a package with a `path` dependency builds in the guest without the network (ADR-NIUV-0002, "K4-3 の結果").

| | |
|---|---|
| Manifest digest (what `[builder]` pins from now on) | `sha256:40ede3aa423d3c065451d96cf9c1e32467b5549073ff7c3c6106a30d2aaf5107` |
| Config digest (podman image id) | `sha256:0ccce4fbd5c203b41bba31d349cf701efa8325aaeeffa9378f6b6855ccf765d0` |
| Name given to kite and to `kite_sign`; podman tag | `niuv/builder-k4`; `localhost/niuv-builder-k4:k43` |
| Built with | podman 6.1.1, cache on (`podman build` 23 s: only the niuv stage and what follows were rebuilt) |
| Trees built in (recorded, not pinned) | niuv `173e75ab…` (jj `6919be9b66be`, working copy clean), nim-cbor-det `f0fc1d28…`, nim-frames `ff7490d0…`, nim-fdio `2284b43d…` (same as K4-2) |
| Signed by | the development key `niuv-builder-dev-k4`, as before |

`exe-sha256.txt` is of this image (only the `niuv` line differs from K4-2's); `apk-info.txt` and `tools.txt` are unchanged. The K4-2 image (`sha256:0f5f221a…`) builds Gleam packages that have a `path` dependency only with the network, so `--in-builder` should use this one. An earlier build of the same commit minus the `tar` fix had digest `sha256:c2f816cb…`; it cannot unpack a Hex archive in the guest (busybox) and is not to be used.

## The image of K5 (2026-10-21): derived from the K4-3 image with `kite pack`, no podman

The K4-3 image had niuv from before NIV-33 (the guest and the host disagreed on
a package's fingerprint when the workspace was inside the package root) and no
host name (a guest's name is `(none)`, and `inet:gethostbyname` of it waited
five seconds). It is not rebuilt: `derive.sh` unpacks its root with kite's own
reader, replaces three files and packs the tree (ADR-NIUV-0002, "K5 の続き").

| | |
|---|---|
| Base | `niuv/builder-k4@sha256:40ede3aa423d3c065451d96cf9c1e32467b5549073ff7c3c6106a30d2aaf5107` (the K4-3 image above) |
| Manifest digest (what `[builder]` pins from now on) | `sha256:1d1da016041cb2d144308049b9b965e5a5baa31214c31e358e829b1e112a74f6` |
| Config digest | `sha256:ca3387ff8755e0c3653811dd713ed93cbe1286f36f25c0588156f8173dee8277` (151 bytes: `kite pack` writes no environment or command) |
| Name given to kite and to `kite_sign` | `niuv/builder` |
| Layers | 1, `application/vnd.oci.image.layer.v1.tar+gzip`: `sha256:07f4090267a18a314e5b410c9d65f6667bfdf1619c5dff229d9c1b4b2f96f2cb`, 173,831,591 bytes (6234 entries, 407,197,184 bytes of tar) |
| Made with | kite 0.2.0 from kite-container `8d9ac045` (zippy 0.10.20; with 0.10.18 the layer could not be read back, kite-container's own fix), niuv's `derive.sh` |
| Reproduced | the same tree packed twice gave the same manifest digest, in each of two runs of `derive.sh` (two kite builds: zippy 0.10.18 and 0.10.20); the layer read back by kite's own reader lists the same 6234 entries as the tree |
| Signed by | the development key `niuv-builder-dev-k4`, as before (fukai roadmap 118 does not exist yet) |

What was replaced (`replaced-sha256.txt`; `exe-sha256.txt` has the new niuv line):

```
bca4ca6ebc2babd66bc94c9b3a0132f8119058a693d856a7f24d30ecb4812e99  usr/local/bin/niuv        (was 60c7477b…)
c2eefa37e084f1644e83b0cd9efef9b94cb51dcd1879a2e1d6e51a78a512fbee  usr/local/bin/builder-run (was 576add80…)
19a8625aac2b613a3e81670adb021fc05766228600c717a7a6c2e4d4b4355b9c  etc/hosts                 (was e3998dbe…)
```

Everything else is the base's: listing both roots as `kind mode size sha256 path`
(`tools/imagetree.nim`) differs in these three lines and nowhere else among 6234
entries. What the listing does not carry is not in the image either (`kite pack`
writes no owner, time, hard link or extended attribute: PCK-07, PCK-08; the
sticky bit of `/tmp` was already dropped by kite's reader when the base was
unpacked, PCK-05). The new niuv is the one niuv built for `aarch64-linux-musl` in
the K4-3 image's guest from niuv `591200c8` plus the declaration fix of its
external dependencies (parsetoml's source spelled `….git`, `src = "src"` for
parsetoml and checksums), 1,073,152 bytes.

Checked: the K4 acceptance suite (5 tests) on this image; `inet:gethostbyname` of
the guest's own name: `(none)` 5014 ms in the K4-3 image, `niuv-builder` 2 ms in
this one.

## The image of 2026-10-22: made again without podman, after the scaffold was lost

The scaffold of K5 (kite, key, signed images, initramfs) was gone with a temporary directory, so the
digest `sha256:1d1da016…` could no longer be started (no key to sign with). `bootstrap-alpine.sh`
made the whole chain again in an Alpine guest with a network (ADR-NIUV-0002, "作り直し (2026-10-22、足場の消失による)").

| | |
|---|---|
| Base (first image) | `niuv/builder-base@sha256:83187985f489b596d3ccd33a7173489b3d8aa8b02afe8247486ca0c376c583ea` (6234 entries; two packs of the tree gave this digest twice) |
| Manifest digest (what `[builder]` pins from now on) | `sha256:4131aa3a16d670c15ca4ec9fa5e3d51c5720b9cdca983c7f7af5194d225bf079` |
| Config digest | `sha256:c0758358578014402dc43ef7a9762e7267dfd3e721dbe5404caa0d7811c9496a` (151 bytes) |
| Name given to kite and to `kite_sign` | `niuv/builder` |
| Layers | 1: `sha256:33835cc8670d547b0a4e4a0b1e1b976e6296e3be0d57b0f989c96cfd1fcc4275`, 173,925,183 bytes (6234 entries, 407,462,912 bytes of tar) |
| Made with | kite 0.2.0 from kite-container `8489bb0d` (zippy 0.10.20), guest kernel `Image-vsock` for the two guests with a network, niuv `7a3f3946` |
| Reproduced | the derived tree packed twice gave one digest; the layer read back lists the same 6234 entries as the tree. A second run of the whole script, from nothing, gave other digests (base `c93e69d3…`, image `8a57e197…`): not reproducible, not promised |
| Signed by | the development key `godsgolem-kite-site-dev` (kid `c7096c88925b326b1b23470910599c9f`) in kite's `dev_keys`; not a release key (fukai roadmap 118) |

Differences from the image of K5: `musl` and `musl-dev` are 1.2.6-r3 (r2 is gone from Alpine's index); `nim`,
`beam.smp` and `erlexec` have other bytes (`exe-sha256.txt`); the niuv is `fc21b322…` (was `bca4ca6e…`); gleam is the same file.
The base was not packed from podman layers: the Alpine root (pinned digest) with the runtime packages added by `apk add --root`.
`records/` is of this image. Checked: `run-selftest.sh` (13 ok), the K4 acceptance suite (5 tests).
