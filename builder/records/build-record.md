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
| Manifest digest (what `[builder]` pins from now on) | `sha256:0f5f221a3ade5f25e9ccf6f5d72adc8980efd90279ea0683adfb77fb604c0287` |
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
