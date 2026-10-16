## Building the Gleam packages of a closure (NIV-16, NIV-17).
##
## `gleam` does the compiling. niuv only decides where the sources sit when it
## does, because `gleam build` has no way to be told, from outside, where a
## `path` dependency lives (checked against `gleam --help` 1.19.1; the
## low-level `gleam compile-package` takes already compiled libraries and
## would leave the Hex packages to niuv, which is what `gleam` is for).
##
## What ships is `gleam export erlang-shipment`: the application's own `src`
## and its non-dev dependencies, without `test/`, `dev/` or dev dependencies.

import std/[algorithm, os, sequtils, strutils]
import parsetoml
import ./[artifact, decl, errors, exec, hashing, resolve, sbom, toolchain]

const
  SkipDirs = [".git", ".jj", "build"]
  DependencyTables = ["dependencies", "dev-dependencies", "dev_dependencies"]
  MaxGleamOutput = 8192

type
  GleamPackage = object
    decl: PackageDecl
    dir: string            ## the Gleam root (absolute)
    name: string           ## gleam.toml `name`, which is also the stage directory
    toml: TomlValueRef
    pathDeps: seq[tuple[dep, path: string]]

  GleamResult* = object
    artifacts*: seq[Artifact]
    hex*: seq[Component]   ## Hex packages that were shipped, with their own licenses
    stageDir*: string

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
  for tableName in DependencyTables:
    let t = doc.tableVal.getOrDefault(tableName)
    if t.isNil or t.kind != TomlValueKind.Table: continue
    for dep, v in t.tableVal.pairs:
      if v.kind == TomlValueKind.Table and v.tableVal.hasKey("path"):
        p.pathDeps.add (dep: dep, path: strOf(v.tableVal, "path"))
  ok(p)

proc pathDepDir(p: GleamPackage, path: string): string {.raises: [].} =
  ## Where a gleam.toml path dependency points: relative to the package, or
  ## as written when absolute (os.`/` would glue it under the package).
  if isAbsolute(path): normalizedPath(path) else: normalizedPath(p.dir / path)

proc validate(pkgs: seq[GleamPackage], root: string): NResult[void] {.raises: [].} =
  ## Every path dependency of a Gleam package must be a Gleam package of the
  ## closure, at the place niuv.toml says. Otherwise the staged copy would
  ## build something other than the declared workspace.
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

proc stageKey(pkgs: seq[GleamPackage], gleam, erlang: ToolInfo): NResult[string] {.raises: [].} =
  ## The stage is named for its input: the tools and every package's content.
  var lines = @["gleam " & gleam.version & " " & gleam.sha256, "erlang " & erlang.version & " " & erlang.sha256]
  for p in pkgs.sortedByIt(it.name):
    lines.add p.name & "\0" & ?treeHash(p.dir, SkipDirs)
  ok(sha256Hex(lines.join("\n")))

proc copyPackage(p: GleamPackage, to: string): NResult[void] {.raises: [].} =
  for rel in ?listFiles(p.dir, SkipDirs):
    try:
      createDir(parentDir(to / rel))
      copyFile(p.dir / rel, to / rel)
    except CatchableError as e:
      return err(niuvError(ekIo, p.dir / rel & " -> " & to / rel & ": " & e.msg))
  ok()

proc rewriteGleamToml(p: GleamPackage, to: string): NResult[void] {.raises: [].} =
  ## Path dependencies become `../<gleam name>`: the stage is one directory
  ## per Gleam package, side by side.
  for tableName in DependencyTables:
    let t = p.toml.tableVal.getOrDefault(tableName)
    if t.isNil or t.kind != TomlValueKind.Table: continue
    for dep, v in t.tableVal.pairs:
      if v.kind == TomlValueKind.Table and v.tableVal.hasKey("path"):
        v.tableVal["path"] = newTString("../" & dep)
  try:
    writeFile(to / "gleam.toml", p.toml.toTomlString())
  except Exception as e:
    return err(niuvError(ekIo, to / "gleam.toml" & ": " & e.msg))
  ok()

proc rewriteManifestToml(dir: string): NResult[void] {.raises: [].} =
  ## gleam's own lock keeps the path of every local package; they move with
  ## the staging. Hex entries (version, checksum) are left as gleam wrote them.
  let file = dir / "manifest.toml"
  if not fileExists(file): return ok()
  let doc = ?parseToml(file)
  if doc.kind != TomlValueKind.Table: return buildErr[void](file & ": not a table")
  let packages = doc.tableVal.getOrDefault("packages")
  if not packages.isNil and packages.kind == TomlValueKind.Array:
    for e in packages.arrayVal:
      if e.kind == TomlValueKind.Table and strOf(e.tableVal, "source") == "local":
        e.tableVal["path"] = newTString("../" & strOf(e.tableVal, "name"))
  let reqs = doc.tableVal.getOrDefault("requirements")
  if not reqs.isNil and reqs.kind == TomlValueKind.Table:
    for dep, v in reqs.tableVal.pairs:
      if v.kind == TomlValueKind.Table and v.tableVal.hasKey("path"):
        v.tableVal["path"] = newTString("../" & dep)
  try:
    writeFile(file, doc.toTomlString())
  except Exception as e:
    return err(niuvError(ekIo, file & ": " & e.msg))
  ok()

proc tail(s: string, n: int): string {.raises: [].} =
  if s.len <= n: s else: "..." & s[s.len - n .. ^1]

proc buildGleam*(gleam, erlang: ToolInfo, c: Closure, outDir, stageRoot: string): NResult[GleamResult] {.raises: [].} =
  ## Stages the Gleam packages of the closure under `stageRoot/<input hash>/`,
  ## builds the root's Erlang shipment there with deterministic `.beam`
  ## output, and copies the shipped `.beam` files to `outDir/beam/<app>/`.
  var pkgs: seq[GleamPackage]
  for d in c.packages:
    if d.gleam.present: pkgs.add ?readPackage(d)
  let rootAt = pkgs.mapIt(it.decl.name).find(c.root)
  if rootAt < 0:
    return err(niuvError(ekUsage, "package '" & c.root & "' has no [gleam] table"))
  let rootPkg = pkgs[rootAt]
  ?validate(pkgs, c.root)

  var stageBase: string
  try:
    stageBase = absolutePath(stageRoot)
  except CatchableError as e:
    return err(niuvError(ekIo, stageRoot & ": " & e.msg))
  let stage = stageBase / ?stageKey(pkgs, gleam, erlang)
  var res = GleamResult(stageDir: stage)
  try:
    removeDir(stage)
    createDir(stage)
  except CatchableError as e:
    return err(niuvError(ekIo, stage & ": " & e.msg))
  for p in pkgs:
    ?copyPackage(p, stage / p.name)
    ?rewriteGleamToml(p, stage / p.name)
  ?rewriteManifestToml(stage / rootPkg.name)

  let env = @[("PATH", pathWith([gleam, erlang])), ("ERL_COMPILER_OPTIONS", "deterministic")]
  let run = ?runProcess(gleam.exe, @["export", "erlang-shipment"], workDir = stage / rootPkg.name, env = env)
  if run.code != 0:
    return buildErr[GleamResult]("gleam failed for '" & c.root & "' (exit " & $run.code & "):\n" &
                                 tail(run.output, MaxGleamOutput))

  let shipment = stage / rootPkg.name / "build" / "erlang-shipment"
  var apps: seq[string]
  try:
    for kind, path in walkDir(shipment, relative = true):
      if kind == pcDir: apps.add path
  except CatchableError as e:
    return err(niuvError(ekIo, shipment & ": " & e.msg))
  apps.sort()
  for app in apps:
    let ebin = shipment / app / "ebin"
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
      let to = outDir / "beam" / app / file
      try:
        createDir(parentDir(to))
        copyFile(ebin / file, to)
      except CatchableError as e:
        return err(niuvError(ekIo, ebin / file & " -> " & to & ": " & e.msg))
      res.artifacts.add ?describeFile(name, akBeam, to, rootPkg.decl.gleam.sealed)
    if pkgs.allIt(it.name != app):
      # A Hex package: its license is whatever its own gleam.toml says.
      let hexToml = stage / rootPkg.name / "build" / "packages" / app / "gleam.toml"
      var comp = Component(name: app)
      if fileExists(hexToml):
        let doc = ?parseToml(hexToml)
        if doc.kind == TomlValueKind.Table:
          comp.version = strOf(doc.tableVal, "version")
          let lic = doc.tableVal.getOrDefault("licences")
          if not lic.isNil and lic.kind == TomlValueKind.Array:
            comp.licenses = lic.arrayVal.filterIt(it.kind == TomlValueKind.String).mapIt(it.stringVal)
      res.hex.add comp
  ok(res)
