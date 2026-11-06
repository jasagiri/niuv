## E tests for WASM components in the project build: NIV-49 .. NIV-57
## (ADR-NIUV-0007). The declaration's own rules (NIV-49, NIV-50) are in
## test_decl.nim and test_workspace.nim. These build with the real nim, clang,
## wasi-sysroot and wasm-tools, run the component with wasmtime, and fail
## (not skip) when one is missing.

import std/[algorithm, options, os, osproc, sequtils, strutils, unittest]
import ../../src/niuv/[artifact, cli, errors, hashing, lock, manifest, workspace]
import support

const testFile* = "tests/unit/test_wasmbuild.nim"

proc pkgToml(name: string, extra = ""): string =
  "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n" & extra

const
  probeWit = "package niuv:probe;\n\nworld probe {\n    export run: func() -> u32;\n}\n"
  trapPanic = "proc rawoutput(s: string) = discard\nproc panic(s: string) {.noreturn.} =\n" &
              "  {.emit: \"__builtin_trap();\".}\n  while true: discard\n"
  guestUsingLib = "import answer\nproc run(): uint32 {.exportc: \"run\", cdecl.} = uint32(answer())\n"
  guestPlain = "proc run(): uint32 {.exportc: \"run\", cdecl.} = 7\n"

proc component(name: string, extra = "", dir = name): string =
  "\n[[wasm.component]]\nname = \"" & name & "\"\nentry = \"" & dir & "/main.nim\"\nwit = \"wit\"\n" &
  "world = \"niuv:probe/probe\"\nexport = [\"run\"]\nno_simd = true\n" & extra

proc makeWorkspace(d: string, appExtra: string, libLicense = "Apache-2.0",
                   guests: openArray[(string, string)] = [("probe", guestUsingLib)]): string =
  ## `app` declares wasm components; `lib` is its workspace dependency and
  ## holds `answer()`, which the guests may import (NIV-56).
  writeTree(d, {
    "app/niuv.toml": pkgToml("app", appExtra & "[dependencies]\nworkspace = [\"lib\"]\n"),
    "app/wit/probe.wit": probeWit,
    "lib/niuv.toml": pkgToml("lib", "\n[nim]\n").replace("Apache-2.0", libLicense),
    "lib/src/answer.nim": "proc answer*(): int = 42\n",
    "niuv.workspace.toml": "[workspace]\nmembers = [\"app\", \"lib\"]\n[tools.nim]\nversion = \"" &
      realNim().version & "\"\n"})
  for (name, src) in guests:
    writeTree(d, {"app/" & name & "/main.nim": src, "app/" & name & "/panicoverride.nim": trapPanic})
  d / "niuv.workspace.toml"

proc buildApp(d, w: string, extra: seq[string] = @[]): CliResult =
  runCli(@["build", "app", "--workspace", w, "--out", d / "out", "--stage", d / "stage"] & extra)

proc locked(w: string) =
  check runCli(@["lock", "--workspace", w]).code == 0

proc invoke(component: string): string =
  let (o, code) = execCmdEx("wasmtime run --invoke 'run()' " & quoteShell(component))
  check code == 0
  o.strip()

proc files(dir: string): seq[string] =
  for p in walkDirRec(dir, relative = true): result.add p
  result.sort()

suite "NIV-51 the build puts each component into the output directory and the manifest":
  test "Given a declared component, When built, Then <out>/wasm/<name>.component.wasm runs and the manifest lists it with its SHA-256":
    let d = freshDir("wb-build")
    let w = makeWorkspace(d, component("probe"))
    locked(w)
    let r = buildApp(d, w)
    check r.code == 0
    let file = d / "out" / "wasm" / "probe.component.wasm"
    check fileExists(file)
    check invoke(file) == "42"
    let m = decodeManifest(readFile(d / "out" / "niuv.manifest.cbor")).get
    check m.entries.len == 1
    check m.entries[0].kind == akWasm and m.entries[0].name == "probe"
    check m.entries[0].sha256 == sha256File(file).get
    check m.entries[0].size == getFileSize(file)
    check ("probe wasm " & m.entries[0].sha256) in r.stdout

  test "Given a built component, When the output directory is listed, Then it holds the component, the manifest and the SBOM only":
    let d = freshDir("wb-only")
    let w = makeWorkspace(d, component("probe"))
    locked(w)
    check buildApp(d, w).code == 0
    check files(d / "out") == @["niuv.manifest.cbor", "niuv.sbom.cdx.json", "wasm/probe.component.wasm"]
    check files(d / "stage").anyIt(it.endsWith("probe.core.wasm"))

  test "Given a build run twice, When the component is hashed, Then it is the same":
    let d = freshDir("wb-twice")
    let w = makeWorkspace(d, component("probe"))
    locked(w)
    check buildApp(d, w).code == 0
    let first = sha256File(d / "out" / "wasm" / "probe.component.wasm").get
    check buildApp(d, w).code == 0
    check sha256File(d / "out" / "wasm" / "probe.component.wasm").get == first

  test "Given a component that does not build, When built, Then the build fails naming the component and carries the reason":
    let d = freshDir("wb-broken")
    let w = makeWorkspace(d, component("probe"), guests = [("probe", "let x: int = \"text\"\n")])
    locked(w)
    let r = buildApp(d, w)
    check r.code != 0
    check "wasm component 'probe'" in r.stderr and "type mismatch" in r.stderr
    check not fileExists(d / "out" / "niuv.manifest.cbor")

  test "Given a component and a stack size, When built, Then the stack is the declared one":
    let d = freshDir("wb-stack")
    let w = makeWorkspace(d, component("probe", "stack_size = 131072\n"))
    locked(w)
    check buildApp(d, w).code == 0
    let (o, code) = execCmdEx("wasm-tools print " & quoteShell(d / "out" / "wasm" / "probe.component.wasm"))
    check code == 0
    # The stack comes first in the linear memory, so 128 KiB of stack is the 2 initial pages
    # (the default 8 MiB would start at 129).
    check "(memory (;0;) 2 " in o

suite "NIV-52 the WASM tools are looked for before any compiler runs":
  test "Given no clang at --llvm, When built, Then it is refused naming clang and nothing is built":
    let d = freshDir("wb-noclang")
    let w = makeWorkspace(d, component("probe"))
    locked(w)
    let empty = d / "nollvm"
    createDir(empty)
    let r = buildApp(d, w, @["--llvm", empty])
    check r.code != 0
    check (empty / "clang") in r.stderr
    check not dirExists(d / "out" / "wasm") or files(d / "out" / "wasm").len == 0

  test "Given a directory that is not a wasi-sysroot, When built, Then it is refused naming the sysroot":
    let d = freshDir("wb-nosysroot")
    let w = makeWorkspace(d, component("probe"))
    locked(w)
    let r = buildApp(d, w, @["--sysroot", d])
    check r.code != 0
    check "wasi-sysroot" in r.stderr

  test "Given no wasm-tools on PATH, When built, Then it is refused naming wasm-tools":
    let d = freshDir("wb-nowasmtools")
    let w = makeWorkspace(d, component("probe"))
    locked(w)
    let bin = d / "pathbin"
    createDir(bin)
    createSymlink(realNim().exe, bin / "nim")
    let old = getEnv("PATH")
    putEnv("PATH", bin)
    let r = buildApp(d, w)
    putEnv("PATH", old)
    check r.code != 0
    check "wasm-tools" in r.stderr

  test "Given a package with no component, When built, Then no WASM tool is needed":
    let d = freshDir("wb-nocomp")
    writeTree(d, {"app/niuv.toml": pkgToml("app", "\n[nim]\n[[nim.bin]]\nname = \"hello\"\nmain = \"hello.nim\"\n"),
                  "app/hello.nim": "echo 1\n", "app/src/x.nim": "discard",
                  "niuv.workspace.toml": "[workspace]\nmembers = [\"app\"]\n[tools.nim]\nversion = \"" &
                    realNim().version & "\"\n"})
    let w = d / "niuv.workspace.toml"
    locked(w)
    let empty = d / "nollvm"
    createDir(empty)
    check buildApp(d, w, @["--llvm", empty, "--sysroot", d]).code == 0

suite "NIV-53 --bin selects components too":
  test "Given two components, When built with --bin of one, Then only that one is built and listed":
    let d = freshDir("wb-only-one")
    let w = makeWorkspace(d, component("one") & component("two"),
                          guests = [("one", guestPlain), ("two", guestUsingLib)])
    locked(w)
    check buildApp(d, w, @["--bin", "two"]).code == 0
    check files(d / "out" / "wasm") == @["two.component.wasm"]
    check invoke(d / "out" / "wasm" / "two.component.wasm") == "42"
    let m = decodeManifest(readFile(d / "out" / "niuv.manifest.cbor")).get
    check m.entries.mapIt(it.name) == @["two"]

  test "Given two components, When built without --bin, Then both are built":
    let d = freshDir("wb-both")
    let w = makeWorkspace(d, component("one") & component("two"),
                          guests = [("one", guestPlain), ("two", guestUsingLib)])
    locked(w)
    check buildApp(d, w).code == 0
    check files(d / "out" / "wasm") == @["one.component.wasm", "two.component.wasm"]
    check invoke(d / "out" / "wasm" / "one.component.wasm") == "7"

  test "Given a --bin that names neither a bin nor a component, When built, Then it is refused as a usage error":
    let d = freshDir("wb-unknown")
    let w = makeWorkspace(d, component("probe"))
    locked(w)
    let r = buildApp(d, w, @["--bin", "ghost"])
    check r.code != 0
    check "ghost" in r.stderr

suite "NIV-54 the license gate covers a sealed component":
  test "Given a sealed component and a GPL-3.0 package in the closure, When built, Then it is refused before any compile":
    let d = freshDir("wb-gate")
    let w = makeWorkspace(d, component("probe", "sealed = true\n"), libLicense = "GPL-3.0-only")
    locked(w)
    let r = buildApp(d, w)
    check r.code != 0
    check "lib" in r.stderr and "GPL-3.0-only" in r.stderr
    check not dirExists(d / "stage")

  test "Given an unsealed component and a GPL-3.0 package in the closure, When built, Then it builds":
    let d = freshDir("wb-gate-open")
    let w = makeWorkspace(d, component("probe"), libLicense = "GPL-3.0-only")
    locked(w)
    check buildApp(d, w).code == 0

suite "NIV-56 the closure reaches the component":
  test "Given a component that imports a module of a workspace dependency and one of a declared path, When built, Then both are found":
    let d = freshDir("wb-paths")
    let w = makeWorkspace(d, component("probe", "paths = [\"../sdk/src\"]\n"),
                          guests = [("probe", "import answer, extra\nproc run(): uint32 {.exportc: \"run\", cdecl.} = uint32(answer() + extra())\n")])
    writeTree(d, {"sdk/src/extra.nim": "proc extra*(): int = 100\n"})
    locked(w)
    check buildApp(d, w).code == 0
    check invoke(d / "out" / "wasm" / "probe.component.wasm") == "142"

suite "NIV-57 the lock covers what the component reads":
  test "Given a locked component, When its WIT, its program or a declared path changes, Then the package hash changes":
    let d = freshDir("wb-lock")
    let w = makeWorkspace(d, component("probe", "paths = [\"../sdk/src\"]\n"))
    writeTree(d, {"sdk/src/extra.nim": "proc extra*(): int = 100\n"})
    proc hash(): string =
      let ws = loadWorkspace(w).get
      packageHash(ws.find("app").get, ws).get
    let before = hash()
    for (rel, text) in [("app/wit/probe.wit", probeWit & "// edited\n"), ("app/probe/main.nim", guestPlain),
                        ("app/probe/panicoverride.nim", trapPanic & "# edited\n"),
                        ("sdk/src/extra.nim", "proc extra*(): int = 101\n")]:
      let old = readFile(d / rel)
      writeFile(d / rel, text)
      check hash() != before
      writeFile(d / rel, old)
      check hash() == before

  test "Given a build after the component's source changed, When built, Then it is refused as stale (NIV-12)":
    let d = freshDir("wb-stale")
    let w = makeWorkspace(d, component("probe"))
    locked(w)
    writeFile(d / "app" / "probe" / "main.nim", guestPlain)
    let r = buildApp(d, w)
    check r.code != 0
    check "app" in r.stderr
