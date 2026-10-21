# builder: the Linux build image of niuv

The recipe for the image in which `niuv build --target aarch64-linux-musl` runs
(ADR-NIUV-0002, NIV-24 to NIV-32): Alpine 3.24, musl Nim 2.2.12 built from the
csources distribution, Erlang/OTP 29.1.1 built from source, the upstream gleam
1.19.1 aarch64 musl binary, and niuv itself. aarch64 only. The image is built with
podman, put into kite's store, signed, and started by kite in a guest with no
network. This directory holds the recipe, the pinned inputs and the records;
it holds no key and knows nothing about fukai.

| File | What |
|---|---|
| `inputs.env`, `inputs.sha256`, `deps.tree` | Alpine digest, upstream URLs; SHA-256 of the three tarballs; tree hashes of the third-party Nim sources |
| `Containerfile` | The image. The first stage checks the tarballs again with `sha256sum -c` |
| `verify-inputs.sh`, `tree-hash.sh` | The checks `build.sh` runs before anything is built. A mismatch or a missing file stops with exit 1 |
| `build.sh` | Fetch, verify, stage the context, `podman build`, `podman save --format oci-dir`, write the records |
| `import-sign.sh` | `kite import` of the OCI layout, then `kite_sign image` |
| `run-selftest.sh`, `selftest.sh` | Start the image in a kite guest with `--mount` (source read-only, output read-write) and `--exit-status`; `selftest.sh` is the guest's program |
| `builder-run` | The image's program for `niuv ... --in-builder`: runs `/ctl/run.sh`, which the host writes into a read-only mount (kite starts a program that is in the image, not in a mount) |
| `derive.sh` | The next image from the one before it, without podman: unpack the base's root, replace `niuv`, `builder-run` and `/etc/hosts`, `kite pack` twice (same digest required), import, check the image against the tree, sign |
| `tools/imagetree.nim`, `tools/build.sh` | `list` (a root as comparable lines) and `unpack` (a stored image's root, built by kite's own reader); built against the kite source tree |
| `records/` | What went in: `apk-info.txt`, `tools.txt`, `exe-sha256.txt`, `selftest.txt`, `build-record.md` |
| `test/test_verify.sh` | E tests of the input check (`sh builder/test/test_verify.sh`) |
| `LICENSES.md` | The licenses of what the image contains |

## Use

```sh
OUT=/somewhere/outside/the/repository
builder/build.sh --out $OUT [--no-cache]          # 5 to 7 minutes on 4 CPUs
builder/import-sign.sh --oci $OUT/oci --repo niuv/builder --home KITE_HOME \
  --key KEYFILE --kite KITE --kite-sign KITE_SIGN
builder/run-selftest.sh --home KITE_HOME --image niuv/builder@sha256:… \
  --signature KITE_HOME/niuv_builder.sig --kite KITE --kernel K --initrd I \
  --source /path/to/niuv --out OUTDIR
```

`--home` is the `HOME` kite runs with (its store is `~/.kite`, its trust file
`~/.config/kite/trust.json`). The name given to `kite_sign` must contain a `/`.

## Deriving the next image

`Containerfile` and `build.sh` make the first image: Alpine, Nim, OTP and gleam
cannot come from anywhere else. What changes afterwards (niuv, the entry
`builder-run`, `/etc/hosts`) changes by derivation, because it is three files
and the rest must stay byte for byte (ADR-NIUV-0002, "K5 の続き"):

```sh
tools/build.sh KITE_SRC OUT/tools                 # imagetree, against kite-container
derive.sh --home KITE_HOME --base niuv/builder-k4@sha256:… --niuv NIUV_FOR_LINUX \
  --out OUT/derive --repo niuv/builder --kite KITE --kite-sign KITE_SIGN \
  --key KEYFILE --imagetree OUT/tools/imagetree   # about 17 minutes (two packs of 400 MB)
```

`NIUV_FOR_LINUX` is a niuv built for `aarch64-linux-musl`: `niuv build niuv
--target aarch64-linux-musl --in-builder` in a workspace that lists niuv,
nim-cbor-det, nim-frames and nim-fdio. The script stops on any difference
outside the three files, on two packs with different digests, and on an image
that differs from its tree. An image made this way is not what `Containerfile`
would make (the `/etc/hosts` line is only added here); the records say which
one an image is.

## The signing key is a development key

The ceremony for the image key (fukai roadmap 118: a key apart from the release
key, the same ceremony and place) does not exist yet. Until it does, the image
is signed with a key listed under `dev_keys` in kite's trust file, and kite
warns on every run that the image is development-signed. `import-sign.sh` takes
the key as an argument and keeps none. A digest signed this way is not a release
pin.

## Not done

Sigstore verification of the upstream tarballs (Future: needs `cosign` on the
machine that builds). Building the image from the lock (NIV-26 is K4-2). A
second architecture or libc.
