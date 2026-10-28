## The fingerprint of niuv's own sources (NIV-46): which sources a niuv
## binary was built from, so that a binary older than its sources refuses to
## build instead of building with rules that are no longer the source's.
##
## The fingerprint covers src/ (*.nim, *.c), nim.cfg and config.nims. The
## sibling repositories on nim.cfg's --path (nim-cbor-det, nim-frames) are
## not covered.

import std/[algorithm, os, strutils]
import ./[errors, hashing]

const
  SourceRoot* = currentSourcePath().parentDir.parentDir.parentDir
    ## The niuv checkout this binary was compiled from.
  RebuildCommand* = "nim c --opt:speed --hints:off -o:" & SourceRoot / "build" / "bin" / "niuv" & " " &
                    SourceRoot / "src" / "niuv.nim"

const
  ExitStale* = 3        ## the sources changed after the binary was built (NIV-47)
  ExitNoSources* = 4    ## the sources are not where the binary was built (NIV-47)

type
  Freshness* = enum
    frFresh           ## the sources have the fingerprint the binary was built with
    frStale           ## the sources changed after the binary was built
    frNoSources       ## the sources are not where they were (a copied binary)

proc isFingerprinted(rel: string): bool {.raises: [].} =
  (rel.startsWith("src/") and (rel.endsWith(".nim") or rel.endsWith(".c"))) or
    rel in ["nim.cfg", "config.nims"]

proc fingerprintOf*(files: seq[(string, string)]): string {.raises: [].} =
  ## SHA-256 over the files sorted by path, each as path, length and content.
  var sorted = files
  sorted.sort(proc (a, b: (string, string)): int = cmp(a[0], b[0]))
  var all = ""
  for (rel, content) in sorted:
    all.add rel & "\0" & $content.len & "\0" & content
  sha256Hex(all)

proc buildFingerprint(): string {.compileTime.} =
  let listing = staticExec("cd " & quoteShell(SourceRoot) & " && find src -type f && ls nim.cfg config.nims")
  var files: seq[(string, string)]
  for line in listing.splitLines():
    let rel = line.strip()
    if rel.isFingerprinted: files.add (rel, staticRead(SourceRoot / rel))
  fingerprintOf(files)

const BuildFingerprint* = buildFingerprint()

proc sourceFingerprint*(root: string): NResult[string] {.raises: [].} =
  ## The fingerprint of the sources under `root` now.
  var files: seq[(string, string)]
  try:
    for path in walkDirRec(root / "src", relative = true):
      let rel = "src/" & path.replace(DirSep, '/')
      if rel.isFingerprinted: files.add (rel, readFile(root / rel))
    for rel in ["nim.cfg", "config.nims"]:
      if fileExists(root / rel): files.add (rel, readFile(root / rel))
  except CatchableError as e:
    return err(niuvError(ekIo, root & ": " & e.msg))
  ok(fingerprintOf(files))

proc freshness*(built, root: string): NResult[Freshness] {.raises: [].} =
  if not dirExists(root / "src"): return ok(frNoSources)
  let now = ?sourceFingerprint(root)
  ok(if now == built: frFresh else: frStale)
