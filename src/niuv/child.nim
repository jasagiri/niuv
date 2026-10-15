## The child form (NIV-21): one request, the build, on nim-frames.
##
## Request: {1: kind (1 = build), 2: workspace file, 3: package, 4: out dir,
## 5: stage dir (optional)}. Reply: ok {1: the bytes of the manifest}, or the
## error numbers every child boundary uses.

import std/os
import cbor_det
import nim_frames/child
import ./[build, errors, workspace]

const
  KindBuild = 1'u64
  ChildVersion = 1'u64

proc textField(m: CborValue, key: uint64): Result[string, string] {.raises: [].} =
  let f = lookup(m, key)
  if not f.found: return err("missing field " & $key)
  if f.value.kind != ckText: return err("field " & $key & " must be text")
  ok(f.value.textVal)

proc codeFor(kind: ErrKind): uint64 {.raises: [].} =
  case kind
  of ekWorkspace, ekResolve: ecNotFound
  of ekDecl, ekRange, ekConflict, ekLock, ekTool, ekLicense, ekUsage: ecRefused
  of ekBuild, ekIo: ecIo

proc handleRequest*(request: CborValue): CborValue {.raises: [].} =
  if request.kind != ckMap: return errorReply(ecMalformed, "the request is not a map")
  let kind = lookup(request, 1)
  if not kind.found or kind.value.kind != ckUint:
    return errorReply(ecMalformed, "missing field 1 (kind)")
  if kind.value.uintVal != KindBuild:
    return errorReply(ecUnknownKind, "kind " & $kind.value.uintVal)
  let wsFile = textField(request, 2)
  let package = textField(request, 3)
  let outDir = textField(request, 4)
  if wsFile.isErr: return errorReply(ecMalformed, wsFile.error)
  if package.isErr: return errorReply(ecMalformed, package.error)
  if outDir.isErr: return errorReply(ecMalformed, outDir.error)
  var stage = defaultStageRoot()
  let stageField = lookup(request, 5)
  if stageField.found:
    if stageField.value.kind != ckText: return errorReply(ecMalformed, "field 5 must be text")
    stage = stageField.value.textVal
  if not fileExists(wsFile.value):
    return errorReply(ecNotFound, wsFile.value & " does not exist")
  let ws = loadWorkspace(wsFile.value)
  if ws.isErr: return errorReply(codeFor(ws.error.kind), ws.error.msg)
  let built = buildPackage(ws.get, package.value, outDir.value, stage)
  if built.isErr: return errorReply(codeFor(built.error.kind), built.error.msg)
  var bytes: string
  try:
    bytes = readFile(built.get.manifestPath)
  except CatchableError as e:
    return errorReply(ecIo, built.get.manifestPath & ": " & e.msg)
  okReply(@[entry(1, cBytes(bytes))])

proc runBuildChild*(): int {.raises: [].} =
  runChild(ChildVersion, handleRequest)
