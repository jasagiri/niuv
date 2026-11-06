## The workspace niuv.workspace.toml (NIV-07): which directories are packages,
## which tools are pinned, and where external dependencies are looked for.

import std/[options, os, strutils, tables]
import parsetoml
import ./[decl, errors]

const
  KnownTools* = ["erlang", "gleam", "kite", "nim"]
  HostOnlyTools* = ["kite"]   ## runs on the host that starts a builder guest; no Linux target pins it

type
  ToolSpec* = object
    name*: string
    version*: string
    via*: string           ## "" (look on PATH) or "mise"

  Workspace* = object
    file*: string          ## absolute path of niuv.workspace.toml
    dir*: string           ## its directory
    packages*: seq[PackageDecl]   ## in the order of `members`
    tools*: seq[ToolSpec]         ## sorted by name
    externalRoots*: seq[string]   ## absolute

proc find*(ws: Workspace, name: string): Option[PackageDecl] {.raises: [].} =
  for p in ws.packages:
    if p.name == name: return some(p)
  none(PackageDecl)

proc tool*(ws: Workspace, name: string): Option[ToolSpec] {.raises: [].} =
  for t in ws.tools:
    if t.name == name: return some(t)
  none(ToolSpec)

proc wsErr[T](file, msg: string): NResult[T] {.raises: [].} =
  err(niuvError(ekWorkspace, file & ": " & msg))

proc expandPath(s, baseDir: string): NResult[string] {.raises: [].} =
  ## `~`, `$NAME`, then relative to `baseDir`. An unset variable is an error,
  ## not an empty string.
  var rest = s
  var home = ""
  if rest == "~" or rest.startsWith("~/"):
    home = getEnv("HOME")
    if home.len == 0:
      return err(niuvError(ekWorkspace, "'" & s & "': HOME is not set"))
    rest = home & rest[1 .. ^1]
  var outp = ""
  var i = 0
  while i < rest.len:
    if rest[i] == '$':
      var j = i + 1
      while j < rest.len and (rest[j].isAlphaNumeric or rest[j] == '_'): inc j
      let name = rest[i + 1 ..< j]
      if name.len == 0:
        return err(niuvError(ekWorkspace, "'" & s & "': a '$' without a variable name"))
      if not existsEnv(name):
        return err(niuvError(ekWorkspace, "'" & s & "': the variable " & name & " is not set"))
      outp.add getEnv(name)
      i = j
    else:
      outp.add rest[i]
      inc i
  ok(if outp.isAbsolute: normalizedPath(outp) else: normalizedPath(baseDir / outp))

proc checkMember(file: string, d: PackageDecl): NResult[void] {.raises: [].} =
  ## The paths a declaration names must exist; a build must not discover
  ## them one failure at a time.
  proc missing(what, path: string): NResult[void] {.raises: [].} =
    wsErr[void](file, "package '" & d.name & "': " & what & " " & path & " does not exist")
  if not dirExists(d.root): return missing("the package root", d.root)
  if d.nim.present:
    if not dirExists(d.nimSrcDir): return missing("nim src", d.nimSrcDir)
    for b in d.nim.bins:
      if not fileExists(d.inRoot(b.main)): return missing("the main of bin '" & b.name & "'", d.inRoot(b.main))
  if d.gleam.present:
    let gt = d.inRoot(d.gleam.root) / "gleam.toml"
    if not fileExists(gt): return missing("the gleam root's gleam.toml", gt)
  let wsDir = parentDir(file)
  for c in d.wasm.components:
    # NIV-50: what a component names stays inside the workspace and exists.
    var named = @[("entry", c.entry), ("wit", c.wit)]
    for p in c.paths: named.add ("paths", p)
    for (what, rel) in named:
      let p = d.inRoot(rel)
      if not (p == wsDir or p.startsWith(wsDir & "/")):
        return wsErr[void](file, "package '" & d.name & "': wasm component '" & c.name & "' " & what &
                                 " " & rel & " leaves the workspace " & wsDir)
    if not fileExists(d.inRoot(c.entry)):
      return missing("the entry of wasm component '" & c.name & "'", d.inRoot(c.entry))
    if not dirExists(d.inRoot(c.wit)):
      return missing("the wit directory of wasm component '" & c.name & "'", d.inRoot(c.wit))
    for p in c.paths:
      if not dirExists(d.inRoot(p)): return missing("the path of wasm component '" & c.name & "'", d.inRoot(p))
  ok()

proc allowOnly(t: TomlTableRef, allowed: openArray[string], file, ctx: string): NResult[void] {.raises: [].} =
  for k in t.keys:
    if k notin allowed: return wsErr[void](file, "[" & ctx & "] unknown key '" & k & "'")
  ok()

proc readStrings(t: TomlTableRef, key, file, ctx: string): NResult[seq[string]] {.raises: [].} =
  var items: seq[string]
  let v = t.getOrDefault(key)
  if v.isNil: return ok(items)
  if v.kind != TomlValueKind.Array:
    return wsErr[seq[string]](file, "[" & ctx & "] '" & key & "' must be an array of strings")
  for e in v.arrayVal:
    if e.kind != TomlValueKind.String or e.stringVal.len == 0 or e.stringVal.len > 4096:
      return wsErr[seq[string]](file, "[" & ctx & "] '" & key & "' must hold non-empty strings")
    items.add e.stringVal
  ok(items)

proc subTable(t: TomlTableRef, key, file: string): NResult[TomlTableRef] {.raises: [].} =
  let v = t.getOrDefault(key)
  if v.isNil: return ok(TomlTableRef(nil))
  if v.kind != TomlValueKind.Table:
    return wsErr[TomlTableRef](file, "'" & key & "' must be a table")
  ok(v.tableVal)

proc readTools(t: TomlTableRef, file: string): NResult[seq[ToolSpec]] {.raises: [].} =
  var tools: seq[ToolSpec]
  if t.isNil: return ok(tools)
  for name, v in t.pairs:
    if name notin KnownTools:
      return wsErr[seq[ToolSpec]](file, "[tools." & name & "] niuv drives " & KnownTools.join(", ") & " only")
    if v.kind != TomlValueKind.Table:
      return wsErr[seq[ToolSpec]](file, "[tools." & name & "] must be a table")
    ?allowOnly(v.tableVal, ["version", "via"], file, "tools." & name)
    let ver = v.tableVal.getOrDefault("version")
    if ver.isNil or ver.kind != TomlValueKind.String:
      return wsErr[seq[ToolSpec]](file, "[tools." & name & "] 'version' must be a string")
    if not isExactVersion(ver.stringVal):
      let kind = if ver.stringVal.len > 0 and ver.stringVal[0] in {'>', '<', '=', '^', '~', '*'}: ekRange else: ekWorkspace
      return err(niuvError(kind, file & ": [tools." & name & "] version '" & ver.stringVal &
                           "' is not an exact x.y.z"))
    var via = ""
    let vv = v.tableVal.getOrDefault("via")
    if not vv.isNil:
      if vv.kind != TomlValueKind.String or vv.stringVal notin ["mise"]:
        return wsErr[seq[ToolSpec]](file, "[tools." & name & "] 'via' must be \"mise\"")
      via = vv.stringVal
    tools.add ToolSpec(name: name, version: ver.stringVal, via: via)
  ok(tools)

proc loadWorkspace*(file: string): NResult[Workspace] {.raises: [].} =
  var text, dir, absFile: string
  try:
    text = readFile(file)
    absFile = normalizedPath(absolutePath(file))
    dir = parentDir(absFile)
  except CatchableError as e:
    return err(niuvError(ekIo, file & ": " & e.msg))
  var doc: TomlValueRef
  try:
    doc = parseString(text, file)
  except Exception as e:
    # parsetoml declares no raises list; the message goes out as an error value.
    return wsErr[Workspace](file, e.msg)
  if doc.kind != TomlValueKind.Table:
    return wsErr[Workspace](file, "not a table")
  ?allowOnly(doc.tableVal, ["workspace", "tools", "external"], file, "top level")
  let wsTable = ?subTable(doc.tableVal, "workspace", file)
  if wsTable.isNil: return wsErr[Workspace](file, "missing table [workspace]")
  ?allowOnly(wsTable, ["members"], file, "workspace")
  let members = ?readStrings(wsTable, "members", file, "workspace")
  if members.len == 0: return wsErr[Workspace](file, "[workspace] members is empty")

  var ws = Workspace(file: absFile, dir: dir)
  var seenDirs: seq[string]
  for m in members:
    let mdir = normalizedPath(dir / m)
    if mdir in seenDirs: return wsErr[Workspace](file, "member " & m & " is listed twice")
    seenDirs.add mdir
    let declFile = mdir / "niuv.toml"
    if not fileExists(declFile):
      return wsErr[Workspace](file, "member " & m & " has no niuv.toml (" & declFile & ")")
    let d = ?parseDeclFile(declFile)
    ?checkMember(file, d)
    for other in ws.packages:
      if other.name == d.name:
        return wsErr[Workspace](file, "the name '" & d.name & "' is declared twice: " &
                                other.declDir & " and " & d.declDir)
    ws.packages.add d

  ws.tools = ?readTools(?subTable(doc.tableVal, "tools", file), file)
  let ext = ?subTable(doc.tableVal, "external", file)
  if not ext.isNil:
    ?allowOnly(ext, ["roots"], file, "external")
    for r in ?readStrings(ext, "roots", file, "external"):
      ws.externalRoots.add ?expandPath(r, dir)
  ok(ws)
