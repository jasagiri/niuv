## Building the WASM components a package declares (NIV-49 .. NIV-56,
## ADR-NIUV-0007).
##
## The recipe is `wasm.nim`'s (NIV-40 .. NIV-43, NIV-48); this module only
## turns a `[[wasm.component]]` into a `WasmRequest`, and puts the component,
## and nothing else, into the output directory.

import std/os
import ./[artifact, decl, errors, nimbuild, resolve, wasm]

const
  WasmOutDir* = "wasm"   ## under the output directory: <name>.component.wasm (NIV-51)

type
  WasmBuilt* = object
    artifacts*: seq[Artifact]
    notes*: seq[string]

proc componentRequest*(c: Closure, root: PackageDecl, comp: WasmComponent,
                       stageDir: string): WasmRequest {.raises: [].} =
  ## The core module and the embedded form stay in `stageDir`; the closure's
  ## Nim packages, then the component's own paths and flags, reach nim as
  ## `--path` and flags (NIV-56).
  var flags = closurePaths(c)
  for p in comp.paths: flags.add "--path:" & root.inRoot(p)
  flags.add comp.flags
  WasmRequest(program: root.inRoot(comp.entry), outDir: stageDir / "out", stageDir: stageDir, name: comp.name,
              nimFlags: flags, simd: not comp.noSimd, shape: wsComponent, witDir: root.inRoot(comp.wit),
              world: comp.world, exports: comp.exports, stackSize: comp.stackSize)

proc buildWasmComponents*(tc: WasmToolchain, c: Closure, root: PackageDecl, outDir, stageRoot: string,
                          only: seq[string] = @[]): NResult[WasmBuilt] {.raises: [].} =
  ## The components of `root` (all, or the ones named in `only`), each as
  ## <outDir>/wasm/<name>.component.wasm.
  var built = WasmBuilt()
  var outAbs: string
  try:
    outAbs = absolutePath(outDir)
    createDir(outAbs / WasmOutDir)
  except CatchableError as e:
    return err(niuvError(ekIo, outDir & ": " & e.msg))
  for comp in root.wasm.components:
    if only.len > 0 and comp.name notin only: continue
    let stage = stageFor(stageRoot, outAbs, comp.name)
    let r = buildWasm(tc, componentRequest(c, root, comp, stage))
    if r.isErr:
      let e = r.error
      return err(niuvError(e.kind, "wasm component '" & comp.name & "' of '" & c.root & "': " & e.msg))
    let dest = outAbs / WasmOutDir / (comp.name & ".component.wasm")
    try:
      copyFile(r.get.component, dest)
    except CatchableError as e:
      return err(niuvError(ekIo, dest & ": " & e.msg))
    built.artifacts.add ?describeFile(comp.name, akWasm, dest, comp.sealed)
    built.notes.add r.get.notes
  ok(built)
