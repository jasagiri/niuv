## `niuv lock` and `niuv build`: the order of the checks, then the compilers.
##
## The build checks come first and each refuses on its own: the closure, the
## lock against the files on disk, the license gate over what is declared,
## the tools against the lock. Only then does a compiler run. The Hex
## packages `gleam` fetches are checked against the gate after its build,
## because only then are their licenses known.

import std/[options, os, sequtils]
import ./[artifact, decl, errors, gleambuild, lock, manifest, nimbuild, resolve, sbom, toolchain, workspace]

const
  ManifestFile* = "niuv.manifest.cbor"
  SbomFile* = "niuv.sbom.cdx.json"

type
  BuildOutcome* = object
    artifacts*: seq[Artifact]
    notes*: seq[string]    ## things declared but not built, said out loud
    manifestPath*, sbomPath*: string

proc lockWorkspace*(ws: Workspace): NResult[Lock] {.raises: [].} =
  ## Probes every tool the workspace pins, then locks.
  let tools = ?probeTools(ws, ws.tools.mapIt(it.name))
  buildLock(ws, tools)

proc defaultStageRoot*(): string {.raises: [].} =
  try:
    getTempDir() / "niuv-stage"
  except CatchableError:
    "niuv-stage"

proc writeOut(path, content: string): NResult[void] {.raises: [].} =
  try:
    createDir(parentDir(path))
    writeFile(path, content)
  except CatchableError as e:
    return err(niuvError(ekIo, path & ": " & e.msg))
  ok()

proc buildPackage*(ws: Workspace, package: string, outDir: string, stageRoot: string,
                   only: seq[string] = @[]): NResult[BuildOutcome] {.raises: [].} =
  let closure = ?resolveClosure(ws, package)
  let locked = ?readLock(ws)
  ?checkLock(locked, ws, closure)
  let root = ws.find(package).get
  var outcome = BuildOutcome()

  let bins = root.nim.bins.filterIt(only.len == 0 or it.name in only)
  let buildsNim = root.nim.present and bins.len > 0
  let buildsGleam = root.gleam.present
  let nimSealed = bins.anyIt(it.sealed)

  # The gate over what is declared, before any compiler runs.
  ?checkLicenses(nimComponents(closure), nimSealed, package)
  ?checkLicenses(gleamComponents(closure, @[]), root.gleam.sealed and buildsGleam, package)

  var needed: seq[string]
  if buildsNim: needed.add "nim"
  if buildsGleam: needed.add ["gleam", "erlang"]
  let tools = ?probeTools(ws, needed)
  ?checkTools(locked, tools)
  proc tool(name: string): ToolInfo {.raises: [].} = tools.filterIt(it.name == name)[0]

  var comps = nimComponents(closure)
  if buildsNim:
    outcome.artifacts.add ?buildNim(tool("nim"), closure, outDir, stageRoot, only)
  if buildsGleam:
    let g = ?buildGleam(tool("gleam"), tool("erlang"), closure, outDir, stageRoot)
    ?checkLicenses(g.hex, root.gleam.sealed, package)
    outcome.artifacts.add g.artifacts
    for c in gleamComponents(closure, g.hex):
      if comps.allIt(it.name != c.name or it.version != c.version): comps.add c
  if root.wasm.present:
    outcome.notes.add "wasm: '" & root.wasm.entry & "' is declared, not built (niuv has no WASM build step)"

  outcome.manifestPath = outDir / ManifestFile
  outcome.sbomPath = outDir / SbomFile
  ?writeOut(outcome.manifestPath, ?encodeManifest(root.name, root.version, outcome.artifacts))
  ?writeOut(outcome.sbomPath, renderSbom(root.name, root.version, comps))
  ok(outcome)
