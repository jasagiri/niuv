# Package
version       = "0.2.0"
author        = "jasagiri"
description   = "Multi-language (Nim, Gleam, WASM) build tool: declarations, closure, lock, build, manifest, license gate"
license       = "Apache-2.0"
srcDir        = "src"
bin           = @["niuv"]
binDir        = "build/bin"

# Dependencies
requires "nim >= 2.0.0"
requires "parsetoml >= 0.7.2"
requires "results >= 0.5.1"
requires "checksums >= 0.2.1"
# foundation/nim-cbor-det (the manifest) and nim-frames (the child form) are
# not in the nimble registry: nim.cfg takes them from source, next to this
# repository.

task test, "Run the tests":
  exec "nim c -r --opt:speed --hints:off tests/test_all.nim"
