## One built output: what the manifest lists (NIV-18).

import std/os
import ./[errors, hashing]

type
  ArtifactKind* = enum
    akBeam = "beam"
    akNimChild = "nim-child"
    akWasm = "wasm"

  Artifact* = object
    name*: string          ## the bin name, or the Erlang module for a beam
    kind*: ArtifactKind
    path*: string          ## where the file is now (not part of the manifest)
    sha256*: string
    size*: int64
    sealed*: bool          ## set by the package's [..] sealed = true (NIV-20)

proc describeFile*(name: string, kind: ArtifactKind, path: string,
                   sealed: bool): NResult[Artifact] {.raises: [].} =
  var size: int64
  try:
    size = getFileSize(path)
  except CatchableError as e:
    return err(niuvError(ekIo, path & ": " & e.msg))
  ok(Artifact(name: name, kind: kind, path: path, sha256: ?sha256File(path), size: size,
              sealed: sealed))
