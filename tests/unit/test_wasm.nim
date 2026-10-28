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
