## E tests for the Gleam build: NIV-16 (plumbing) and NIV-17 (fixed bytes).

import std/[algorithm, os, osproc, sequtils, strutils, unittest]
import ../../src/niuv/[artifact, errors, gleambuild, hashing, resolve, workspace]
import support

const testFile* = "tests/unit/test_gleambuild.nim"

proc pkgToml(name: string, extra = ""): string =
  "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n" & extra

## `app` (gleam name `app`) depends on `lib` (gleam name `lib_gl`), which sits
## at a different depth: the path in app's gleam.toml is not `../lib`.
proc makeWorkspace(dir: string, appGleamDeps = "lib_gl = { path = \"../deep/lib\" }\n",
                   niuvDeps = "[dependencies]\nworkspace = [\"lib\"]\n", withManifest = false,
                   hexSum = ""): Workspace =
  writeTree(dir, {
    "app/niuv.toml": pkgToml("app", "\n[gleam]\n" & niuvDeps),
    "app/gleam.toml": "name = \"app\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\nlicences = [\"Apache-2.0\"]\n\n" &
      "[dependencies]\n" & appGleamDeps,
    "app/src/app.gleam": (if hexSum.len > 0: "import hexlib\nimport lib_gl\n\npub fn run() -> Int {\n  lib_gl.answer() + hexlib.one()\n}\n"
                          else: "import lib_gl\n\npub fn run() -> Int {\n  lib_gl.answer()\n}\n"),
    "app/src/app_ffi.erl": "-module(app_ffi).\n-export([ping/0]).\nping() -> ok.\n",
    "app/test/app_test.gleam": "pub fn main() {\n  Nil\n}\n",
    "deep/lib/niuv.toml": pkgToml("lib", "\n[gleam]\n"),
    "deep/lib/gleam.toml": "name = \"lib_gl\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\nlicences = [\"MIT\"]\n",
    "deep/lib/src/lib_gl.gleam": "pub fn answer() -> Int {\n  42\n}\n",
    "niuv.workspace.toml": "[workspace]\nmembers = [\"app\", \"deep/lib\"]\n"})
  if hexSum.len > 0:
    writeFile(dir / "app" / "gleam.toml", readFile(dir / "app" / "gleam.toml") & "hexlib = \">= 1.0.0 and < 2.0.0\"\n")
    writeFile(dir / "app" / "manifest.toml",
      "packages = [\n" &
      "  { name = \"hexlib\", version = \"1.0.0\", build_tools = [\"gleam\"], requirements = [], otp_app = \"hexlib\", source = \"hex\", outer_checksum = \"" & hexSum & "\" },\n" &
      "  { name = \"lib_gl\", version = \"0.1.0\", build_tools = [\"gleam\"], requirements = [], source = \"local\", path = \"../deep/lib\" },\n" &
      "]\n")
  elif withManifest:
    writeFile(dir / "app" / "manifest.toml",
      "# Do not manually edit this file, it is managed by Gleam.\n\npackages = [\n" &
      "  { name = \"lib_gl\", version = \"0.1.0\", build_tools = [\"gleam\"], requirements = [], source = \"local\", path = \"../deep/lib\" },\n" &
      "]\n\n[requirements]\nlib_gl = { path = \"../deep/lib\" }\n")
  loadWorkspace(dir / "niuv.workspace.toml").get

proc sh(cmd: string) =
  let (o, code) = execCmdEx(cmd)
  doAssert code == 0, cmd & ": " & o

proc toOctal(n, width: int): string =
  var v = n
  while v > 0:
    result = $(v mod 8) & result
    v = v div 8
  result = repeat('0', max(0, width - result.len)) & result

proc ustar(name, content: string, kind = '0', link = ""): string =
  ## One tar member, written by hand: tar programs refuse to make a name with `..` in it.
  var h = newString(512)
  proc put(at: int, v: string) =
    for i, c in v: h[at + i] = c
  put(0, name); put(100, "0000644\0"); put(108, "0000000\0"); put(116, "0000000\0")
  put(124, toOctal(content.len, 11) & "\0"); put(136, "00000000000\0")
  put(148, "        "); h[156] = kind; put(157, link); put(257, "ustar\0" & "00")
  var sum = 0
  for c in h: sum += ord(c)
  put(148, toOctal(sum, 6) & "\0 ")
  result = h & content & newString((512 - content.len mod 512) mod 512)

proc makeHexPackage(d, name, version: string, extra: openArray[(string, string)] = [], contents = ""): string =
  ## A Hex archive in `<d>/hexcache/<OUTER CHECKSUM>.tar`; returns the checksum.
  ## `contents` replaces the packed sources (an already compressed contents.tar.gz).
  let src = d / "hexsrc" / name
  let outer = d / "hexouter" / name
  removeDir(src); removeDir(outer)
  writeTree(src, {"gleam.toml": "name = \"" & name & "\"\nversion = \"" & version & "\"\nlicences = [\"MIT\"]\n",
                  "src" / (name & ".gleam"): "pub fn one() -> Int {\n  1\n}\n"})
  for (rel, content) in extra: writeTree(src, {rel: content})
  createDir(outer)
  if contents.len > 0: writeFile(outer / "contents.tar.gz", contents)
  else: sh("tar czf " & quoteShell(outer / "contents.tar.gz") & " -C " & quoteShell(src) & " gleam.toml src")
  writeTree(outer, {"VERSION": "3", "CHECKSUM": "x", "metadata.config": "{<<\"name\">>,<<\"" & name & "\">>}.\n"})
  createDir(d / "hexcache")
  let tmp = d / "hexcache" / (name & ".tar")
  sh("tar cf " & quoteShell(tmp) & " -C " & quoteShell(outer) & " VERSION CHECKSUM metadata.config contents.tar.gz")
  let sum = sha256File(tmp).get.toUpperAscii
  moveFile(tmp, d / "hexcache" / (sum & ".tar"))
  sum

proc build(d: string, ws: Workspace, stageRoot: string): NResult[GleamResult] =
  let c = resolveClosure(ws, "app").get
  buildGleam(realGleam(), realErlang(), c, d / "out", stageRoot, d / "hexcache")

proc beamHashes(r: GleamResult): seq[string] =
  r.artifacts.mapIt(it.name & " " & it.sha256).sorted

suite "NIV-16 gleam plumbing":
  test "Given a path dependency at another depth, When built, Then the shipped beams of both packages come back":
    let d = freshDir("gl-plumb")
    let r = build(d, makeWorkspace(d), d / "stage")
    check r.isOk
    let names = r.get.artifacts.mapIt(it.name)
    check "app" in names
    check "lib_gl" in names
    check "app_ffi" in names
    for a in r.get.artifacts:
      check a.kind == akBeam
      check fileExists(a.path)
      check a.path.endsWith(".beam")
      check a.size == getFileSize(a.path)
      check a.sha256 == sha256File(a.path).get

  test "Given tests in the package, When built, Then their modules are not shipped":
    let d = freshDir("gl-notest")
    let r = build(d, makeWorkspace(d), d / "stage")
    check r.isOk
    check "app_test" notin r.get.artifacts.mapIt(it.name)

  test "Given a build, When the stage is read, Then each package is compiled into lib/<name>/ebin from where its sources are":
    let d = freshDir("gl-stagelib")
    let r = build(d, makeWorkspace(d), d / "stage").get
    check fileExists(r.stageDir / "lib" / "app" / "ebin" / "app.beam")
    check fileExists(r.stageDir / "lib" / "lib_gl" / "ebin" / "lib_gl.beam")
    check not dirExists(r.stageDir / "app")   # nothing is copied: the packages are compiled in place

  test "Given a package that imports a module of a package it does not depend on, When built, Then it is refused":
    let d = freshDir("gl-sees-deps")
    let ws = makeWorkspace(d, appGleamDeps = "lib_gl = { path = \"../deep/lib\" }\n")
    writeFile(d / "deep" / "lib" / "gleam.toml", readFile(d / "deep" / "lib" / "gleam.toml") & "\n[dependencies]\n")
    createDir(d / "other")
    writeTree(d, {"other/niuv.toml": pkgToml("other", "\n[gleam]\n"),
                  "other/gleam.toml": "name = \"other\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\n",
                  "other/src/other.gleam": "pub fn x() -> Int {\n  1\n}\n"})
    writeFile(d / "niuv.workspace.toml", "[workspace]\nmembers = [\"app\", \"deep/lib\", \"other\"]\n")
    writeFile(d / "app" / "niuv.toml", pkgToml("app", "\n[gleam]\n[dependencies]\nworkspace = [\"lib\", \"other\"]\n"))
    writeFile(d / "deep" / "lib" / "src" / "lib_gl.gleam", "import other\n\npub fn answer() -> Int {\n  other.x()\n}\n")
    let r = build(d, loadWorkspace(d / "niuv.workspace.toml").get, d / "stage")
    check r.isErr
    check "other" in r.error.msg

  test "Given a build, When the sources are looked at afterwards, Then they are untouched":
    let d = freshDir("gl-untouched")
    let ws = makeWorkspace(d)
    let before = readFile(d / "app" / "gleam.toml")
    check build(d, ws, d / "stage").isOk
    check readFile(d / "app" / "gleam.toml") == before
    check not dirExists(d / "app" / "build")
    check not dirExists(d / "deep" / "lib" / "build")

  test "Given a manifest.toml with local paths and no Hex entry, When built, Then it is not needed to know them and the build passes":
    let d = freshDir("gl-manifest")
    let r = build(d, makeWorkspace(d, withManifest = true), d / "stage")
    check r.isOk

  test "Given a Hex dependency pinned by the root's manifest.toml, When built from the Hex copy, Then its beams ship and it is listed with its license":
    let d = freshDir("gl-hex")
    let sum = makeHexPackage(d, "hexlib", "1.0.0")
    let r = build(d, makeWorkspace(d, hexSum = sum), d / "stage")
    check r.isOk
    check ("beam" / "hexlib" / "hexlib.beam") in r.get.artifacts.mapIt(it.path.relativePath(d / "out"))
    check r.get.hex.len == 1
    check r.get.hex[0].name == "hexlib"
    check r.get.hex[0].version == "1.0.0"
    check r.get.hex[0].licenses == @["MIT"]

  test "Given a Hex archive that is not the one the lock names, When built, Then it is refused naming both checksums":
    let d = freshDir("gl-hex-sum")
    let sum = makeHexPackage(d, "hexlib", "1.0.0")
    let wrong = "A".repeat(64)
    moveFile(d / "hexcache" / (sum & ".tar"), d / "hexcache" / (wrong & ".tar"))
    let r = build(d, makeWorkspace(d, hexSum = wrong), d / "stage")
    check r.isErr
    check sum in r.error.msg and wrong in r.error.msg

  test "Given a Hex package that is not in the Hex copy, When built, Then it is refused naming it and its archive":
    let d = freshDir("gl-hex-missing")
    let sum = makeHexPackage(d, "hexlib", "1.0.0")
    removeFile(d / "hexcache" / (sum & ".tar"))
    let r = build(d, makeWorkspace(d, hexSum = sum), d / "stage")
    check r.isErr
    check "hexlib" in r.error.msg and sum in r.error.msg

  test "Given a Hex dependency that the root's manifest.toml does not pin, When built, Then it is refused naming it":
    let d = freshDir("gl-hex-unpinned")
    discard makeHexPackage(d, "hexlib", "1.0.0")
    let ws = makeWorkspace(d, hexSum = "B".repeat(64))
    writeFile(d / "app" / "manifest.toml", "packages = []\n")
    let r = build(d, ws, d / "stage")
    check r.isErr
    check "hexlib" in r.error.msg and "manifest.toml" in r.error.msg

  test "Given a Hex archive whose contents name a path outside themselves, When built, Then it is refused and nothing is written there":
    let d = freshDir("gl-hex-escape")
    let tarMember = ustar("../escaped.txt", "x") & newString(1024)
    writeFile(d / "evil.tar", tarMember)
    sh("gzip -c " & quoteShell(d / "evil.tar") & " > " & quoteShell(d / "evil.tar.gz"))
    let sum = makeHexPackage(d, "hexlib", "1.0.0", contents = readFile(d / "evil.tar.gz"))
    let r = build(d, makeWorkspace(d, hexSum = sum), d / "stage")
    check r.isErr
    check "outside" in r.error.msg
    check not fileExists(d / "stage" / "escaped.txt")

  test "Given a Hex archive that holds a symbolic link, When built, Then it is refused":
    let d = freshDir("gl-hex-link")
    let src = d / "linksrc"
    writeTree(src, {"gleam.toml": "name = \"hexlib\"\nversion = \"1.0.0\"\n", "src/hexlib.gleam": "pub fn one() -> Int {\n  1\n}\n"})
    createSymlink("/etc/hosts", src / "src" / "link.txt")
    sh("tar czf " & quoteShell(d / "links.tar.gz") & " -C " & quoteShell(src) & " gleam.toml src")
    let sum = makeHexPackage(d, "hexlib", "1.0.0", contents = readFile(d / "links.tar.gz"))
    let r = build(d, makeWorkspace(d, hexSum = sum), d / "stage")
    check r.isErr
    check "symbolic link" in r.error.msg

  test "Given a path dependency that the closure does not hold, When built, Then it is refused naming it":
    let d = freshDir("gl-undeclared")
    let ws = makeWorkspace(d, niuvDeps = "")
    let r = build(d, ws, d / "stage")
    check r.isErr
    check r.error.kind == ekBuild
    check "lib_gl" in r.error.msg
    check "niuv.toml" in r.error.msg

  test "Given an absolute path to the workspace package of that name, When built, Then it is accepted":
    let d = freshDir("gl-abspath")
    let ws = makeWorkspace(d, appGleamDeps = "lib_gl = { path = \"" & (d / "deep" / "lib") & "\" }\n")
    let r = build(d, ws, d / "stage")
    check r.isOk
    check "lib_gl" in r.get.artifacts.mapIt(it.name)

  test "Given an absolute path that points elsewhere, When built, Then it is refused naming that path":
    let d = freshDir("gl-abselse")
    let ws = makeWorkspace(d, appGleamDeps = "lib_gl = { path = \"" & (d / "somewhere") & "\" }\n")
    let r = build(d, ws, d / "stage")
    check r.isErr
    check (" at " & (d / "somewhere") & " ") in r.error.msg

  test "Given a path that points elsewhere than the workspace package of that name, When built, Then it is refused":
    let d = freshDir("gl-elsewhere")
    let ws = makeWorkspace(d, appGleamDeps = "lib_gl = { path = \"../somewhere/else\" }\n")
    let r = build(d, ws, d / "stage")
    check r.isErr
    check r.error.kind == ekBuild
    check "lib_gl" in r.error.msg
    check "somewhere" in r.error.msg

  test "Given a Gleam compile error, When built, Then the compiler output comes back":
    let d = freshDir("gl-fail")
    let ws = makeWorkspace(d)
    writeFile(d / "deep" / "lib" / "src" / "lib_gl.gleam", "pub fn answer() -> Int {\n  not gleam\n}\n")
    let r = build(d, ws, d / "stage")
    check r.isErr
    check r.error.kind == ekBuild
    check "lib_gl" in r.error.msg

  test "Given a package without a gleam table, When built, Then it is refused":
    let d = freshDir("gl-nogleam")
    let ws = makeWorkspace(d)
    var c = resolveClosure(ws, "app").get
    for p in c.packages.mitems:
      if p.name == "app": p.gleam.present = false
    let r = buildGleam(realGleam(), realErlang(), c, d / "out", d / "stage")
    check r.isErr
    check r.error.kind == ekUsage

suite "NIV-17 fixed bytes":
  test "Given one input built in two places with two stage roots, When the beams are hashed, Then all are equal":
    let a = freshDir("gl-fixed-a")
    let b = freshDir("gl-fixed-b" / "deeper" / "still")
    let ra = build(a, makeWorkspace(a), a / "stage-one")
    let rb = build(b, makeWorkspace(b), b / "elsewhere" / "stage-two")
    check ra.isOk and rb.isOk
    check ra.get.artifacts.len >= 3
    check beamHashes(ra.get) == beamHashes(rb.get)
    check ra.get.stageDir != rb.get.stageDir

  test "Given a Hex dependency, When built in two places, Then all beams, the Hex ones included, are equal":
    let a = freshDir("gl-hexfixed-a")
    let b = freshDir("gl-hexfixed-b" / "deeper")
    let sa = makeHexPackage(a, "hexlib", "1.0.0")
    let sb = makeHexPackage(b, "hexlib", "1.0.0")
    let ra = build(a, makeWorkspace(a, hexSum = sa), a / "s")
    let rb = build(b, makeWorkspace(b, hexSum = sb), b / "elsewhere" / "s")
    check ra.isOk and rb.isOk
    check "hexlib" in ra.get.artifacts.mapIt(it.name)
    check beamHashes(ra.get) == beamHashes(rb.get)

  test "Given the Erlang FFI beam, When built in two places, Then its SHA-256 is equal":
    let a = freshDir("gl-ffi-a")
    let b = freshDir("gl-ffi-b" / "x")
    let fa = build(a, makeWorkspace(a), a / "s").get.artifacts.filterIt(it.name == "app_ffi")
    let fb = build(b, makeWorkspace(b), b / "s").get.artifacts.filterIt(it.name == "app_ffi")
    check fa.len == 1 and fb.len == 1
    check fa[0].sha256 == fb[0].sha256

  test "Given the same content in two places, When staged, Then the stage directory has the same name":
    let a = freshDir("gl-key-a")
    let b = freshDir("gl-key-b" / "y")
    let ra = build(a, makeWorkspace(a), a / "s").get
    let rb = build(b, makeWorkspace(b), b / "s").get
    check extractFilename(ra.stageDir) == extractFilename(rb.stageDir)
    check extractFilename(ra.stageDir).len == 64

  test "Given a source changes, When staged, Then the stage directory has another name":
    let d = freshDir("gl-key-change")
    let ws = makeWorkspace(d)
    let before = extractFilename(build(d, ws, d / "s").get.stageDir)
    writeFile(d / "deep" / "lib" / "src" / "lib_gl.gleam", "pub fn answer() -> Int {\n  43\n}\n")
    check extractFilename(build(d, ws, d / "s").get.stageDir) != before

  test "Given leftovers in the stage directory, When built again, Then they are gone":
    let d = freshDir("gl-stale")
    let ws = makeWorkspace(d)
    let first = build(d, ws, d / "s").get
    writeFile(first.stageDir / "leftover.txt", "stale")
    writeFile(first.stageDir / "lib" / "app" / "ebin" / "ghost.beam", "stale")
    let again = build(d, ws, d / "s")
    check again.isOk
    check not fileExists(first.stageDir / "leftover.txt")
    check not fileExists(first.stageDir / "lib" / "app" / "ebin" / "ghost.beam")

  test "Given the user's ERL_COMPILER_OPTIONS, When built, Then the build is still deterministic":
    let a = freshDir("gl-env-a")
    let b = freshDir("gl-env-b" / "z")
    let ra = build(a, makeWorkspace(a), a / "s").get
    putEnv("ERL_COMPILER_OPTIONS", "debug_info")
    let rb = build(b, makeWorkspace(b), b / "s")
    delEnv("ERL_COMPILER_OPTIONS")
    check rb.isOk
    check beamHashes(ra) == beamHashes(rb.get)

suite "NIV-23 beam placement":
  test "Given a Gleam build, When its beams are placed, Then each sits at beam/<application>/<module>.beam under the output":
    let d = freshDir("gl-place")
    let r = build(d, makeWorkspace(d), d / "stage")
    check r.isOk
    var placed: seq[string]
    for a in r.get.artifacts:
      check a.path.isRelativeTo(d / "out" / "beam")
      placed.add a.path.relativePath(d / "out")
    check (("beam" / "app" / "app.beam") in placed)
    check (("beam" / "app" / "app_ffi.beam") in placed)
    check (("beam" / "lib_gl" / "lib_gl.beam") in placed)
