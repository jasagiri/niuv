## `niuv lock` and `niuv build`: the order of the checks, then the compilers.
##
## The build checks come first and each refuses on its own: the closure, the
## lock against the files on disk, the tools against the lock. Only then does
## a compiler run.

import std/[options, sequtils]
import ./[artifact, errors, lock, nimbuild, resolve, toolchain, workspace, decl]

type
  BuildOutcome* = object
    artifacts*: seq[Artifact]
    notes*: seq[string]    ## things declared but not built, said out loud

proc lockWorkspace*(ws: Workspace): NResult[Lock] {.raises: [].} =
  ## Probes every tool the workspace pins, then locks.
  let tools = ?probeTools(ws, ws.tools.mapIt(it.name))
  buildLock(ws, tools)

proc buildPackage*(ws: Workspace, package: string, outDir: string,
                   only: seq[string] = @[]): NResult[BuildOutcome] {.raises: [].} =
  let closure = ?resolveClosure(ws, package)
  let locked = ?readLock(ws)
  ?checkLock(locked, ws, closure)
  let root = ws.find(package).get
  var outcome = BuildOutcome()

  var needed: seq[string]
  if root.nim.present and root.nim.bins.len > 0: needed.add "nim"
  let tools = ?probeTools(ws, needed)
  ?checkTools(locked, tools)

  if needed.len > 0:
    let nim = tools.filterIt(it.name == "nim")[0]
    outcome.artifacts.add ?buildNim(nim, closure, outDir, only)
  if root.wasm.present:
    outcome.notes.add "wasm: '" & root.wasm.entry & "' is declared, not built (niuv has no WASM build step)"
  ok(outcome)
