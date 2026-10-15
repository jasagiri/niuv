## E tests for the command line: NIV-22 (commands), and the whole path
## lock -> build that NIV-11, NIV-12, NIV-13 and NIV-15 describe from outside.

import std/[os, osproc, strutils, unittest]
import ../../src/niuv/[cli, hashing]
import support

const testFile* = "tests/unit/test_cli.nim"

proc pkgToml(name: string, extra = ""): string =
  "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n" & extra

proc makeWorkspace(dir: string, nimVersion: string): string =
  writeTree(dir, {
    "app/niuv.toml": pkgToml("app", "\n[nim]\n[[nim.bin]]\nname = \"hello\"\nmain = \"child/hello.nim\"\n" &
      "[dependencies]\nworkspace = [\"lib\"]\n"),
    "app/child/hello.nim": "import greeter\necho greet(\"cli\")\n",
    "app/src/placeholder.nim": "discard",
    "lib/niuv.toml": pkgToml("lib", "\n[nim]\n"),
    "lib/src/greeter.nim": "proc greet*(n: string): string = \"hello \" & n\n",
    "niuv.workspace.toml": "[workspace]\nmembers = [\"app\", \"lib\"]\n[tools.nim]\nversion = \"" &
      nimVersion & "\"\n"})
  dir / "niuv.workspace.toml"

proc nimVersion(): string = realNim().version

suite "NIV-22 commands":
  test "Given no command, When run, Then usage is printed and the exit code is not zero":
    let r = runCli(@[])
    check r.code != 0
    check "lock" in r.stderr and "build" in r.stderr

  test "Given venv, activate or install, When run, Then they are refused as unknown commands":
    for c in ["venv", "activate", "install", "init", "shell", "mcp"]:
      let r = runCli(@[c])
      check r.code != 0
      check "unknown command" in r.stderr
      check c in r.stderr

  test "Given --help, When run, Then usage is printed with exit code zero":
    let r = runCli(@["--help"])
    check r.code == 0
    check "lock" in r.stdout and "check" in r.stdout and "build" in r.stdout and "child" in r.stdout

  test "Given each accepted command, When run without a workspace, Then the failure is about the workspace, not the command":
    let d = freshDir("cli-nows")
    let saved = getCurrentDir()
    setCurrentDir(d)
    for c in [@["lock"], @["check", "app"], @["build", "app"]]:
      let r = runCli(c)
      check r.code != 0
      check "unknown command" notin r.stderr
      check "niuv.workspace.toml" in r.stderr
    setCurrentDir(saved)

  test "Given build without a package, When run, Then usage is refused":
    let d = freshDir("cli-nopkg")
    let r = runCli(@["build", "--workspace", makeWorkspace(d, nimVersion())])
    check r.code != 0
    check "package" in r.stderr

  test "Given an unknown option, When run, Then it is refused":
    let r = runCli(@["lock", "--frobnicate"])
    check r.code != 0
    check "--frobnicate" in r.stderr

suite "NIV-12 stale lock through the command line":
  test "Given no lock, When built, Then the exit code is not zero and the message asks for niuv lock":
    let d = freshDir("cli-nolock")
    let r = runCli(@["build", "app", "--workspace", makeWorkspace(d, nimVersion())])
    check r.code != 0
    check "niuv lock" in r.stderr

  test "Given a lock, When built, Then the program is built and listed":
    let d = freshDir("cli-ok")
    let w = makeWorkspace(d, nimVersion())
    check runCli(@["lock", "--workspace", w]).code == 0
    check fileExists(d / "niuv.lock")
    let r = runCli(@["build", "app", "--workspace", w, "--out", d / "out"])
    check r.code == 0
    check "hello" in r.stdout and "nim-child" in r.stdout
    let (o, code) = execCmdEx(d / "out" / "hello")
    check code == 0
    check "hello cli" in o

  test "Given a source edited after locking, When built, Then it is refused":
    let d = freshDir("cli-edit")
    let w = makeWorkspace(d, nimVersion())
    check runCli(@["lock", "--workspace", w]).code == 0
    writeFile(d / "lib" / "src" / "greeter.nim", "proc greet*(n: string): string = \"changed \" & n\n")
    let r = runCli(@["build", "app", "--workspace", w, "--out", d / "out"])
    check r.code != 0
    check "lib" in r.stderr and "niuv lock" in r.stderr
    check not fileExists(d / "out" / "hello")

  test "Given the lock locked again after the edit, When built, Then it is built":
    let d = freshDir("cli-relock")
    let w = makeWorkspace(d, nimVersion())
    check runCli(@["lock", "--workspace", w]).code == 0
    writeFile(d / "lib" / "src" / "greeter.nim", "proc greet*(n: string): string = \"changed \" & n\n")
    check runCli(@["lock", "--workspace", w]).code == 0
    check runCli(@["build", "app", "--workspace", w, "--out", d / "out"]).code == 0

suite "NIV-13 tool pin through the command line":
  test "Given a lock whose nim SHA-256 is not the installed one, When built, Then it is refused":
    let d = freshDir("cli-toolsha")
    let w = makeWorkspace(d, nimVersion())
    check runCli(@["lock", "--workspace", w]).code == 0
    let lk = d / "niuv.lock"
    let real = realNim().sha256
    writeFile(lk, readFile(lk).replace(real, "0".repeat(64)))
    let r = runCli(@["build", "app", "--workspace", w, "--out", d / "out"])
    check r.code != 0
    check "SHA-256" in r.stderr

  test "Given a workspace that pins a nim version that is not installed, When locked, Then it is refused":
    let d = freshDir("cli-toolver")
    let w = makeWorkspace(d, "0.0.1")
    let r = runCli(@["lock", "--workspace", w])
    check r.code != 0
    check "0.0.1" in r.stderr
    check not fileExists(d / "niuv.lock")

suite "NIV-08 check through the command line":
  test "Given a package, When checked, Then its closure is listed dependencies first":
    let d = freshDir("cli-check")
    let w = makeWorkspace(d, nimVersion())
    let r = runCli(@["check", "app", "--workspace", w])
    check r.code == 0
    check r.stdout.find("lib") < r.stdout.find("app")

  test "Given an unknown package, When checked, Then it is refused":
    let d = freshDir("cli-check-unknown")
    let r = runCli(@["check", "ghost", "--workspace", makeWorkspace(d, nimVersion())])
    check r.code != 0
    check "ghost" in r.stderr

# ---- Gleam, manifest, SBOM and the license gate through the command line --

import std/json
import ../../src/niuv/[artifact, errors, manifest]

proc makeMixed(dir: string, libLicense = "MIT", appNimSealed = false, appGleamSealed = false,
               wasm = false): string =
  ## `app` has a Nim bin and a Gleam package; both depend on `lib`.
  let gleamV = realGleam().version
  let erlV = realErlang().version
  writeTree(dir, {
    "app/niuv.toml": pkgToml("app", "\n[nim]\n[[nim.bin]]\nname = \"hello\"\nmain = \"child/hello.nim\"\n" &
      "sealed = " & $appNimSealed & "\n[gleam]\nsealed = " & $appGleamSealed & "\n" &
      (if wasm: "[wasm]\nentry = \"wasm/main.wat\"\n" else: "") &
      "[dependencies]\nworkspace = [\"lib\"]\n"),
    "app/child/hello.nim": "import greeter\necho greet(\"mixed\")\n",
    "app/src/placeholder.nim": "discard",
    "app/gleam.toml": "name = \"app\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\n\n[dependencies]\nlib_gl = { path = \"../lib\" }\n",
    "app/src/app.gleam": "import lib_gl\n\npub fn run() -> Int {\n  lib_gl.answer()\n}\n",
    "app/src/app_ffi.erl": "-module(app_ffi).\n-export([ping/0]).\nping() -> ok.\n",
    "app/wasm/main.wat": "(module)\n",
    "lib/niuv.toml": pkgToml("lib", "\n[nim]\n[gleam]\n").replace("Apache-2.0", libLicense),
    "lib/src/greeter.nim": "proc greet*(n: string): string = \"hello \" & n\n",
    "lib/gleam.toml": "name = \"lib_gl\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\n",
    "lib/src/lib_gl.gleam": "pub fn answer() -> Int {\n  42\n}\n",
    "niuv.workspace.toml": "[workspace]\nmembers = [\"app\", \"lib\"]\n[tools.nim]\nversion = \"" &
      realNim().version & "\"\n[tools.gleam]\nversion = \"" & gleamV & "\"\n[tools.erlang]\nversion = \"" &
      erlV & "\"\n"})
  dir / "niuv.workspace.toml"

proc buildMixed(d, w: string): CliResult =
  runCli(@["build", "app", "--workspace", w, "--out", d / "out", "--stage", d / "stage"])

suite "NIV-15 NIV-18 NIV-19 a mixed build writes a manifest and an SBOM":
  test "Given a Nim bin and a Gleam package, When built, Then the manifest lists both kinds":
    let d = freshDir("cli-mixed")
    let w = makeMixed(d)
    check runCli(@["lock", "--workspace", w]).code == 0
    let r = buildMixed(d, w)
    check r.code == 0
    let m = decodeManifest(readFile(d / "out" / "niuv.manifest.cbor"))
    check m.isOk
    check m.get.package == "app"
    var names: seq[string]
    for e in m.get.entries: names.add $e.kind & ":" & e.name
    for want in ["nim-child:hello", "beam:app", "beam:lib_gl", "beam:app_ffi"]:
      check want in names
    for e in m.get.entries:
      let onDisk = if e.kind == akNimChild: d / "out" / e.name else: ""
      if onDisk.len > 0: check sha256File(onDisk).get == e.sha256

  test "Given a build, When the SBOM is read, Then it lists the packages with their licenses":
    let d = freshDir("cli-sbom")
    let w = makeMixed(d, libLicense = "BSD-3-Clause")
    check runCli(@["lock", "--workspace", w]).code == 0
    check buildMixed(d, w).code == 0
    let j = parseJson(readFile(d / "out" / "niuv.sbom.cdx.json"))
    check j["bomFormat"].getStr == "CycloneDX"
    var found = false
    for c in j["components"]:
      if c["name"].getStr == "lib":
        found = true
        check c["licenses"][0]["license"]["id"].getStr == "BSD-3-Clause"
    check found

  test "Given the same build twice, When the manifests are compared, Then the bytes are equal":
    let d = freshDir("cli-manifest-twice")
    let w = makeMixed(d)
    check runCli(@["lock", "--workspace", w]).code == 0
    check buildMixed(d, w).code == 0
    let first = readFile(d / "out" / "niuv.manifest.cbor")
    removeDir(d / "out")
    check buildMixed(d, w).code == 0
    check readFile(d / "out" / "niuv.manifest.cbor") == first

suite "NIV-20 license gate through the command line":
  test "Given a sealed Nim bin and a GPL-3.0 package in the closure, When built, Then it is refused before any compile":
    let d = freshDir("cli-gate-nim")
    let w = makeMixed(d, libLicense = "GPL-3.0-only", appNimSealed = true)
    check runCli(@["lock", "--workspace", w]).code == 0
    let r = buildMixed(d, w)
    check r.code != 0
    check "lib" in r.stderr and "GPL-3.0-only" in r.stderr
    check not fileExists(d / "out" / "hello")
    check not dirExists(d / "out" / "beam")

  test "Given a sealed Gleam package and a GPL-3.0 package in the closure, When built, Then it is refused before gleam runs":
    let d = freshDir("cli-gate-gleam")
    let w = makeMixed(d, libLicense = "AGPL-3.0-or-later", appGleamSealed = true)
    check runCli(@["lock", "--workspace", w]).code == 0
    let r = buildMixed(d, w)
    check r.code != 0
    check "AGPL-3.0-or-later" in r.stderr
    check not dirExists(d / "stage")

  test "Given GPL-3.0 and nothing sealed, When built, Then it builds and the SBOM carries the license":
    let d = freshDir("cli-gate-open")
    let w = makeMixed(d, libLicense = "GPL-3.0-only")
    check runCli(@["lock", "--workspace", w]).code == 0
    check buildMixed(d, w).code == 0
    check "GPL-3.0-only" in readFile(d / "out" / "niuv.sbom.cdx.json")

  test "Given a sealed bin and only permissive licenses, When built, Then it builds":
    let d = freshDir("cli-gate-ok")
    let w = makeMixed(d, libLicense = "MIT", appNimSealed = true, appGleamSealed = true)
    check runCli(@["lock", "--workspace", w]).code == 0
    check buildMixed(d, w).code == 0

suite "NIV-04 wasm is declared, not built":
  test "Given a wasm table, When built, Then the build says so and the manifest has no wasm entry":
    let d = freshDir("cli-wasm")
    let w = makeMixed(d, wasm = true)
    check runCli(@["lock", "--workspace", w]).code == 0
    let r = buildMixed(d, w)
    check r.code == 0
    check "wasm" in r.stdout and "not built" in r.stdout
    for e in decodeManifest(readFile(d / "out" / "niuv.manifest.cbor")).get.entries:
      check e.kind != akWasm
