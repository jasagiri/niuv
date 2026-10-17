# Licenses of what the builder image contains

The files in this directory are Apache-2.0 (the license of niuv). The image
holds other people's software under their own terms; they are not changed.

| What | License | Where it comes from |
|---|---|---|
| Erlang/OTP 29.1.1 | Apache-2.0 | `otp_src_29.1.1.tar.gz`, built from source |
| Nim 2.2.12 | MIT (the compiler) | `nim-2.2.12.tar.xz`, built from C |
| gleam 1.19.1 | Apache-2.0 | the upstream aarch64 musl binary |
| niuv | Apache-2.0 | this repository |
| parsetoml 0.7.2, nim-results 0.5.1, checksums 0.2.1 | MIT | linked into niuv (`deps.tree`) |
| nim-cbor-det, nim-frames, nim-fdio | Apache-2.0 | foundation, linked into niuv |
| Alpine Linux 3.24, musl, gcc, binutils, OpenSSL and the other apk packages | their own (see each package's `license` in `apk info -L`/`apk info -d`) | the `apk add` lines of the Containerfile; the versions that went in are in `records/apk-info.txt` |

Nim's license text is `/opt/nim/copying.txt` in the image.
