## SHA-256 of bytes, of a file and of a directory tree (NIV-11).

import std/[algorithm, os, strutils]
import checksums/sha2
import ./errors

const
  ChunkSize = 64 * 1024

proc toHex(d: ShaDigest_256): string {.raises: [].} =
  const hexDigits = "0123456789abcdef"
  result = newStringOfCap(64)
  for c in d:
    result.add hexDigits[int(ord(c)) shr 4]
    result.add hexDigits[int(ord(c)) and 15]

proc sha256Hex*(data: string): string {.raises: [].} =
  var ctx = initSha_256()
  ctx.update(data)
  ctx.digest().toHex

proc sha256File*(path: string): NResult[string] {.raises: [].} =
  var ctx = initSha_256()
  var f: File
  if not open(f, path, fmRead):
    return err(niuvError(ekIo, path & ": cannot open for reading"))
  var buf = newString(ChunkSize)
  try:
    while true:
      let n = readBuffer(f, addr buf[0], ChunkSize)
      if n == 0: break
      ctx.update(buf.toOpenArray(0, n - 1))
  except CatchableError as e:
    close(f)
    return err(niuvError(ekIo, path & ": " & e.msg))
  close(f)
  ok(ctx.digest().toHex)

proc listFiles*(dir: string, skipDirs: openArray[string] = [],
                 skipPaths: openArray[string] = []): NResult[seq[string]] {.raises: [].} =
  ## Every file under `dir` as a '/'-separated path relative to it, sorted.
  ## The directories named in `skipDirs` are left out at any depth; the
  ## absolute paths in `skipPaths` (a directory or a file) are left out where
  ## they are (NIV-33). A symlink to a directory is an error: what it points
  ## at could change unseen.
  if not dirExists(dir):
    return err(niuvError(ekIo, dir & ": not a directory"))
  let skip = @skipDirs
  var skipAbs: seq[string]
  var absDir: string
  try:
    absDir = normalizedPath(absolutePath(dir))
    for p in skipPaths: skipAbs.add normalizedPath(absolutePath(p))
  except CatchableError as e:
    return err(niuvError(ekIo, dir & ": " & e.msg))
  var files: seq[string]
  proc walk(rel: string): NResult[void] {.raises: [].} =
    try:
      for kind, path in walkDir(dir / rel, relative = true):
        let relPath = if rel.len == 0: path else: rel / path
        if skipAbs.len > 0 and (absDir / relPath) in skipAbs: continue
        case kind
        of pcDir:
          if path notin skip: ?walk(relPath)
        of pcFile, pcLinkToFile:
          files.add relPath.replace(DirSep, '/')
        of pcLinkToDir:
          return err(niuvError(ekIo, dir / relPath & ": a symlink to a directory inside a hashed tree"))
    except CatchableError as e:
      return err(niuvError(ekIo, dir / rel & ": " & e.msg))
    ok()
  ?walk("")
  files.sort()
  ok(files)

proc hashEntries*(entries: openArray[tuple[label, path: string]]): NResult[string] {.raises: [].} =
  ## SHA-256 over the sorted lines `label NUL file-sha256 LF`. Modification
  ## times and the order of the entries do not matter.
  var lines: seq[string]
  for e in entries:
    let h = ?sha256File(e.path)
    lines.add e.label & "\0" & h & "\n"
  lines.sort()
  ok(sha256Hex(lines.join("")))

proc treeHash*(dir: string, skipDirs: openArray[string] = [],
                skipPaths: openArray[string] = []): NResult[string] {.raises: [].} =
  ## `hashEntries` over every file of `dir`, labelled by its relative path.
  var entries: seq[tuple[label, path: string]]
  for rel in ?listFiles(dir, skipDirs, skipPaths):
    entries.add (label: rel, path: dir / rel)
  hashEntries(entries)
