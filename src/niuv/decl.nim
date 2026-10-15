## The declaration of one package: niuv.toml (NIV-01 .. NIV-06, NIV-10).
##
## Strict on purpose: a key niuv does not know is refused, not ignored, so a
## typo cannot silently leave a flag out of a build.

import std/[os, sequtils, strutils]
import parsetoml
import ./errors

const
  MaxFieldLen = 4096

type
  NimBin* = object
    name*: string
    main*: string          ## relative to the package root
    flags*: seq[string]
    sealed*: bool

  NimSection* = object
    present*: bool
    src*: string           ## relative to the package root
    flags*: seq[string]
    bins*: seq[NimBin]

  GleamSection* = object
    present*: bool
    root*: string          ## relative to the package root
    sealed*: bool

  WasmSection* = object
    present*: bool
    entry*: string         ## relative to the package root
    sealed*: bool

  ExternalDep* = object
    name*: string
    source*: string
    version*: string       ## exactly x.y.z (NIV-10)
    src*: string           ## relative to the dependency's directory
    license*: string       ## "" when not declared; the SBOM then says NOASSERTION

  PackageDecl* = object
    name*, version*, license*: string
    declDir*: string       ## where niuv.toml is
    root*: string          ## the package's own directory (absolute)
    nim*: NimSection
    gleam*: GleamSection
    wasm*: WasmSection
    workspaceDeps*: seq[string]
    externals*: seq[ExternalDep]

  Reader = object
    file: string

proc isNameChar(c: char): bool {.raises: [].} =
  c in {'a'..'z', 'A'..'Z', '0'..'9', '-', '_'}

proc validName*(s: string): bool {.raises: [].} =
  s.len > 0 and s.len <= 128 and s.allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9', '-', '_'})

proc isExactVersion*(s: string): bool {.raises: [].} =
  ## x.y.z, each part digits only.
  let parts = s.split('.')
  if parts.len != 3: return false
  for p in parts:
    if p.len == 0 or p.len > 9 or not p.allCharsInSet(Digits): return false
  true

proc looksLikeRange(s: string): bool {.raises: [].} =
  if s.anyIt(it in {'>', '<', '=', '^', '~', '*', ',', '|', ' '}): return true
  for p in s.split('.'):
    if p in ["x", "X", "*"]: return true
  false

proc fail[T](r: Reader, ctx, msg: string, kind = ekDecl): NResult[T] {.raises: [].} =
  err(niuvError(kind, r.file & ": [" & ctx & "] " & msg))

proc checkKeys(r: Reader, t: TomlTableRef, allowed: openArray[string],
               ctx: string): NResult[void] {.raises: [].} =
  for k in t.keys:
    if k notin allowed:
      return r.fail[:void](ctx, "unknown key '" & k & "'")
  ok()

proc str(r: Reader, t: TomlTableRef, key, ctx: string, required: bool,
         default = ""): NResult[string] {.raises: [].} =
  if not t.hasKey(key):
    if required: return r.fail[:string](ctx, "missing key '" & key & "'")
    return ok(default)
  let v = t.getOrDefault(key)
  if v.kind != TomlValueKind.String:
    return r.fail[:string](ctx, "'" & key & "' must be a string")
  if v.stringVal.len > MaxFieldLen:
    return r.fail[:string](ctx, "'" & key & "' is longer than " & $MaxFieldLen & " bytes")
  if required and v.stringVal.len == 0:
    return r.fail[:string](ctx, "'" & key & "' is empty")
  ok(v.stringVal)

proc flag(r: Reader, t: TomlTableRef, key, ctx: string): NResult[bool] {.raises: [].} =
  if not t.hasKey(key): return ok(false)
  let v = t.getOrDefault(key)
  if v.kind != TomlValueKind.Bool:
    return r.fail[:bool](ctx, "'" & key & "' must be true or false")
  ok(v.boolVal)

proc strings(r: Reader, t: TomlTableRef, key, ctx: string): NResult[seq[string]] {.raises: [].} =
  var items: seq[string]
  if not t.hasKey(key): return ok(items)
  let v = t.getOrDefault(key)
  if v.kind != TomlValueKind.Array:
    return r.fail[:seq[string]](ctx, "'" & key & "' must be an array of strings")
  for e in v.arrayVal:
    if e.kind != TomlValueKind.String or e.stringVal.len > MaxFieldLen:
      return r.fail[:seq[string]](ctx, "'" & key & "' must hold strings only")
    items.add e.stringVal
  ok(items)

proc table(r: Reader, t: TomlTableRef, key, ctx: string): NResult[TomlTableRef] {.raises: [].} =
  let v = t.getOrDefault(key)
  if v.kind != TomlValueKind.Table:
    return r.fail[:TomlTableRef](ctx, "'" & key & "' must be a table")
  ok(v.tableVal)

proc readPackage(r: Reader, t: TomlTableRef, d: var PackageDecl): NResult[void] {.raises: [].} =
  const ctx = "package"
  ?r.checkKeys(t, ["name", "version", "license", "root"], ctx)
  d.name = ?r.str(t, "name", ctx, true)
  if not validName(d.name):
    return r.fail[:void](ctx, "name '" & d.name & "' may hold letters, digits, '-' and '_' only")
  d.version = ?r.str(t, "version", ctx, true)
  if not isExactVersion(d.version):
    return r.fail[:void](ctx, "version '" & d.version & "' is not x.y.z")
  d.license = ?r.str(t, "license", ctx, true)
  let rootRel = ?r.str(t, "root", ctx, false)
  d.root =
    if rootRel.len == 0: d.declDir
    elif rootRel.isAbsolute: normalizedPath(rootRel)
    else: normalizedPath(d.declDir / rootRel)
  ok()

proc readNim(r: Reader, t: TomlTableRef, d: var PackageDecl): NResult[void] {.raises: [].} =
  const ctx = "nim"
  ?r.checkKeys(t, ["src", "flags", "bin"], ctx)
  d.nim.present = true
  d.nim.src = ?r.str(t, "src", ctx, false, "src")
  d.nim.flags = ?r.strings(t, "flags", ctx)
  if t.hasKey("bin"):
    let v = t.getOrDefault("bin")
    if v.kind != TomlValueKind.Array:
      return r.fail[:void](ctx, "'bin' must be an array of tables ([[nim.bin]])")
    for e in v.arrayVal:
      if e.kind != TomlValueKind.Table:
        return r.fail[:void](ctx, "'bin' must be an array of tables ([[nim.bin]])")
      let bt = e.tableVal
      const bctx = "nim.bin"
      ?r.checkKeys(bt, ["name", "main", "flags", "sealed"], bctx)
      var b = NimBin()
      b.name = ?r.str(bt, "name", bctx, true)
      if not validName(b.name):
        return r.fail[:void](bctx, "name '" & b.name & "' may hold letters, digits, '-' and '_' only")
      for other in d.nim.bins:
        if other.name == b.name:
          return r.fail[:void](bctx, "two bins are named '" & b.name & "'")
      b.main = ?r.str(bt, "main", bctx, true)
      b.flags = ?r.strings(bt, "flags", bctx)
      b.sealed = ?r.flag(bt, "sealed", bctx)
      d.nim.bins.add b
  ok()

proc readGleam(r: Reader, t: TomlTableRef, d: var PackageDecl): NResult[void] {.raises: [].} =
  const ctx = "gleam"
  ?r.checkKeys(t, ["root", "sealed"], ctx)
  d.gleam.present = true
  d.gleam.root = ?r.str(t, "root", ctx, false, ".")
  d.gleam.sealed = ?r.flag(t, "sealed", ctx)
  ok()

proc readWasm(r: Reader, t: TomlTableRef, d: var PackageDecl): NResult[void] {.raises: [].} =
  const ctx = "wasm"
  ?r.checkKeys(t, ["entry", "sealed"], ctx)
  d.wasm.present = true
  d.wasm.entry = ?r.str(t, "entry", ctx, true)
  d.wasm.sealed = ?r.flag(t, "sealed", ctx)
  ok()

proc readExternal(r: Reader, name: string, t: TomlTableRef): NResult[ExternalDep] {.raises: [].} =
  let ctx = "dependencies.external." & name
  if not validName(name):
    return r.fail[:ExternalDep](ctx, "name '" & name & "' may hold letters, digits, '-' and '_' only")
  ?r.checkKeys(t, ["source", "version", "src", "license"], ctx)
  var e = ExternalDep(name: name)
  e.source = ?r.str(t, "source", ctx, true)
  e.version = ?r.str(t, "version", ctx, true)
  if not isExactVersion(e.version):
    if looksLikeRange(e.version):
      return r.fail[:ExternalDep](ctx,
        "version '" & e.version & "' is a range; only an exact x.y.z is accepted", ekRange)
    return r.fail[:ExternalDep](ctx, "version '" & e.version & "' is not x.y.z")
  e.src = ?r.str(t, "src", ctx, false, ".")
  e.license = ?r.str(t, "license", ctx, false)
  ok(e)

proc readDependencies(r: Reader, t: TomlTableRef, d: var PackageDecl): NResult[void] {.raises: [].} =
  const ctx = "dependencies"
  ?r.checkKeys(t, ["workspace", "external"], ctx)
  d.workspaceDeps = ?r.strings(t, "workspace", ctx)
  if t.hasKey("external"):
    let ext = ?r.table(t, "external", ctx)
    for name, v in ext.pairs:
      if v.kind != TomlValueKind.Table:
        return r.fail[:void](ctx, "external '" & name & "' must be a table")
      d.externals.add ?r.readExternal(name, v.tableVal)
  ok()

proc parseDeclText*(text, fileName, declDir: string): NResult[PackageDecl] {.raises: [].} =
  ## `fileName` only appears in messages; `declDir` is where the declaration
  ## lives and is the base of `[package] root`.
  let r = Reader(file: fileName)
  var doc: TomlValueRef
  try:
    doc = parseString(text, fileName)
  except Exception as e:
    # parsetoml declares no raises list; its failures are TomlError and
    # ValueError. The message goes to the caller as an error value.
    return err(niuvError(ekDecl, fileName & ": " & e.msg))
  if doc.kind != TomlValueKind.Table:
    return r.fail[:PackageDecl]("", "not a table")
  let top = doc.tableVal
  ?r.checkKeys(top, ["package", "nim", "gleam", "wasm", "dependencies"], "top level")
  if not top.hasKey("package"):
    return r.fail[:PackageDecl]("package", "missing table [package]")
  var d = PackageDecl(declDir: normalizedPath(declDir))
  ?r.readPackage(?r.table(top, "package", "top level"), d)
  if top.hasKey("nim"): ?r.readNim(?r.table(top, "nim", "top level"), d)
  if top.hasKey("gleam"): ?r.readGleam(?r.table(top, "gleam", "top level"), d)
  if top.hasKey("wasm"): ?r.readWasm(?r.table(top, "wasm", "top level"), d)
  if top.hasKey("dependencies"): ?r.readDependencies(?r.table(top, "dependencies", "top level"), d)
  ok(d)

proc parseDeclFile*(path: string): NResult[PackageDecl] {.raises: [].} =
  var text, dir: string
  try:
    text = readFile(path)
    dir = parentDir(absolutePath(path))
  except CatchableError as e:
    return err(niuvError(ekIo, path & ": " & e.msg))
  parseDeclText(text, path, dir)

proc inRoot*(d: PackageDecl, rel: string): string {.raises: [].} =
  ## A path of the declaration, counted from the package root.
  if rel.isAbsolute: normalizedPath(rel) else: normalizedPath(d.root / rel)

proc nimSrcDir*(d: PackageDecl): string {.raises: [].} =
  d.inRoot(d.nim.src)
