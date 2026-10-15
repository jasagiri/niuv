## The lock niuv.lock (NIV-11, NIV-12, NIV-13): what a build is allowed to
## find, pinned by content.
##
## Written next to niuv.workspace.toml. It covers the whole workspace: one
## coherent set, one pin per external name.

import std/[algorithm, os, sequtils, strutils]
import parsetoml
import ./[decl, errors, hashing, resolve, toolchain, workspace]

const
  LockVersion = 1
  LockFileName* = "niuv.lock"
  ## Directories that hold output, not source.
  SkipDirs = [".git", ".jj", "nimcache", "build", "node_modules"]

type
  LockedTool* = object
    name*, version*, sha256*: string

  LockedPackage* = object
    name*, version*: string
    path*: string          ## the package root, relative to the workspace
    sha256*: string

  LockedExternal* = object
    name*, source*, version*: string
    sha256*: string

  Lock* = object
    tools*: seq[LockedTool]
    packages*: seq[LockedPackage]
    externals*: seq[LockedExternal]

proc lockErr[T](msg: string): NResult[T] {.raises: [].} =
  err(niuvError(ekLock, msg))

# ---------------------------------------------------------------- hashing

proc packageHash*(d: PackageDecl): NResult[string] {.raises: [].} =
  ## The declared sources of a package: the declaration, the Nim src
  ## directory, the directory of each bin's main (or the main alone when it
  ## sits in the root), the Gleam root without its build output, the WASM
  ## entry. Files outside these (tests, docs, bin/) do not move the hash.
  var entries: seq[tuple[label, path: string]]
  proc add(label, path: string) {.raises: [].} =
    if entries.allIt(it.label != label): entries.add (label: label, path: path)
  proc addTree(dir, labelPrefix: string): NResult[void] {.raises: [].} =
    for rel in ?listFiles(dir, SkipDirs):
      add(labelPrefix & rel, dir / rel)
    ok()
  add("decl/niuv.toml", d.declDir / "niuv.toml")
  if d.nim.present:
    ?addTree(d.nimSrcDir, "nim-src:")
    for b in d.nim.bins:
      let main = d.inRoot(b.main)
      let dir = parentDir(main)
      if dir == d.root: add("bin-main:" & b.main, main)
      else: ?addTree(dir, "bin-dir:" & b.name & ":")
  if d.gleam.present:
    ?addTree(d.inRoot(d.gleam.root), "gleam:")
  if d.wasm.present:
    add("wasm:" & d.wasm.entry, d.inRoot(d.wasm.entry))
  hashEntries(entries)

proc lockPackage*(ws: Workspace, d: PackageDecl): NResult[LockedPackage] {.raises: [].} =
  var rel: string
  try:
    rel = relativePath(d.root, ws.dir)
  except CatchableError as e:
    return lockErr[LockedPackage]("package '" & d.name & "': " & e.msg)
  ok(LockedPackage(name: d.name, version: d.version, path: rel, sha256: ?packageHash(d)))

proc lockExternal*(e: ResolvedExternal): NResult[LockedExternal] {.raises: [].} =
  ok(LockedExternal(name: e.name, source: e.source, version: e.version,
                    sha256: ?treeHash(e.dir, [".git", ".jj"])))

# ---------------------------------------------------------------- building

proc buildLock*(ws: Workspace, tools: seq[ToolInfo]): NResult[Lock] {.raises: [].} =
  ## Locks every member and every external the members ask for. A name pinned
  ## two ways anywhere in the workspace is refused here.
  var l = Lock()
  for t in tools.sortedByIt(it.name):
    l.tools.add LockedTool(name: t.name, version: t.version, sha256: t.sha256)
  var ext: seq[ResolvedExternal]
  for d in ws.packages.sortedByIt(it.name):
    l.packages.add ?lockPackage(ws, d)
    let c = ?resolveClosure(ws, d.name)
    for e in c.externals:
      let same = ext.filterIt(it.name == e.name)
      if same.len == 0: ext.add e
      elif same[0].version != e.version or normalizedSource(same[0].source) != normalizedSource(e.source):
        return err(niuvError(ekConflict, "'" & e.name & "' is pinned two ways in this workspace: " &
          same[0].version & " (" & same[0].source & ") for '" & same[0].requiredBy & "' and " &
          e.version & " (" & e.source & ") for '" & e.requiredBy &
          "'; a workspace holds one pin per external name"))
  for e in ext.sortedByIt(it.name):
    l.externals.add ?lockExternal(e)
  ok(l)

# ---------------------------------------------------------------- the file

proc q(s: string): string {.raises: [].} =
  "\"" & s.replace("\\", "\\\\").replace("\"", "\\\"") & "\""

proc renderLock*(l: Lock): string {.raises: [].} =
  result = "# niuv.lock: written by `niuv lock`. Do not edit by hand.\n"
  result.add "lock-version = " & $LockVersion & "\n"
  for t in l.tools:
    result.add "\n[tool." & t.name & "]\nversion = " & q(t.version) & "\nsha256 = " & q(t.sha256) & "\n"
  for p in l.packages:
    result.add "\n[package." & p.name & "]\nversion = " & q(p.version) & "\npath = " & q(p.path) &
               "\nsha256 = " & q(p.sha256) & "\n"
  for e in l.externals:
    result.add "\n[external." & e.name & "]\nsource = " & q(e.source) & "\nversion = " & q(e.version) &
               "\nsha256 = " & q(e.sha256) & "\n"

proc strKeys(t: TomlTableRef, keys: openArray[string], file, ctx: string): NResult[seq[string]] {.raises: [].} =
  ## The values of exactly `keys`, in that order.
  for k in t.keys:
    if k notin keys: return lockErr[seq[string]](file & ": [" & ctx & "] unknown key '" & k & "'")
  var values: seq[string]
  for k in keys:
    let v = t.getOrDefault(k)
    if v.isNil or v.kind != TomlValueKind.String:
      return lockErr[seq[string]](file & ": [" & ctx & "] '" & k & "' must be a string")
    values.add v.stringVal
  ok(values)

proc parseLock*(text, file: string): NResult[Lock] {.raises: [].} =
  var doc: TomlValueRef
  try:
    doc = parseString(text, file)
  except Exception as e:
    # parsetoml declares no raises list; the message goes out as an error value.
    return lockErr[Lock](file & ": " & e.msg)
  if doc.kind != TomlValueKind.Table: return lockErr[Lock](file & ": not a table")
  let top = doc.tableVal
  for k in top.keys:
    if k notin ["lock-version", "tool", "package", "external"]:
      return lockErr[Lock](file & ": unknown key '" & k & "'")
  let ver = top.getOrDefault("lock-version")
  if ver.isNil or ver.kind != TomlValueKind.Int or ver.intVal != LockVersion:
    return lockErr[Lock](file & ": lock-version must be " & $LockVersion & "; run `niuv lock`")
  var l = Lock()
  for section in ["tool", "package", "external"]:
    let st = top.getOrDefault(section)
    if st.isNil: continue
    if st.kind != TomlValueKind.Table: return lockErr[Lock](file & ": [" & section & "] must be a table")
    for name, v in st.tableVal.pairs:
      if v.kind != TomlValueKind.Table: return lockErr[Lock](file & ": [" & section & "." & name & "] must be a table")
      let ctx = section & "." & name
      case section
      of "tool":
        let f = ?strKeys(v.tableVal, ["version", "sha256"], file, ctx)
        l.tools.add LockedTool(name: name, version: f[0], sha256: f[1])
      of "package":
        let f = ?strKeys(v.tableVal, ["version", "path", "sha256"], file, ctx)
        l.packages.add LockedPackage(name: name, version: f[0], path: f[1], sha256: f[2])
      else:
        let f = ?strKeys(v.tableVal, ["source", "version", "sha256"], file, ctx)
        l.externals.add LockedExternal(name: name, source: f[0], version: f[1], sha256: f[2])
  ok(l)

proc lockPath*(ws: Workspace): string {.raises: [].} =
  ws.dir / LockFileName

proc writeLock*(ws: Workspace, l: Lock): NResult[void] {.raises: [].} =
  try:
    writeFile(lockPath(ws), renderLock(l))
  except CatchableError as e:
    return err(niuvError(ekIo, lockPath(ws) & ": " & e.msg))
  ok()

proc readLock*(ws: Workspace): NResult[Lock] {.raises: [].} =
  let path = lockPath(ws)
  if not fileExists(path):
    return lockErr[Lock]("there is no " & path & "; run `niuv lock` first")
  var text: string
  try:
    text = readFile(path)
  except CatchableError as e:
    return err(niuvError(ekIo, path & ": " & e.msg))
  parseLock(text, path)

# ---------------------------------------------------------------- checking

proc short(h: string): string {.raises: [].} =
  if h.len > 12: h[0 ..< 12] else: h

proc checkLock*(l: Lock, ws: Workspace, c: Closure): NResult[void] {.raises: [].} =
  ## Every package and external of the closure must be in the lock, where the
  ## lock says, with the content the lock says.
  const again = "; run `niuv lock`"
  for d in c.packages:
    let now = ?lockPackage(ws, d)
    let at = l.packages.filterIt(it.name == d.name)
    if at.len == 0:
      return lockErr[void]("package '" & d.name & "' is not in niuv.lock" & again)
    if at[0].path != now.path:
      return lockErr[void]("package '" & d.name & "' moved: the lock says " & at[0].path &
                           ", it is at " & now.path & again)
    if at[0].version != now.version:
      return lockErr[void]("package '" & d.name & "' is " & now.version & " but the lock says " &
                           at[0].version & again)
    if at[0].sha256 != now.sha256:
      return lockErr[void]("package '" & d.name & "' changed since it was locked (" &
                           short(at[0].sha256) & " -> " & short(now.sha256) & ")" & again)
  for e in c.externals:
    let now = ?lockExternal(e)
    let at = l.externals.filterIt(it.name == e.name)
    if at.len == 0:
      return lockErr[void]("external '" & e.name & "' is not in niuv.lock" & again)
    if at[0].version != now.version or normalizedSource(at[0].source) != normalizedSource(now.source):
      return lockErr[void]("external '" & e.name & "' is pinned at " & now.version & " (" & now.source &
                           ") but the lock says " & at[0].version & " (" & at[0].source & ")" & again)
    if at[0].sha256 != now.sha256:
      return lockErr[void]("external '" & e.name & "' " & e.version & " changed on disk (" &
                           short(at[0].sha256) & " -> " & short(now.sha256) & ")" & again)
  ok()

proc checkTools*(l: Lock, actual: seq[ToolInfo]): NResult[void] {.raises: [].} =
  ## Each tool in use must be pinned, at this version, with this executable.
  for t in actual:
    let at = l.tools.filterIt(it.name == t.name)
    if at.len == 0:
      return err(niuvError(ekTool, "tool " & t.name & " is not pinned in niuv.lock; run `niuv lock`"))
    if at[0].version != t.version:
      return err(niuvError(ekTool, "tool " & t.name & " is " & t.version & " (" & t.exe &
                           ") but niuv.lock pins " & at[0].version))
    if at[0].sha256 != t.sha256:
      return err(niuvError(ekTool, "tool " & t.name & " " & t.version & ": the executable " & t.exe &
                           " has SHA-256 " & short(t.sha256) & " but niuv.lock pins " & short(at[0].sha256)))
  ok()
