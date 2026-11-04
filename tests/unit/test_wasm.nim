## E tests for the wasm32-wasip1 build: NIV-34..NIV-39 (ADR-NIUV-0003).
## They build small programs with the real nim, clang, wasi-sysroot and
## wasmtime, and fail (not skip) when one of them is missing.

import std/[os, osproc, sequtils, strutils, unittest]
import ../../src/niuv/[cli, errors, wasm]
import support

const testFile* = "tests/unit/test_wasm.nim"

proc toolchain(aot = true): WasmToolchain =
  findWasmToolchain(DefaultLlvmBin, DefaultWasiSysroot, aot).get

proc request(program, dir: string, name = "prog", aot = false, nimFlags: seq[string] = @[]): WasmRequest =
  WasmRequest(program: program, outDir: dir / "out", stageDir: dir / "stage", name: name,
              nimFlags: nimFlags, simd: true, aot: aot)

proc run(module: string, args: seq[string] = @[], precompiled = false): (string, int) =
  var cmd = "wasmtime run "
  if precompiled: cmd.add "--allow-precompiled "
  cmd.add quoteShell(module)
  for a in args: cmd.add " " & quoteShell(a)
  execCmdEx(cmd)

const
  argsProgram = """
import std/os
echo "count=", paramCount()
for i in 1 .. paramCount(): echo "arg=", paramStr(i)
echo "intsize=", sizeof(int)
programResult = 3
"""
  tripleQuote = "\"\"\""
  multiplyProgram = "{.emit: " & tripleQuote & """
#include <stdio.h>
static void showProduct(unsigned long long aHi, unsigned long long aLo, unsigned long long bHi, unsigned long long bLo) {
  volatile unsigned __int128 a = ((unsigned __int128)aHi << 64) | aLo;
  volatile unsigned __int128 b = ((unsigned __int128)bHi << 64) | bLo;
  unsigned __int128 p = a * b;
  printf("%016llx%016llx\n", (unsigned long long)(p >> 64), (unsigned long long)p);
}
""" & tripleQuote & """.}
proc showProduct(aHi, aLo, bHi, bLo: uint64) {.importc, nodecl.}
showProduct(0, 0xFFFFFFFFFFFFFFFF'u64, 0, 0xFFFFFFFFFFFFFFFF'u64)
showProduct(0x0123456789ABCDEF'u64, 0xFEDCBA9876543210'u64, 0, 0x1000000000000001'u64)
showProduct(0xFFFFFFFFFFFFFFFF'u64, 0xFFFFFFFFFFFFFFFF'u64, 0xFFFFFFFFFFFFFFFF'u64, 0xFFFFFFFFFFFFFFFF'u64)
"""

suite "NIV-34 the recipe":
  test "Given a request, When the nim arguments are made, Then the recipe's flags come first and the caller's after":
    let args = nimArgs(WasmRequest(program: "p.nim", nimFlags: @["-d:danger"]), "/c")
    for f in ["--mm:orc", "-d:useMalloc", "-d:noSignalHandler", "-d:nimNoGetRandom", "--exceptions:goto",
              "--threads:off", "--os:linux", "--cpu:wasm32", "--noMain:on", "--compileOnly"]:
      check f in args
    check args.find("-d:danger") > args.find("--noMain:on")
    check args[^1] == "p.nim"
    check "--nimcache:/c" in args

  test "Given SIMD on or off, When the clang flags are made, Then the target is wasm32-wasip1 at -O2 and -msimd128 follows SIMD":
    check targetCFlags("/s", true) == @["--target=wasm32-wasip1", "--sysroot=/s", "-O2", "-msimd128"]
    check targetCFlags("/s", false) == @["--target=wasm32-wasip1", "--sysroot=/s", "-O2"]
    let link = linkArgs(WasmToolchain(sysroot: "/s"), true, @["a.o"], "rt.a", "x.wasm")
    check "-Wl,-z,stack-size=8388608" in link
    check "-Wl,--max-memory=4294967296" in link
    check link[^4 .. ^1] == @["-lc", "rt.a", "-o", "x.wasm"]

  test "NIV-48 Given a stack size, When the link arguments are made, Then every shape links that stack, and only 64 KiB..64 MiB multiples of 16 are taken":
    let tc = WasmToolchain(sysroot: "/s")
    check "-Wl,-z,stack-size=1048576" in linkArgs(tc, false, @["a.o"], "rt.a", "x.wasm", 1048576)
    check "-Wl,-z,stack-size=1048576" in componentLinkArgs(tc, false, @["a.o"], @["run"], "rt.a", "x.wasm", 1048576)
    check "-Wl,-z,stack-size=1048576" in reactorLinkArgs(tc, false, @["a.o"], @["run"], "rt.a", "x.wasm", 1048576)
    check stackSizeValid(65536) and stackSizeValid(64 * 1024 * 1024) and stackSizeValid(StackSize)
    check not stackSizeValid(65535) and not stackSizeValid(64 * 1024 * 1024 + 16) and not stackSizeValid(65536 + 8)
    check not stackSizeValid(0)

  test "Given Nim's C and a link, When their clang arguments are made, Then warnings fail the build instead of being silenced":
    let c = nimCArgs(WasmToolchain(sysroot: "/s"), true, "/lib", "a.c", "a.o")
    check "-Werror" in c
    check "-w" notin c
    check "-Wl,--fatal-warnings" in linkArgs(WasmToolchain(sysroot: "/s"), true, @["a.o"], "rt.a", "x.wasm")
    check "-Wl,--fatal-warnings" in componentLinkArgs(WasmToolchain(sysroot: "/s"), true, @["a.o"], @["run"], "rt.a", "x.wasm")

  test "Given a program whose generated C has a warning, When built, Then the build fails and shows the warning":
    let d = freshDir("wasm-cwarning")
    writeTree(d, {"main.nim": "{.emit: \"#warning \\\"a warning from the generated C\\\"\".}\necho 1\n"})
    let built = buildWasm(toolchain(), request(d / "main.nim", d))
    check built.isErr
    check built.error.kind == ekBuild
    check "a warning from the generated C" in built.error.msg

  test "Given a program whose nim.cfg adds a path, When built, Then the module on that path is found and int is 32-bit":
    let d = freshDir("wasm-cfg")
    writeTree(d, {"nim.cfg": "--path:\"lib\"\n", "lib/greeting.nim": "proc greeting*(): string = \"hello wasm\"\n",
                  "main.nim": "import greeting\necho greeting()\necho \"intsize=\", sizeof(int)\n"})
    let built = buildWasm(toolchain(), request(d / "main.nim", d))
    check built.isOk
    let (o, code) = run(built.get.wasm)
    check code == 0
    check "hello wasm" in o
    check "intsize=4" in o

suite "NIV-35 the C entry":
  test "Given arguments and a program result, When the module runs, Then the program sees the arguments and exits with its result":
    let d = freshDir("wasm-args")
    writeTree(d, {"main.nim": argsProgram})
    let built = buildWasm(toolchain(), request(d / "main.nim", d))
    check built.isOk
    let (o, code) = run(built.get.wasm, @["a b", "c"])
    check code == 3
    check "count=2" in o
    check "arg=a b" in o and "arg=c" in o

  test "Given a std/unittest program with a failing check, When the module runs, Then it exits non-zero, and zero when all pass":
    let d = freshDir("wasm-unittest")
    writeTree(d, {"fails.nim": "import std/unittest\ntest \"one\":\n  check 1 + 1 == 3\n",
                  "passes.nim": "import std/unittest\ntest \"one\":\n  check 1 + 1 == 2\n"})
    let fails = buildWasm(toolchain(), request(d / "fails.nim", d, "fails"))
    let passes = buildWasm(toolchain(), request(d / "passes.nim", d, "passes"))
    check fails.isOk and passes.isOk
    let (fo, fcode) = run(fails.get.wasm)
    check fcode != 0
    check "[FAILED]" in fo
    let (po, pcode) = run(passes.get.wasm)
    check pcode == 0
    check "[OK]" in po

suite "NIV-36 the 128-bit multiply":
  test "Given clang's resource directory in each known layout, When looked into, Then the wasm32 compiler-rt is found, and none in an empty one":
    for rel in CompilerRtCandidates:
      let d = freshDir("wasm-rt")
      writeTree(d, {rel: "!<arch>\n"})
      check compilerRtIn(d) == d / rel
    check compilerRtIn(freshDir("wasm-rt-none")) == ""

  test "Given no compiler-rt, When a program multiplies 128-bit numbers, Then niuv's shim gives the right products and says so":
    let d = freshDir("wasm-multi3")
    writeTree(d, {"main.nim": multiplyProgram})
    var tc = toolchain()
    tc.compilerRt = ""
    let built = buildWasm(tc, request(d / "main.nim", d))
    check built.isOk
    check built.get.builtins == bkMulti3Shim
    check built.get.notes.anyIt("wasi-runtimes" in it and "owner" in it)
    let (o, code) = run(built.get.wasm)
    check code == 0
    check o.splitLines()[0 .. 2] == @["fffffffffffffffe0000000000000001",
                                       "0111111111111110fedcba9876543210",
                                       "00000000000000000000000000000001"]

  test "Given a compiler-rt, When built, Then it is linked instead of the shim and no note is given":
    let d = freshDir("wasm-rt-linked")
    writeTree(d, {"main.nim": "echo 1\n"})
    var tc = toolchain()
    let rt = d / "librt.a"
    check execCmdEx(quoteShell(DefaultLlvmBin / "llvm-ar") & " rcs " & quoteShell(rt)).exitCode == 0
    tc.compilerRt = rt
    let built = buildWasm(tc, request(d / "main.nim", d))
    check built.isOk
    check built.get.builtins == bkCompilerRt
    check built.get.notes.len == 0

suite "NIV-37 outputs and the stage":
  test "Given --aot, When built, Then the out directory holds only the .wasm and the .cwasm, and the .cwasm runs precompiled":
    let d = freshDir("wasm-aot")
    writeTree(d, {"main.nim": "echo \"aot ok\"\n"})
    let built = buildWasm(toolchain(), request(d / "main.nim", d, aot = true))
    check built.isOk
    var names: seq[string]
    for _, f in walkDir(d / "out"): names.add f.extractFilename
    check names.len == 2 and "prog.wasm" in names and "prog.cwasm" in names
    let (o, code) = run(built.get.cwasm, precompiled = true)
    check code == 0
    check "aot ok" in o

  test "Given a stage used by a larger program before, When a smaller one is built there, Then nothing of the earlier one is linked":
    let d = freshDir("wasm-stage")
    writeTree(d, {"big.nim": "import std/[json, times]\necho %*{\"t\": $initDuration(seconds = 1)}\n",
                  "small.nim": "echo \"small\"\n"})
    check buildWasm(toolchain(), request(d / "big.nim", d)).isOk
    let small = buildWasm(toolchain(), request(d / "small.nim", d))
    check small.isOk
    var cFiles = 0
    for _, f in walkDir(d / "stage" / "c"):
      if f.endsWith(".c") and "json" in f: inc cFiles
    check cFiles == 0
    check run(small.get.wasm)[0].strip() == "small"

  test "Given an output directory and a name, When the stage is chosen, Then it lies under the stage root and differs per output":
    let a = stageFor("/root", "/out/a", "p")
    check a.startsWith("/root/wasm/")
    check a != stageFor("/root", "/out/b", "p")
    check a != stageFor("/root", "/out/a", "q")

suite "NIV-38 refusals":
  test "Given a missing clang or a directory that is not a wasi-sysroot, When the toolchain is looked for, Then each is refused by path":
    let d = freshDir("wasm-notools")
    let noClang = findWasmToolchain(d, DefaultWasiSysroot, false)
    check noClang.isErr
    check noClang.error.kind == ekTool
    check d / "clang" in noClang.error.msg
    let noSysroot = findWasmToolchain(DefaultLlvmBin, d, false)
    check noSysroot.isErr
    check noSysroot.error.kind == ekTool
    check d in noSysroot.error.msg

  test "Given a missing program or one that does not compile, When built, Then the first is a usage error and the second carries nim's message":
    let d = freshDir("wasm-bad")
    let missing = buildWasm(toolchain(), request(d / "absent.nim", d))
    check missing.isErr
    check missing.error.kind == ekUsage
    writeTree(d, {"bad.nim": "let x: int = \"text\"\n"})
    let bad = buildWasm(toolchain(), request(d / "bad.nim", d))
    check bad.isErr
    check bad.error.kind == ekBuild
    check "type mismatch" in bad.error.msg

suite "NIV-39 niuv wasm on the command line":
  test "Given niuv wasm with --out and --aot, When run, Then it prints both modules and notes the shim on stderr":
    let d = freshDir("wasm-cli")
    writeTree(d, {"hello.nim": "echo \"cli ok\"\n"})
    let r = runCli(@["wasm", d / "hello.nim", "--out", d / "o", "--stage", d / "s", "--aot",
                     "--nim-flag", "-d:greeting"])
    check r.code == 0
    check ("wasm " & d / "o" / "hello.wasm") in r.stdout
    check ("cwasm " & d / "o" / "hello.cwasm") in r.stdout
    if toolchain().compilerRt.len == 0:
      check "wasi-runtimes" in r.stderr
    check run(d / "o" / "hello.wasm")[0].strip() == "cli ok"

  test "Given niuv wasm without a program or with an unknown option, When run, Then it is refused with the usage":
    let none = runCli(@["wasm"])
    check none.code == 2
    check "wasm needs one Nim program" in none.stderr
    let unknown = runCli(@["wasm", "x.nim", "--simd"])
    check unknown.code == 2
    check "unknown option --simd" in unknown.stderr
    let help = runCli(@["--help"])
    check "wasm <program.nim>" in help.stdout

const
  probeWit = "package niuv:probe;\n\nworld probe {\n    export run: func() -> u32;\n}\n"
  heapGuest = """
proc run(): uint32 {.exportc: "run", cdecl.} =
  var s = newSeq[uint32]()
  for i in 1'u32 .. 6: s.add i
  for v in s: result += v
"""
  trapPanic = "proc rawoutput(s: string) = discard\nproc panic(s: string) {.noreturn.} =\n" &
              "  {.emit: \"__builtin_trap();\".}\n  while true: discard\n"

proc componentRequest(program, dir: string, exports = @["run"], world = "niuv:probe/probe"): WasmRequest =
  var r = request(program, dir)
  r.shape = wsComponent
  r.witDir = dir / "wit"
  r.world = world
  r.exports = exports
  r

proc componentToolchain(): WasmToolchain =
  findWasmToolchain(DefaultLlvmBin, DefaultWasiSysroot, false, component = true).get

proc probeDir(name: string, guest = heapGuest, panicOverride = true): string =
  let d = freshDir(name)
  writeTree(d, {"wit/probe.wit": probeWit, "prog/main.nim": guest})
  if panicOverride: writeTree(d, {"prog/panicoverride.nim": trapPanic})
  d

suite "NIV-40 the component recipe":
  test "Given a component request, When the nim arguments are made, Then Nim builds freestanding with ARC and panics on":
    var req = WasmRequest(program: "p.nim", shape: wsComponent)
    let args = nimArgs(req, "/c")
    for f in ["--os:standalone", "--mm:arc", "--panics:on", "-d:useMalloc", "--threads:off", "--noMain:on",
              "--cpu:wasm32"]:
      check f in args
    check "--os:linux" notin args
    check "--mm:orc" notin args

  test "Given exports, When the component link arguments are made, Then there is no entry, no C runtime, and each export is named":
    let link = componentLinkArgs(WasmToolchain(sysroot: "/s"), false, @["a.o"], @["run", "cabi_realloc"], "rt.a", "x.wasm")
    check "-nostdlib" in link and "-Wl,--no-entry" in link
    check "-Wl,--export=run" in link and "-Wl,--export=cabi_realloc" in link
    check "/s/lib/wasm32-wasip1/libc.a" in link
    check link[^2 .. ^1] == @["-o", "x.wasm"]

suite "NIV-41 a component of a world":
  test "Given a guest that uses the heap and a world exporting run, When built, Then the core imports nothing and the component runs":
    let d = probeDir("wasm-component")
    let built = buildWasm(componentToolchain(), componentRequest(d / "prog" / "main.nim", d))
    check built.isOk
    check built.get.wasm == d / "out" / "prog.core.wasm"
    check built.get.component == d / "out" / "prog.component.wasm"
    let (printed, pcode) = execCmdEx("wasm-tools print " & quoteShell(built.get.wasm))
    check pcode == 0
    check "(import" notin printed
    check "(export \"run\"" in printed
    let (o, code) = execCmdEx("wasmtime run --invoke 'run()' " & quoteShell(built.get.component))
    check code == 0
    check o.strip() == "21"

suite "NIV-42 component refusals":
  test "Given no panicoverride.nim next to the program, When built, Then it is refused before nim runs and says the panic should trap":
    let d = probeDir("wasm-component-nopanic", panicOverride = false)
    let r = buildWasm(componentToolchain(), componentRequest(d / "prog" / "main.nim", d))
    check r.isErr
    check r.error.kind == ekUsage
    check "panicoverride.nim" in r.error.msg and "trap" in r.error.msg

  test "Given no world or no export, When built, Then it is refused as a usage error":
    let d = probeDir("wasm-component-noworld")
    check buildWasm(componentToolchain(), componentRequest(d / "prog" / "main.nim", d, world = "")).error.kind == ekUsage
    check buildWasm(componentToolchain(), componentRequest(d / "prog" / "main.nim", d, exports = @[])).error.kind == ekUsage

  test "Given an export the program does not define, When built, Then the link failure is reported":
    let d = probeDir("wasm-component-noexport")
    let r = buildWasm(componentToolchain(), componentRequest(d / "prog" / "main.nim", d, exports = @["run", "absent"]))
    check r.isErr
    check r.error.kind == ekBuild
    check "absent" in r.error.msg

  test "Given a guest that calls into WASI, When built, Then wasm-tools refuses the core module and the reason is passed on":
    let d = probeDir("wasm-component-wasi", guest = "{.emit: \"#include <stdio.h>\".}\n" &
      "proc puts(s: cstring): cint {.importc, nodecl.}\n" &
      "proc run(): uint32 {.exportc: \"run\", cdecl.} =\n  discard puts(\"x\")\n  7\n")
    let r = buildWasm(componentToolchain(), componentRequest(d / "prog" / "main.nim", d))
    check r.isErr
    check r.error.kind == ekBuild
    check "wasm-tools component" in r.error.msg
    check "wasi" in r.error.msg

suite "NIV-43 niuv wasm --component on the command line":
  test "Given --component, --world and --export, When run, Then it prints the core and the component":
    let d = probeDir("wasm-component-cli")
    let r = runCli(@["wasm", d / "prog" / "main.nim", "--component", d / "wit", "--world", "niuv:probe/probe",
                     "--export", "run", "--out", d / "o", "--stage", d / "s"])
    check r.code == 0
    check ("core " & d / "o" / "main.core.wasm") in r.stdout
    check ("component " & d / "o" / "main.component.wasm") in r.stdout

  test "Given --component with --aot, without --world or --export, or --world alone, When run, Then each is refused with the usage":
    let d = probeDir("wasm-component-cli-bad")
    let prog = d / "prog" / "main.nim"
    let cases = [
      (@["wasm", prog, "--component", d / "wit", "--world", "niuv:probe/probe", "--export", "run", "--aot"], "--aot"),
      (@["wasm", prog, "--component", d / "wit", "--export", "run"], "--world"),
      (@["wasm", prog, "--component", d / "wit", "--world", "niuv:probe/probe"], "--export"),
      (@["wasm", prog, "--world", "niuv:probe/probe"], "--world is for --component")]
    for (args, says) in cases:
      let r = runCli(args)
      check r.code == 2
      check says in r.stderr

const
  foundationDir = currentSourcePath().parentDir.parentDir.parentDir.parentDir
  appWit = "package niuv:app;\n\nworld app {\n  export wasi:cli/run@0.3.0;\n}\n"
  readingGuest = """
import std/monotimes

proc runMain(): int32 {.exportc: "niuvRunMain", cdecl.} =
  let started = getMonoTime()
  var text = ""
  try:
    text = readFile("note.txt")
  except IOError:
    return 1
  if text != "file contents\n": return 1
  if getMonoTime() < started: return 1
  0

{.emit: """ & tripleQuote & """
__attribute__((export_name("wasi:cli/run@0.3.0#run")))
int niuvRunExport(void) { return niuvRunMain(); }
""" & tripleQuote & """.}
"""

proc reactorAdapter(): string =
  ## Builds nim-wasip1-adapter's adapters into a scratch directory and returns the reactor one.
  let outDir = freshDir("wasm-adapter")
  let (o, code) = execCmdEx("bash " & quoteShell(foundationDir / "nim-wasip1-adapter" / "scripts" / "build-adapter.sh") &
                            " " & quoteShell(outDir))
  doAssert code == 0, o
  outDir / "reactor" / "wasi_snapshot_preview1.wasm"

proc wasmRuntime(): string =
  ## nim-wasm-runtime's runner, an outside tool like wasmtime (WASM_RUNTIME overrides the place).
  result = getEnv("WASM_RUNTIME", foundationDir / "nim-wasm-runtime" / "bin" / "wasm_runtime")
  doAssert fileExists(result), result & " is missing: build it in nim-wasm-runtime (nimble build)"

proc wasiDir(name: string): string =
  let d = freshDir(name)
  writeTree(d, {"wit/app.wit": appWit, "prog/main.nim": readingGuest, "data/note.txt": "file contents\n"})
  let (o, code) = execCmdEx("cp -RL " & quoteShell(foundationDir / "nim-wasi" / "wit" / "deps") & " " &
                            quoteShell(d / "wit" / "deps"))
  doAssert code == 0, o
  d

proc wasiRequest(d, adapter: string): WasmRequest =
  var r = request(d / "prog" / "main.nim", d)
  r.shape = wsComponent
  r.witDir = d / "wit"
  r.world = "niuv:app/app"
  r.adapter = adapter
  r

suite "NIV-44 a WASI reactor with the preview1 adapter":
  test "Given a guest that exports wasi:cli/run and reads a file and the clock, When built with the adapter, Then the world is as declared and the core has no _start":
    let d = wasiDir("wasm-wasi-reactor")
    let built = buildWasm(componentToolchain(), wasiRequest(d, reactorAdapter()))
    check built.isOk
    let (wit, wcode) = execCmdEx("wasm-tools component wit " & quoteShell(built.get.component))
    check wcode == 0
    check "export wasi:cli/run@0.3.0;" in wit
    check "import wasi:filesystem/preopens@0.3.0;" in wit
    check "import wasi:clocks/monotonic-clock@0.3.0;" in wit
    let (core, ccode) = execCmdEx("wasm-tools print " & quoteShell(built.get.wasm))
    check ccode == 0
    check "(export \"_start\"" notin core
    check "(export \"_initialize\"" in core
    check "(export \"wasi:cli/run@0.3.0#run\"" in core

  test "Given that component, When run by nim-wasm-runtime with the file preopened, Then run returns ok, and err without the file":
    let d = wasiDir("wasm-wasi-run")
    let built = buildWasm(componentToolchain(), wasiRequest(d, reactorAdapter()))
    check built.isOk
    let runner = wasmRuntime()
    let withFile = execCmdEx(quoteShell(runner) & " run " & quoteShell(built.get.component) & " --dir " &
                             quoteShell(d / "data" & "::."))
    check withFile.exitCode == 0
    let empty = freshDir("wasm-wasi-run-empty")
    let without = execCmdEx(quoteShell(runner) & " run " & quoteShell(built.get.component) & " --dir " &
                            quoteShell(empty & "::."))
    check without.exitCode == 1
    let oracle = execCmdEx("wasmtime run -S p3 -W component-model-async=y --dir " & quoteShell(d / "data" & "::.") &
                           " " & quoteShell(built.get.component))
    check oracle.exitCode == 0

  test "Given a missing adapter, When built, Then it is refused and names the script that builds it":
    let d = wasiDir("wasm-wasi-noadapter")
    let r = buildWasm(componentToolchain(), wasiRequest(d, d / "absent.wasm"))
    check r.isErr
    check r.error.kind == ekUsage
    check "build-adapter.sh" in r.error.msg

  test "Given no --adapter, When the default is taken, Then it is nim-wasip1-adapter's reactor adapter next to niuv":
    check DefaultAdapter == foundationDir / "nim-wasip1-adapter" / "build" / "reactor" / "wasi_snapshot_preview1.wasm"

  test "Given --wasi on the command line, When run, Then no export is needed, and --adapter alone or --wasi without --component is refused":
    let d = wasiDir("wasm-wasi-cli")
    let adapter = reactorAdapter()
    let ok = runCli(@["wasm", d / "prog" / "main.nim", "--component", d / "wit", "--world", "niuv:app/app",
                      "--wasi", "--adapter", adapter, "--out", d / "o", "--stage", d / "s"])
    check ok.code == 0
    check ("component " & d / "o" / "main.component.wasm") in ok.stdout
    let adapterAlone = runCli(@["wasm", d / "prog" / "main.nim", "--component", d / "wit", "--world", "niuv:app/app",
                                "--export", "run", "--adapter", adapter])
    check adapterAlone.code == 2
    check "--adapter is for --wasi" in adapterAlone.stderr
    let noComponent = runCli(@["wasm", d / "prog" / "main.nim", "--wasi"])
    check noComponent.code == 2
    check "--wasi is for --component" in noComponent.stderr
