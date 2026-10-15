## Building the Nim children of a package (NIV-14, NIV-15).
##
## Every flag reaches `nim c` as an argument. Nothing is read from nim.cfg,
## config.nims or nimble: what is not declared is not found.

import std/[os, sequtils]
import ./[artifact, decl, errors, exec, resolve, toolchain]

const
  MaxCompilerOutput = 8192

proc nimArgs*(c: Closure, root: PackageDecl, bin: NimBin, nimcache, outFile: string): seq[string] {.raises: [].} =
  result = @["c"]
  result.add root.nim.flags
  result.add bin.flags
  result.add ["--noNimblePath", "--skipUserCfg:on", "--skipParentCfg:on", "--skipProjCfg:on"]
  for p in c.packages:
    if p.nim.present: result.add "--path:" & p.nimSrcDir
  for e in c.externals:
    result.add "--path:" & normalizedPath(e.dir / e.src)
  result.add "--nimcache:" & nimcache
  result.add "-o:" & outFile
  result.add root.inRoot(bin.main)

proc tail(s: string, n: int): string {.raises: [].} =
  if s.len <= n: s else: "..." & s[s.len - n .. ^1]

proc buildNim*(nim: ToolInfo, c: Closure, outDir: string,
               only: seq[string] = @[]): NResult[seq[Artifact]] {.raises: [].} =
  ## Builds the bins of the closure's root package (all, or the ones named in
  ## `only`) into `outDir`, one file per bin, named for the bin.
  var root: PackageDecl
  for p in c.packages:
    if p.name == c.root: root = p
  for name in only:
    if root.nim.bins.allIt(it.name != name):
      return err(niuvError(ekUsage, "package '" & c.root & "' has no nim bin '" & name & "'"))
  try:
    createDir(outDir)
  except CatchableError as e:
    return err(niuvError(ekIo, outDir & ": " & e.msg))
  var built: seq[Artifact]
  for bin in root.nim.bins:
    if only.len > 0 and bin.name notin only: continue
    let outFile = outDir / bin.name
    let args = nimArgs(c, root, bin, outDir / "nimcache" / bin.name, outFile)
    let r = ?runProcess(nim.exe, args, workDir = root.root)
    if r.code != 0:
      return err(niuvError(ekBuild, "nim failed for bin '" & bin.name & "' of '" & c.root &
                           "' (exit " & $r.code & "):\n" & tail(r.output, MaxCompilerOutput)))
    built.add ?describeFile(bin.name, akNimChild, outFile, bin.sealed)
  ok(built)
