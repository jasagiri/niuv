## E tests for the Nim build: NIV-14 (plumbing) and NIV-15 (build).

import std/[options, os, osproc, strutils, unittest]
import ../../src/niuv/[artifact, decl, errors, nimbuild, resolve, workspace]
import support

const testFile* = "tests/unit/test_nimbuild.nim"

proc pkgToml(name: string, extra = ""): string =
  "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n" & extra

## `app` depends on `lib` (workspace) and `ext` (external).
proc makeWorkspace(dir: string, appDeps = "[dependencies]\nworkspace = [\"lib\"]\n" &
                   "[dependencies.external.ext]\nsource = \"github.com/a/ext\"\nversion = \"1.2.3\"\n",
                   binFlags = ""): Workspace =
  writeTree(dir, {
    "app/niuv.toml": pkgToml("app", "\n[nim]\nflags = [\"-d:fromRoot\"]\n[[nim.bin]]\nname = \"hello\"\n" &
      "main = \"child/hello.nim\"\n" & binFlags & "\n" & appDeps),
    "app/child/hello.nim": """
import greeter, extmod
when defined(fromRoot): echo "root-flag"
when defined(fromBin): echo "bin-flag"
when defined(fromCfg): echo "cfg-flag"
echo greet("niuv"), " ", extName()
""",
    "app/src/placeholder.nim": "discard",
    "app/nim.cfg": "-d:fromCfg\n",
    "lib/niuv.toml": pkgToml("lib", "\n[nim]\n"),
    "lib/src/greeter.nim": "proc greet*(n: string): string = \"hello \" & n\n",
    "ext/githubcom_aext_123/extmod.nim": "proc extName*(): string = \"ext\"\n",
    "niuv.workspace.toml": "[workspace]\nmembers = [\"app\", \"lib\"]\n[external]\nroots = [\"ext\"]\n"})
  loadWorkspace(dir / "niuv.workspace.toml").get

proc build(d: string, ws: Workspace, only: seq[string] = @[]): NResult[seq[Artifact]] =
  let c = resolveClosure(ws, "app").get
  buildNim(realNim(), c, d / "out", d / "stage", only)

suite "NIV-14 nim plumbing":
  test "Given a closure, When the arguments are made, Then every src and external is a --path":
    let d = freshDir("nim-args")
    let ws = makeWorkspace(d)
    let c = resolveClosure(ws, "app").get
    let root = ws.find("app").get
    let args = nimArgs(c, root, root.nim.bins[0], d / "cache", d / "out" / "hello")
    check "--path:" & d / "lib" / "src" in args
    check "--path:" & d / "app" / "src" in args
    check "--path:" & d / "ext" / "githubcom_aext_123" in args

  test "Given a build, When the arguments are made, Then nimble and the config files are switched off":
    let d = freshDir("nim-args-off")
    let ws = makeWorkspace(d)
    let c = resolveClosure(ws, "app").get
    let root = ws.find("app").get
    let args = nimArgs(c, root, root.nim.bins[0], d / "cache", d / "out" / "hello")
    for must in ["--noNimblePath", "--skipUserCfg:on", "--skipParentCfg:on", "--skipProjCfg:on"]:
      check must in args

  test "Given root flags and bin flags, When the arguments are made, Then root flags come first":
    let d = freshDir("nim-args-order")
    let ws = makeWorkspace(d, binFlags = "flags = [\"-d:fromBin\"]")
    let c = resolveClosure(ws, "app").get
    let root = ws.find("app").get
    let args = nimArgs(c, root, root.nim.bins[0], d / "cache", d / "out" / "hello")
    check args.find("-d:fromRoot") < args.find("-d:fromBin")
    check args.find("-d:fromBin") >= 0
    check args[0] == "c"
    check args[^1] == d / "app" / "child" / "hello.nim"

  test "Given a dependency declared, When the program is built and run, Then it uses the workspace and external sources":
    let d = freshDir("nim-run")
    let ws = makeWorkspace(d)
    let built = build(d, ws)
    check built.isOk
    let (o, code) = execCmdEx(built.get[0].path)
    check code == 0
    check "hello niuv ext" in o

  test "Given an import of a package that is not declared, When built, Then the compiler fails":
    let d = freshDir("nim-undeclared")
    let ws = makeWorkspace(d, appDeps = "")
    let built = build(d, ws)
    check built.isErr
    check built.error.kind == ekBuild
    check "greeter" in built.error.msg

  test "Given a nim.cfg beside the program, When built, Then it is not read":
    let d = freshDir("nim-nocfg")
    let ws = makeWorkspace(d)
    let built = build(d, ws)
    let (o, _) = execCmdEx(built.get[0].path)
    check "cfg-flag" notin o

  test "Given root flags, When built, Then they reach the compiler":
    let d = freshDir("nim-rootflag")
    let built = build(d, makeWorkspace(d))
    let (o, _) = execCmdEx(built.get[0].path)
    check "root-flag" in o
    check "bin-flag" notin o

  test "Given bin flags, When built, Then they reach the compiler":
    let d = freshDir("nim-binflag")
    let built = build(d, makeWorkspace(d, binFlags = "flags = [\"-d:fromBin\"]"))
    let (o, _) = execCmdEx(built.get[0].path)
    check "bin-flag" in o

suite "NIV-15 nim build":
  test "Given a bin, When built, Then it is placed by name under out with its SHA-256 and size":
    let d = freshDir("nim-place")
    let built = build(d, makeWorkspace(d))
    check built.isOk
    check built.get.len == 1
    let a = built.get[0]
    check a.name == "hello"
    check a.kind == akNimChild
    check a.path == d / "out" / "hello"
    check fileExists(a.path)
    check a.size == getFileSize(a.path)
    check a.sha256.len == 64
    check not a.sealed

  test "Given a bin, When built, Then out holds the bin alone and the compiler's cache is under the stage root":
    let d = freshDir("nim-outonly")
    check build(d, makeWorkspace(d)).isOk
    var inOut: seq[string]
    for f in walkDirRec(d / "out", relative = true): inOut.add f
    check inOut == @["hello"]
    check dirExists(d / "stage")

  test "Given a sealed bin, When built, Then the artifact is marked sealed":
    let d = freshDir("nim-sealed")
    let ws = makeWorkspace(d, binFlags = "sealed = true")
    check build(d, ws).get[0].sealed

  test "Given a bin name, When built with only that name, Then only it is built":
    let d = freshDir("nim-only")
    let ws = makeWorkspace(d)
    check build(d, ws, @["hello"]).get.len == 1

  test "Given a bin name the package lacks, When built, Then it is refused":
    let d = freshDir("nim-nobin")
    let built = build(d, makeWorkspace(d), @["nope"])
    check built.isErr
    check "nope" in built.error.msg

  test "Given a compile error, When built, Then the compiler output comes back":
    let d = freshDir("nim-fail")
    let ws = makeWorkspace(d)
    writeFile(d / "app" / "child" / "hello.nim", "this is not nim\n")
    let built = build(d, ws)
    check built.isErr
    check built.error.kind == ekBuild
    check "hello.nim" in built.error.msg

  test "Given a read-only package root and a link command too long for one line, When built, Then it builds":
    # SPEC: NIV-15
    # The compiler then writes the link command to a file in its working directory (a response file on
    # Linux, a shell script on macOS); in the builder guest the sources are mounted read-only.
    let d = freshDir("nim-longlink")
    var long = ""
    while long.len < 300_000: long.add " -L/nonexistent/niuv-long-link-command"
    let ws = makeWorkspace(d)
    let app = d / "app"
    writeFile(app / "child" / "hello.nim", readFile(app / "child" / "hello.nim") & "{.passL: \"" & long.strip & "\".}\n")
    var dirs = @[app]
    for p in walkDirRec(app, yieldFilter = {pcDir}): dirs.add p
    for p in dirs: setFilePermissions(p, {fpUserRead, fpUserExec, fpGroupRead, fpGroupExec})
    let built = build(d, ws)
    for p in dirs: setFilePermissions(p, {fpUserRead, fpUserWrite, fpUserExec, fpGroupRead, fpGroupExec})
    check built.isOk
    if built.isErr: echo built.error.msg

  test "Given a relative out directory, When built, Then the bin is placed there, counted from where niuv runs":
    # SPEC: NIV-15
    let d = freshDir("nim-relout")
    let ws = makeWorkspace(d)
    let c = resolveClosure(ws, "app").get
    let before = getCurrentDir()
    setCurrentDir(d)
    let built = buildNim(realNim(), c, "relout", d / "stage")
    setCurrentDir(before)
    check built.isOk
    check fileExists(d / "relout" / "hello")

  test "Given the same input built twice, When compared, Then the executables are byte-equal":
    let d = freshDir("nim-twice")
    let ws = makeWorkspace(d)
    let a = build(d, ws).get[0].sha256
    removeDir(d / "out")
    check build(d, ws).get[0].sha256 == a
