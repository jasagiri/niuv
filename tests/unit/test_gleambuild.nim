## E tests for the Gleam build: NIV-16 (plumbing) and NIV-17 (fixed bytes).

import std/[algorithm, os, sequtils, strutils, unittest]
import ../../src/niuv/[artifact, errors, gleambuild, hashing, resolve, workspace]
import support

const testFile* = "tests/unit/test_gleambuild.nim"

proc pkgToml(name: string, extra = ""): string =
  "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n" & extra

## `app` (gleam name `app`) depends on `lib` (gleam name `lib_gl`), which sits
## at a different depth: the path in app's gleam.toml is not `../lib`.
proc makeWorkspace(dir: string, appGleamDeps = "lib_gl = { path = \"../deep/lib\" }\n",
                   niuvDeps = "[dependencies]\nworkspace = [\"lib\"]\n", withManifest = false): Workspace =
  writeTree(dir, {
    "app/niuv.toml": pkgToml("app", "\n[gleam]\n" & niuvDeps),
    "app/gleam.toml": "name = \"app\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\nlicences = [\"Apache-2.0\"]\n\n" &
      "[dependencies]\n" & appGleamDeps,
    "app/src/app.gleam": "import lib_gl\n\npub fn run() -> Int {\n  lib_gl.answer()\n}\n",
    "app/src/app_ffi.erl": "-module(app_ffi).\n-export([ping/0]).\nping() -> ok.\n",
    "app/test/app_test.gleam": "pub fn main() {\n  Nil\n}\n",
    "deep/lib/niuv.toml": pkgToml("lib", "\n[gleam]\n"),
    "deep/lib/gleam.toml": "name = \"lib_gl\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\nlicences = [\"MIT\"]\n",
    "deep/lib/src/lib_gl.gleam": "pub fn answer() -> Int {\n  42\n}\n",
    "niuv.workspace.toml": "[workspace]\nmembers = [\"app\", \"deep/lib\"]\n"})
  if withManifest:
    writeFile(dir / "app" / "manifest.toml",
      "# Do not manually edit this file, it is managed by Gleam.\n\npackages = [\n" &
      "  { name = \"lib_gl\", version = \"0.1.0\", build_tools = [\"gleam\"], requirements = [], source = \"local\", path = \"../deep/lib\" },\n" &
      "]\n\n[requirements]\nlib_gl = { path = \"../deep/lib\" }\n")
  loadWorkspace(dir / "niuv.workspace.toml").get

proc build(d: string, ws: Workspace, stageRoot: string): NResult[GleamResult] =
  let c = resolveClosure(ws, "app").get
  buildGleam(realGleam(), realErlang(), c, d / "out", stageRoot)

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

  test "Given a build, When the stage is read, Then path dependencies point at staged copies":
    let d = freshDir("gl-stagetoml")
    let r = build(d, makeWorkspace(d), d / "stage").get
    let toml = readFile(r.stageDir / "app" / "gleam.toml")
    check "../lib_gl" in toml
    check "deep" notin toml
    check dirExists(r.stageDir / "lib_gl")

  test "Given a build, When the sources are looked at afterwards, Then they are untouched":
    let d = freshDir("gl-untouched")
    let ws = makeWorkspace(d)
    let before = readFile(d / "app" / "gleam.toml")
    check build(d, ws, d / "stage").isOk
    check readFile(d / "app" / "gleam.toml") == before
    check not dirExists(d / "app" / "build")
    check not dirExists(d / "deep" / "lib" / "build")

  test "Given a manifest.toml with local paths, When built, Then the staged manifest is rewritten and the build passes":
    let d = freshDir("gl-manifest")
    let r = build(d, makeWorkspace(d, withManifest = true), d / "stage")
    check r.isOk
    let m = readFile(r.get.stageDir / "app" / "manifest.toml")
    check "../lib_gl" in m
    check "deep" notin m

  test "Given a path dependency that the closure does not hold, When built, Then it is refused naming it":
    let d = freshDir("gl-undeclared")
    let ws = makeWorkspace(d, niuvDeps = "")
    let r = build(d, ws, d / "stage")
    check r.isErr
    check r.error.kind == ekBuild
    check "lib_gl" in r.error.msg
    check "niuv.toml" in r.error.msg

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
    writeFile(first.stageDir / "app" / "leftover.txt", "stale")
    writeFile(first.stageDir / "app" / "src" / "ghost.gleam", "this would not compile")
    let again = build(d, ws, d / "s")
    check again.isOk
    check not fileExists(first.stageDir / "app" / "leftover.txt")

  test "Given the user's ERL_COMPILER_OPTIONS, When built, Then the build is still deterministic":
    let a = freshDir("gl-env-a")
    let b = freshDir("gl-env-b" / "z")
    let ra = build(a, makeWorkspace(a), a / "s").get
    putEnv("ERL_COMPILER_OPTIONS", "debug_info")
    let rb = build(b, makeWorkspace(b), b / "s")
    delEnv("ERL_COMPILER_OPTIONS")
    check rb.isOk
    check beamHashes(ra) == beamHashes(rb.get)
