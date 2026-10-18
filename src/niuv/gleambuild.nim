## Building the Gleam packages of a closure (NIV-16, NIV-17).
##
## niuv compiles the packages itself, one `gleam compile-package` per package,
## in dependency order, and never lets `gleam` resolve versions: no Hex query,
## no `manifest.toml` handling, no config fingerprints (a fresh work place
## with a `path` dependency makes `gleam build` and `gleam export` ask the Hex
## registry even when `manifest.toml` locks everything, which a guest without
## a network cannot answer; checked against gleam 1.19.1).
##
## The local packages are compiled from where they are. The Hex packages come
## from gleam's Hex copy (`<cache>/<OUTER CHECKSUM>.tar`), checked against the
## `outer_checksum` of the root's `manifest.toml` and unpacked into the stage.
## What ships is the `ebin/*.beam` of every package of the (non-dev) closure.
## Not shipped, unlike `gleam export erlang-shipment`: the `<app>@@main`
## entry point module and the `entrypoint` scripts.

import std/[algorithm, os, sequtils, strutils, tables]
import parsetoml
import ./[artifact, decl, errors, exec, hashing, lock, resolve, sbom, toolchain, workspace]

const
  MaxGleamOutput = 8192

type
  GleamPackage = object
    decl: PackageDecl
    dir: string            ## the Gleam root (absolute)
    name: string           ## gleam.toml `name`, which is also the application
    toml: TomlValueRef
    pathDeps: seq[tuple[dep, path: string]]
    hexDeps: seq[string]   ## [dependencies] entries that are not `path`

  HexPackage = object
    name, version, checksum, otpApp: string
    requirements: seq[string]

  GleamResult* = object
    artifacts*: seq[Artifact]
    hex*: seq[Component]   ## Hex packages that were shipped, with their own licenses
    stageDir*: string

  Unit = object            ## one `gleam compile-package`
    name, app, dir: string
    deps: seq[string]      ## direct dependencies (unit names)

proc defaultHexCache*(): string {.raises: [].} =
  ## Where gleam keeps the Hex packages it downloaded on this machine.
  let home = getHomeDir()
  if hostOS == "macosx": home / "Library" / "Caches" / "gleam" / "hex" / "hexpm" / "packages"
  else: home / ".cache" / "gleam" / "hex" / "hexpm" / "packages"

proc buildErr[T](msg: string): NResult[T] {.raises: [].} =
  err(niuvError(ekBuild, msg))

proc parseToml(path: string): NResult[TomlValueRef] {.raises: [].} =
  var text: string
  try:
    text = readFile(path)
  except CatchableError as e:
    return err(niuvError(ekIo, path & ": " & e.msg))
  try:
    ok(parseString(text, path))
  except Exception as e:
    # parsetoml declares no raises list; the message goes out as an error value.
    buildErr[TomlValueRef](path & ": " & e.msg)

proc strOf(t: TomlTableRef, key: string): string {.raises: [].} =
  let v = t.getOrDefault(key)
  if v.isNil or v.kind != TomlValueKind.String: "" else: v.stringVal

proc readPackage(d: PackageDecl): NResult[GleamPackage] {.raises: [].} =
  let dir = d.inRoot(d.gleam.root)
  let doc = ?parseToml(dir / "gleam.toml")
  if doc.kind != TomlValueKind.Table:
    return buildErr[GleamPackage](dir / "gleam.toml" & ": not a table")
  var p = GleamPackage(decl: d, dir: dir, name: strOf(doc.tableVal, "name"), toml: doc)
  if p.name.len == 0:
    return buildErr[GleamPackage](dir / "gleam.toml" & ": no name")
  # Only [dependencies]: dev dependencies are not compiled (`--no-dev`), not shipped.
  let t = doc.tableVal.getOrDefault("dependencies")
  if not t.isNil and t.kind == TomlValueKind.Table:
    for dep, v in t.tableVal.pairs:
      if v.kind == TomlValueKind.Table and v.tableVal.hasKey("path"):
        p.pathDeps.add (dep: dep, path: strOf(v.tableVal, "path"))
      else:
        p.hexDeps.add dep
  ok(p)

proc pathDepDir(p: GleamPackage, path: string): string {.raises: [].} =
  ## Where a gleam.toml path dependency points: relative to the package, or
  ## as written when absolute (os.`/` would glue it under the package).
  if isAbsolute(path): normalizedPath(path) else: normalizedPath(p.dir / path)

proc validate(pkgs: seq[GleamPackage], root: string): NResult[void] {.raises: [].} =
  ## Every path dependency of a Gleam package must be a Gleam package of the
  ## closure, at the place niuv.toml says. Otherwise the build would compile
  ## something other than the declared workspace.
  for i, p in pkgs:
    for j in 0 ..< i:
      if pkgs[j].name == p.name:
        return buildErr[void]("two Gleam packages are named '" & p.name & "': " & pkgs[j].dir & " and " & p.dir)
  for p in pkgs:
    for pd in p.pathDeps:
      let found = pkgs.filterIt(it.name == pd.dep)
      if found.len == 0:
        return buildErr[void]("gleam.toml of '" & p.name & "' has a path dependency '" & pd.dep & "' (" &
          p.pathDepDir(pd.path) & ") that is no Gleam package of the closure of '" & root &
          "'; add its package to [dependencies].workspace in niuv.toml")
      let wanted = p.pathDepDir(pd.path)
      if wanted != found[0].dir:
        return buildErr[void]("gleam.toml of '" & p.name & "' points '" & pd.dep & "' at " & wanted &
          " but the workspace package '" & found[0].decl.name & "' is at " & found[0].dir)
  ok()

# ------------------------------------------------------------ the Hex packages

proc readHexLock(manifest: string): NResult[Table[string, HexPackage]] {.raises: [].} =
  ## The Hex entries of the root's `manifest.toml` (gleam's own lock). It is
  ## read, not written, and not checked against any range: niuv builds exactly
  ## these versions.
  var res = initTable[string, HexPackage]()
  if not fileExists(manifest): return ok(res)
  let doc = ?parseToml(manifest)
  if doc.kind != TomlValueKind.Table: return buildErr[Table[string, HexPackage]](manifest & ": not a table")
  let packages = doc.tableVal.getOrDefault("packages")
  if packages.isNil or packages.kind != TomlValueKind.Array: return ok(res)
  for e in packages.arrayVal:
    if e.kind != TomlValueKind.Table or strOf(e.tableVal, "source") != "hex": continue
    var h = HexPackage(name: strOf(e.tableVal, "name"), version: strOf(e.tableVal, "version"),
                       checksum: strOf(e.tableVal, "outer_checksum").toUpperAscii, otpApp: strOf(e.tableVal, "otp_app"))
    if h.otpApp.len == 0: h.otpApp = h.name
    let reqs = e.tableVal.getOrDefault("requirements")
    if not reqs.isNil and reqs.kind == TomlValueKind.Array:
      h.requirements = reqs.arrayVal.filterIt(it.kind == TomlValueKind.String).mapIt(it.stringVal)
    if h.name.len == 0 or h.checksum.len != 64:
      return buildErr[Table[string, HexPackage]](manifest & ": a Hex entry without a name or a 64-character outer_checksum")
    res[h.name] = h
  ok(res)

proc neededHex(pkgs: seq[GleamPackage], lock: Table[string, HexPackage], manifest: string): NResult[seq[HexPackage]] {.raises: [].} =
  ## The Hex packages the closure needs (non-dev), with their own requirements.
  var want: seq[string]
  for p in pkgs:
    for d in p.hexDeps:
      if d notin want: want.add d
  var seen: seq[string]
  var found: seq[HexPackage]
  while want.len > 0:
    let n = want.pop()
    if n in seen: continue
    seen.add n
    if n in pkgs.mapIt(it.name):
      return buildErr[seq[HexPackage]]("'" & n & "' is both a Hex dependency and a Gleam package of the closure")
    if n notin lock:
      return buildErr[seq[HexPackage]]("the Hex package '" & n & "' is not in " & manifest &
        " (the root's gleam lock decides the Hex versions; add it with `gleam deps download`)")
    let h = lock.getOrDefault(n)
    found.add h
    for r in h.requirements: want.add r
  found.sort(proc (a, b: HexPackage): int = cmp(a.name, b.name))
  ok(found)

proc checkArchiveNames(tar, archive: string, gz: bool): NResult[void] {.raises: [].} =
  let r = ?runProcess(tar, @[(if gz: "-tzf" else: "-tf"), archive])
  if r.code != 0:
    return buildErr[void](archive & " is not a readable archive: " & r.output.strip())
  for line in r.output.splitLines:
    let n = line.strip()
    if n.len == 0: continue
    if n.startsWith("/") or ".." in n.split('/'):
      return buildErr[void](archive & " holds '" & n & "', a path outside its own directory")
  ok()

proc unpackHex(h: HexPackage, cache, to: string): NResult[void] {.raises: [].} =
  ## `<cache>/<OUTER CHECKSUM>.tar` holds `contents.tar.gz`. The archive is
  ## hashed first and must be the one the lock names.
  let tarball = cache / (h.checksum & ".tar")
  if not fileExists(tarball):
    return buildErr[void]("the Hex package " & h.name & " " & h.version & " is not in the Hex copy " & cache &
      " (" & h.checksum & ".tar; `gleam deps download` in a package that needs it fills gleam's copy)")
  let got = (?sha256File(tarball)).toUpperAscii
  if got != h.checksum:
    return buildErr[void](tarball & " has SHA-256 " & got & " but the lock says " & h.checksum)
  var tar = ""
  try:
    # Not followed: busybox's tar is a link to busybox, which picks the applet from the name it is started under.
    tar = findExe("tar", followSymlinks = false)
  except CatchableError as e:
    return err(niuvError(ekIo, "searching PATH for tar: " & e.msg))
  if tar.len == 0: return buildErr[void]("no tar on PATH to unpack " & tarball)
  ?checkArchiveNames(tar, tarball, false)
  let outer = to & ".outer"
  try:
    removeDir(outer)
    createDir(outer)
    createDir(to)
  except CatchableError as e:
    return err(niuvError(ekIo, to & ": " & e.msg))
  let x = ?runProcess(tar, @["-xf", tarball, "-C", outer])
  if x.code != 0: return buildErr[void]("unpacking " & tarball & ": " & x.output.strip())
  let contents = outer / "contents.tar.gz"
  if not fileExists(contents): return buildErr[void](tarball & " holds no contents.tar.gz")
  ?checkArchiveNames(tar, contents, true)
  let y = ?runProcess(tar, @["-xzf", contents, "-C", to])
  if y.code != 0: return buildErr[void]("unpacking " & contents & ": " & y.output.strip())
  try:
    removeDir(outer)
    for p in walkDirRec(to, yieldFilter = {pcFile, pcDir, pcLinkToFile, pcLinkToDir}):
      if symlinkExists(p): return buildErr[void](tarball & " holds a symbolic link: " & p)
  except CatchableError as e:
    return err(niuvError(ekIo, to & ": " & e.msg))
  ok()

# ------------------------------------------------------------ the build

proc tail(s: string, n: int): string {.raises: [].} =
  if s.len <= n: s else: "..." & s[s.len - n .. ^1]

proc stageKey(pkgs: seq[GleamPackage], hex: seq[HexPackage], gleam, erlang: ToolInfo, ws: Workspace): NResult[string] {.raises: [].} =
  ## The stage is named for its input: the tools, every package's content (the
  ## workspace directory is not part of it, NIV-33) and the Hex archives' checksums.
  var lines = @["gleam " & gleam.version & " " & gleam.sha256, "erlang " & erlang.version & " " & erlang.sha256]
  for p in pkgs.sortedByIt(it.name):
    lines.add p.name & "\0" & ?treeHash(p.dir, [".git", ".jj", "build"], ?workspaceSkips(ws, p.dir))
  for h in hex:
    lines.add "hex " & h.name & " " & h.version & " " & h.checksum
  ok(sha256Hex(lines.join("\n")))

proc order(units: seq[Unit], root: string): NResult[seq[Unit]] {.raises: [].} =
  ## Dependencies first, depth first from the root, names in order.
  var done: seq[string]
  var active: seq[string]
  var res: seq[Unit]
  proc visit(n: string): NResult[void] {.raises: [].} =
    if n in done: return ok()
    if n in active: return buildErr[void]("a dependency cycle through '" & n & "'")
    active.add n
    let found = units.filterIt(it.name == n)
    if found.len == 0: return buildErr[void]("nothing provides the dependency '" & n & "'")
    let u = found[0]
    for d in u.deps.sorted:
      ?visit(d)
    discard active.pop()
    done.add n
    res.add u
    ok()
  ?visit(root)
  ok(res)

proc buildGleam*(gleam, erlang: ToolInfo, ws: Workspace, c: Closure, outDir, stageRoot: string,
                 hexCache = ""): NResult[GleamResult] {.raises: [].} =
  ## Compiles the Gleam packages of the closure (and the Hex packages the root's
  ## `manifest.toml` pins for them) under `stageRoot/<input hash>/` and copies
  ## the shipped `.beam` files to `outDir/beam/<app>/`.
  var pkgs: seq[GleamPackage]
  for d in c.packages:
    if d.gleam.present: pkgs.add ?readPackage(d)
  let rootAt = pkgs.mapIt(it.decl.name).find(c.root)
  if rootAt < 0:
    return err(niuvError(ekUsage, "package '" & c.root & "' has no [gleam] table"))
  let rootPkg = pkgs[rootAt]
  ?validate(pkgs, c.root)
  let manifest = rootPkg.dir / "manifest.toml"
  let hexPkgs = ?neededHex(pkgs, ?readHexLock(manifest), manifest)
  let cache = if hexCache.len > 0: hexCache else: defaultHexCache()

  var stageBase: string
  try:
    stageBase = absolutePath(stageRoot)
  except CatchableError as e:
    return err(niuvError(ekIo, stageRoot & ": " & e.msg))
  let stage = stageBase / ?stageKey(pkgs, hexPkgs, gleam, erlang, ws)
  var res = GleamResult(stageDir: stage)
  try:
    removeDir(stage)
    createDir(stage / "lib")
    createDir(stage / "libs")
  except CatchableError as e:
    return err(niuvError(ekIo, stage & ": " & e.msg))

  var units: seq[Unit]
  for p in pkgs:
    units.add Unit(name: p.name, app: p.name, dir: p.dir, deps: p.pathDeps.mapIt(it.dep) & p.hexDeps)
  var otpNames: seq[string]
  for h in hexPkgs:
    let dir = stage / "src" / h.name
    ?unpackHex(h, cache, dir)
    units.add Unit(name: h.name, app: h.otpApp, dir: dir, deps: h.requirements)
    if h.otpApp != h.name: otpNames.add h.name & "=" & h.otpApp
  let compileOrder = ?order(units, rootPkg.name)

  let env = @[("PATH", pathWith([gleam, erlang])), ("ERL_COMPILER_OPTIONS", "deterministic")]
  for u in compileOrder:
    # Each package sees only its (transitive) dependencies, as `gleam build` would.
    let libs = stage / "libs" / u.name
    var reach: seq[string]
    var todo = u.deps
    while todo.len > 0:
      let n = todo.pop()
      if n in reach: continue
      reach.add n
      todo.add units.filterIt(it.name == n)[0].deps  # `order` has already refused a dependency nothing provides
    try:
      createDir(libs)
      for n in reach: createSymlink(stage / "lib" / n, libs / n)
    except CatchableError as e:
      return err(niuvError(ekIo, libs & ": " & e.msg))
    var args = @["compile-package", "--target", "erlang", "--package", u.dir, "--out", stage / "lib" / u.name,
                 "--lib", libs, "--no-dev"]
    if otpNames.len > 0: args.add ["--otp-app-names", otpNames.join(",")]
    let run = ?runProcess(gleam.exe, args, env = env)
    if run.code != 0:
      return buildErr[GleamResult]("gleam failed compiling '" & u.name & "' for '" & c.root & "' (exit " & $run.code &
                                   "):\n" & tail(run.output, MaxGleamOutput))

  for u in compileOrder.sortedByIt(it.app):
    let ebin = stage / "lib" / u.name / "ebin"
    var beams: seq[string]
    try:
      for kind, path in walkDir(ebin, relative = true):
        if kind == pcFile and path.endsWith(".beam"): beams.add path
    except CatchableError as e:
      return err(niuvError(ekIo, ebin & ": " & e.msg))
    beams.sort()
    for file in beams:
      let name = file[0 ..< file.len - 5]
      if res.artifacts.anyIt(it.name == name):
        return buildErr[GleamResult]("the module '" & name & "' is shipped by two applications")
      let to = outDir / "beam" / u.app / file
      try:
        createDir(parentDir(to))
        copyFile(ebin / file, to)
      except CatchableError as e:
        return err(niuvError(ekIo, ebin / file & " -> " & to & ": " & e.msg))
      res.artifacts.add ?describeFile(name, akBeam, to, rootPkg.decl.gleam.sealed)
    if pkgs.allIt(it.name != u.name):
      # A Hex package: its license is whatever its own gleam.toml says.
      let hexToml = u.dir / "gleam.toml"
      var comp = Component(name: u.app, version: hexPkgs.filterIt(it.name == u.name)[0].version)
      if fileExists(hexToml):
        let doc = ?parseToml(hexToml)
        if doc.kind == TomlValueKind.Table:
          let lic = doc.tableVal.getOrDefault("licences")
          if not lic.isNil and lic.kind == TomlValueKind.Array:
            comp.licenses = lic.arrayVal.filterIt(it.kind == TomlValueKind.String).mapIt(it.stringVal)
      res.hex.add comp
  ok(res)
