## The lock niuv.lock (NIV-11, NIV-12, NIV-13): what a build is allowed to
## find, pinned by content.
##
## Written next to niuv.workspace.toml. It covers the whole workspace: one
## coherent set, one pin per external name. One lock per target (NIV-25):
## `niuv.lock` for the machine niuv runs on when no target is named,
## `niuv.<target>.lock` when one is. A lock may name the builder image
## (NIV-26).

import std/[algorithm, options, os, sequtils, strutils]
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

  LockedBuilder* = object
    image*: string         ## NAME@sha256:<64 hex>: the image the target's build runs in (NIV-26)

  Lock* = object
    builder*: Option[LockedBuilder]
    tools*: seq[LockedTool]
    packages*: seq[LockedPackage]
    externals*: seq[LockedExternal]

proc lockErr[T](msg: string): NResult[T] {.raises: [].} =
  err(niuvError(ekLock, msg))

# ---------------------------------------------------------------- hashing

proc workspaceSkips*(ws: Workspace, treeDir: string): NResult[seq[string]] {.raises: [].} =
  ## What of the workspace sits inside `treeDir` and is not the package's
  ## (NIV-33): the workspace directory, whole, when `treeDir` is a proper
  ## ancestor of it; when it is `treeDir` itself, only the workspace file and
  ## the lock files, which niuv writes.
  var skips: seq[string]
  try:
    let tree = normalizedPath(absolutePath(treeDir))
    if ws.dir == tree:
      skips.add ws.file
      for kind, path in walkDir(ws.dir):
        let name = extractFilename(path)
        if kind == pcFile and name.endsWith(".lock") and (name == LockFileName or name.startsWith("niuv.")):
          skips.add path
    elif ws.dir.startsWith(tree & "/"):
      skips.add ws.dir
  except CatchableError as e:
    return err(niuvError(ekIo, ws.dir & ": " & e.msg))
  ok(skips)

proc packageHash*(d: PackageDecl, ws: Workspace): NResult[string] {.raises: [].} =
  ## The declared sources of a package: the declaration, the Nim src
  ## directory, the directory of each bin's main (or the main alone when it
  ## sits in the root), the Gleam root without its build output, the WASM
  ## entry. Files outside these (tests, docs, bin/) do not move the hash, and
  ## neither does the workspace (NIV-33).
  var entries: seq[tuple[label, path: string]]
  proc add(label, path: string) {.raises: [].} =
    if entries.allIt(it.label != label): entries.add (label: label, path: path)
  proc addTree(dir, labelPrefix: string): NResult[void] {.raises: [].} =
    for rel in ?listFiles(dir, SkipDirs, ?workspaceSkips(ws, dir)):
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
  ok(LockedPackage(name: d.name, version: d.version, path: rel, sha256: ?packageHash(d, ws)))

proc lockExternal*(e: ResolvedExternal): NResult[LockedExternal] {.raises: [].} =
  ok(LockedExternal(name: e.name, source: e.source, version: e.version,
                    sha256: ?treeHash(e.dir, [".git", ".jj"])))

# ---------------------------------------------------------------- the builder

proc isLowerHex64(s: string): bool {.raises: [].} =
  s.len == 64 and s.allIt(it in {'0'..'9', 'a'..'f'})

proc checkBuilderImage*(image: string): NResult[LockedBuilder] {.raises: [].} =
  ## NAME@sha256:<64 lowercase hex>, NAME holding a '/'. A tag is refused: a
  ## tag names whatever was pushed last, a digest names one image (NIV-26).
  const shape = "; write NAME@sha256:<64 hex>, for example niuv/builder@sha256:" & repeat('0', 64)
  let at = image.find('@')
  if at < 0:
    return lockErr[LockedBuilder]("builder image '" & image & "' has no @sha256:<digest>" & shape)
  let name = image[0 ..< at]
  let digest = image[at + 1 .. ^1]
  if '/' notin name or name.startsWith("/") or name.endsWith("/") or ':' in name or '@' in name:
    return lockErr[LockedBuilder]("builder image name '" & name & "' must hold a '/' and no tag" & shape)
  if not digest.startsWith("sha256:") or not isLowerHex64(digest[7 .. ^1]):
    return lockErr[LockedBuilder]("builder image digest '" & digest & "' is not sha256:<64 lowercase hex>" & shape)
  ok(LockedBuilder(image: image))

# ---------------------------------------------------------------- building

proc buildLock*(ws: Workspace, tools: seq[ToolInfo], builder = none(LockedBuilder)): NResult[Lock] {.raises: [].} =
  ## Locks every member and every external the members ask for. A name pinned
  ## two ways anywhere in the workspace is refused here.
  var l = Lock(builder: builder)
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
  if l.builder.isSome:
    result.add "\n[builder]\nimage = " & q(l.builder.get.image) & "\n"
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
    if k notin ["lock-version", "builder", "tool", "package", "external"]:
      return lockErr[Lock](file & ": unknown key '" & k & "'")
  let ver = top.getOrDefault("lock-version")
  if ver.isNil or ver.kind != TomlValueKind.Int or ver.intVal != LockVersion:
    return lockErr[Lock](file & ": lock-version must be " & $LockVersion & "; run `niuv lock`")
  var l = Lock()
  let bt = top.getOrDefault("builder")
  if not bt.isNil:
    if bt.kind != TomlValueKind.Table: return lockErr[Lock](file & ": [builder] must be a table")
    let f = ?strKeys(bt.tableVal, ["image"], file, "builder")
    let b = checkBuilderImage(f[0])
    if b.isErr: return lockErr[Lock](file & ": [builder] " & b.error.msg)
    l.builder = some(b.get)
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

proc lockFileName*(target: string): string {.raises: [].} =
  ## `niuv.lock` for no named target, `niuv.<target>.lock` for a named one (NIV-25).
  if target.len == 0: LockFileName else: "niuv." & target & ".lock"

proc lockPath*(ws: Workspace, target = ""): string {.raises: [].} =
  ws.dir / lockFileName(target)

proc writeLockFile*(path: string, l: Lock): NResult[void] {.raises: [].} =
  try:
    writeFile(path, renderLock(l))
  except CatchableError as e:
    return err(niuvError(ekIo, path & ": " & e.msg))
  ok()

proc writeLock*(ws: Workspace, l: Lock, target = ""): NResult[void] {.raises: [].} =
  writeLockFile(lockPath(ws, target), l)

proc readLockFile*(path: string): NResult[Lock] {.raises: [].} =
  if not fileExists(path):
    return lockErr[Lock]("there is no " & path & "; run `niuv lock` first")
  var text: string
  try:
    text = readFile(path)
  except CatchableError as e:
    return err(niuvError(ekIo, path & ": " & e.msg))
  parseLock(text, path)

proc readLock*(ws: Workspace, target = ""): NResult[Lock] {.raises: [].} =
  readLockFile(lockPath(ws, target))

# ---------------------------------------------------------------- checking

proc short(h: string): string {.raises: [].} =
  if h.len > 12: h[0 ..< 12] else: h

proc lockAgain(target: string): string {.raises: [].} =
  if target.len == 0: "; run `niuv lock`" else: "; run `niuv lock --target " & target & "`"

proc checkLock*(l: Lock, ws: Workspace, c: Closure, target = ""): NResult[void] {.raises: [].} =
  ## Every package and external of the closure must be in the lock, where the
  ## lock says, with the content the lock says. `target` names the lock in the
  ## messages only (NIV-25).
  let name = lockFileName(target)
  let again = lockAgain(target)
  for d in c.packages:
    let now = ?lockPackage(ws, d)
    let at = l.packages.filterIt(it.name == d.name)
    if at.len == 0:
      return lockErr[void]("package '" & d.name & "' is not in " & name & again)
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
      return lockErr[void]("external '" & e.name & "' is not in " & name & again)
    if at[0].version != now.version or normalizedSource(at[0].source) != normalizedSource(now.source):
      return lockErr[void]("external '" & e.name & "' is pinned at " & now.version & " (" & now.source &
                           ") but the lock says " & at[0].version & " (" & at[0].source & ")" & again)
    if at[0].sha256 != now.sha256:
      return lockErr[void]("external '" & e.name & "' " & e.version & " changed on disk (" &
                           short(at[0].sha256) & " -> " & short(now.sha256) & ")" & again)
  ok()

proc checkTools*(l: Lock, actual: seq[ToolInfo], target = ""): NResult[void] {.raises: [].} =
  ## Each tool in use must be pinned, at this version, with this executable.
  let name = lockFileName(target)
  for t in actual:
    let at = l.tools.filterIt(it.name == t.name)
    if at.len == 0:
      return err(niuvError(ekTool, "tool " & t.name & " is not pinned in " & name & lockAgain(target)))
    if at[0].version != t.version:
      return err(niuvError(ekTool, "tool " & t.name & " is " & t.version & " (" & t.exe &
                           ") but " & name & " pins " & at[0].version))
    if at[0].sha256 != t.sha256:
      return err(niuvError(ekTool, "tool " & t.name & " " & t.version & ": the executable " & t.exe &
                           " has SHA-256 " & short(t.sha256) & " but " & name & " pins " & short(at[0].sha256)))
  ok()
