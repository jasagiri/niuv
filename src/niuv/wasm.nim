## Building one Nim program for wasm32-wasip1 (ADR-NIUV-0003, NIV-34..NIV-39;
## the component shape: ADR-NIUV-0004, NIV-40..NIV-43).
##
## This module is the one place that says how Nim becomes wasm32: a WASI
## command module, or a component of a WIT world (a freestanding core module
## without _start or WASI imports, wrapped by wasm-tools). It holds the Nim
## flags, the C entry, the clang flags, the 128-bit multiply when no
## compiler-rt is at hand, and the wasmtime AOT step. Callers (test tasks,
## benchmarks, the shell) run `niuv wasm` instead of keeping a copy.
##
## Unlike `niuv build`, the program is not declared in a niuv.toml and is not
## locked: nim reads the program's own nim.cfg / config.nims, so the paths a
## repository already declares for its tests are found (NIV-34).

import std/[json, os, osproc, strutils]
import ./[errors, exec, hashing]

const
  Wasm32Wasip1* = "wasm32-wasip1"
  DefaultLlvmBin* = "/opt/homebrew/opt/llvm/bin"
  DefaultWasiSysroot* = "/opt/homebrew/share/wasi-sysroot"
  WasmNimFlags* = [
    "-d:release", "--mm:orc", "-d:useMalloc", "-d:noSignalHandler", "-d:nimNoGetRandom",
    "--exceptions:goto", "--threads:off", "--os:linux", "--cpu:wasm32", "--noMain:on"]
    ## WASI has no signals, threads or getrandom; Nim has no WASI target, and
    ## Linux's POSIX surface is what wasi-libc provides.
  ComponentNimFlags* = [
    "-d:release", "--mm:arc", "-d:useMalloc", "--threads:off", "--os:standalone", "--cpu:wasm32",
    "--noMain:on", "--panics:on"]
    ## A component's core module imports only what its world names, so Nim
    ## builds freestanding (no WASI). ARC as in an internal desktop probe, the
    ## first component built this way; ORC here is untried.
  StackSize* = 8 * 1024 * 1024
  MaxMemory* = 4294967296'i64
  StartSource = staticRead("wasm/start.c")
  Multi3Source = staticRead("wasm/multi3.c")
  CompilerRtCandidates* = [
    "lib/wasm32-unknown-wasip1/libclang_rt.builtins.a",
    "lib/wasip1/libclang_rt.builtins-wasm32.a",
    "lib/wasi/libclang_rt.builtins-wasm32.a"]
    ## Where clang's resource directory keeps a wasm32 compiler-rt, in the
    ## layouts of LLVM's per-target runtimes and of wasi-sdk.
  MaxCompilerOutput = 8192

type
  WasmShape* = enum
    wsCommand     ## a WASI command module (_start); NIV-34
    wsComponent   ## a component of a WIT world; NIV-40

  BuiltinsKind* = enum
    bkCompilerRt    ## a wasm32 compiler-rt next to clang
    bkMulti3Shim    ## niuv's own __multi3 (multi3.c): no compiler-rt was found

  WasmToolchain* = object
    nim*, clang*, sysroot*: string
    wasmtime*: string        ## "" when no AOT step was asked for
    wasmTools*: string       ## "" unless a component is built
    compilerRt*: string      ## "" when clang has none for wasm32

  WasmRequest* = object
    program*: string         ## the Nim program (its main module)
    outDir*: string          ## gets <name>.wasm, and <name>.cwasm with `aot`
    stageDir*: string        ## the nim cache, the C objects and the C entry
    name*: string
    nimFlags*: seq[string]   ## after the recipe's flags, so they can refine them
    simd*: bool              ## -msimd128
    aot*: bool               ## also `wasmtime compile` to <name>.cwasm
    shape*: WasmShape
    witDir*: string          ## wsComponent: the WIT package with its deps
    world*: string           ## wsComponent: <package>/<world>
    exports*: seq[string]    ## wsComponent: the core exports (with cabi_realloc when the world needs it)

  WasmOutput* = object
    wasm*, cwasm*: string    ## wsComponent: `wasm` is <name>.core.wasm
    component*: string       ## wsComponent: <name>.component.wasm
    builtins*: BuiltinsKind
    notes*: seq[string]

proc targetCFlags*(sysroot: string, simd: bool): seq[string] {.raises: [].} =
  result = @["--target=" & Wasm32Wasip1, "--sysroot=" & sysroot, "-O2"]
  if simd: result.add "-msimd128"

proc nimArgs*(req: WasmRequest, nimcache: string): seq[string] {.raises: [].} =
  let recipe = if req.shape == wsComponent: @ComponentNimFlags else: @WasmNimFlags
  @["c", "--compileOnly", "--hints:off"] & recipe & req.nimFlags &
    @["--nimcache:" & nimcache, req.program]

proc nimCArgs*(tc: WasmToolchain, simd: bool, nimLib, cFile, oFile: string): seq[string] {.raises: [].} =
  ## Not -w, which Nim itself passes to clang: at clang's default warning
  ## level Nim's C for wasm32 gives no warning (NIV-34), so any warning is new
  ## and fails the build rather than vanishing into a log nobody reads.
  targetCFlags(tc.sysroot, simd) & @["-Werror", "-I" & nimLib, "-c", cFile, "-o", oFile]

proc ownCArgs*(tc: WasmToolchain, simd: bool, cFile, oFile: string): seq[string] {.raises: [].} =
  targetCFlags(tc.sysroot, simd) & @["-Wall", "-Wextra", "-Werror", "-c", cFile, "-o", oFile]

proc linkArgs*(tc: WasmToolchain, simd: bool, objects: seq[string], builtins, outFile: string): seq[string] {.raises: [].} =
  targetCFlags(tc.sysroot, simd) &
    @["-nodefaultlibs", "-Wl,--fatal-warnings", "-Wl,--max-memory=" & $MaxMemory, "-Wl,-z,stack-size=" & $StackSize] &
    objects & @["-lc", builtins, "-o", outFile]

proc componentLinkArgs*(tc: WasmToolchain, simd: bool, objects, exports: seq[string],
                        builtins, outFile: string): seq[string] {.raises: [].} =
  ## No C runtime and no entry: libc.a gives malloc and memcpy, and only the
  ## named functions are exported.
  result = targetCFlags(tc.sysroot, simd) & @["-nostdlib", "-Wl,--no-entry", "-Wl,--fatal-warnings"]
  for e in exports: result.add "-Wl,--export=" & e
  result.add @["-Wl,--max-memory=" & $MaxMemory, "-Wl,-z,stack-size=" & $StackSize]
  result.add objects
  result.add @[tc.sysroot / "lib" / Wasm32Wasip1 / "libc.a", builtins, "-o", outFile]

proc compilerRtIn*(resourceDir: string): string {.raises: [].} =
  ## The wasm32 compiler-rt under clang's resource directory, or "".
  for rel in CompilerRtCandidates:
    if fileExists(resourceDir / rel): return resourceDir / rel
  ""

proc tail(s: string, n: int): string {.raises: [].} =
  if s.len <= n: s else: "..." & s[s.len - n .. ^1]

proc toolErr[T](msg: string): NResult[T] {.raises: [].} =
  err(niuvError(ekTool, msg))

proc onPath(name: string): NResult[string] {.raises: [].} =
  var found: string
  try:
    found = findExe(name)
  except OSError as e:
    return toolErr[string]("looking for " & name & " on PATH: " & e.msg)
  if found.len == 0: return toolErr[string](name & " is not on PATH")
  ok(found)

proc findWasmToolchain*(llvmBin, sysroot: string, aot: bool,
                        component = false): NResult[WasmToolchain] {.raises: [].} =
  ## The tools of a wasm32-wasip1 build. Each one that is missing is refused
  ## by name; none is installed or fetched.
  var tc = WasmToolchain(sysroot: sysroot)
  tc.nim = ?onPath("nim")
  tc.clang = llvmBin / "clang"
  if not fileExists(tc.clang):
    return toolErr[WasmToolchain](tc.clang & " does not exist: wasm32-wasip1 needs LLVM's clang (--llvm DIR)")
  if not dirExists(sysroot / "lib" / Wasm32Wasip1):
    return toolErr[WasmToolchain](sysroot & " is not a wasi-sysroot (no lib/" & Wasm32Wasip1 & "; --sysroot DIR)")
  if aot:
    tc.wasmtime = ?onPath("wasmtime")
  if component:
    tc.wasmTools = ?onPath("wasm-tools")
  let r = ?runProcess(tc.clang, @["--target=" & Wasm32Wasip1, "-print-resource-dir"])
  if r.code != 0:
    return toolErr[WasmToolchain](tc.clang & " -print-resource-dir failed:\n" & tail(r.output, MaxCompilerOutput))
  tc.compilerRt = compilerRtIn(r.output.strip())
  ok(tc)

proc nimLibDir(tc: WasmToolchain, program: string): NResult[string] {.raises: [].} =
  let r = ?runProcess(tc.nim, @["dump", "--hints:off", "--dump.format:json", program])
  if r.code != 0:
    return err(niuvError(ekBuild, "nim dump failed for " & program & ":\n" & tail(r.output, MaxCompilerOutput)))
  for line in r.output.splitLines():
    if line.startsWith("{"):
      try:
        let lib = parseJson(line){"libpath"}
        if lib != nil and lib.kind == JString: return ok(lib.getStr())
      except CatchableError as e:
        return err(niuvError(ekBuild, "nim dump gave JSON that does not parse: " & e.msg))
  err(niuvError(ekBuild, "nim dump named no libpath for " & program))

proc runAll(exe: string, jobs: seq[seq[string]], logDir: string): NResult[void] {.raises: [].} =
  ## Runs `exe` once per argument list, as many at a time as there are
  ## processors. Each run's output goes to its own log, so a long error never
  ## fills a pipe; the first failure is returned with its log.
  let width = max(1, countProcessors())
  var running: seq[(Process, int)]
  var failure = ""
  proc logOf(i: int): string = logDir / ($i & ".log")
  proc reap(p: Process, i: int): string {.raises: [].} =
    try:
      let code = p.waitForExit()
      p.close()
      if code != 0:
        return "exit " & $code & " for " & jobs[i][^3] & ":\n" & tail(readFile(logOf(i)), MaxCompilerOutput)
    except CatchableError as e:
      return exe & ": " & e.msg
    ""
  try:
    createDir(logDir)
  except CatchableError as e:
    return err(niuvError(ekIo, logDir & ": " & e.msg))
  for i, args in jobs:
    if running.len >= width:
      let (p, j) = running[0]
      running.delete(0)
      let f = reap(p, j)
      if f.len > 0 and failure.len == 0: failure = f
    if failure.len > 0: break
    try:
      let p = startProcess("/bin/sh", args = @["-c", "log=$1; shift; exec \"$@\" >\"$log\" 2>&1", "sh", logOf(i), exe] & args,
                           options = {})
      running.add (p, i)
    except CatchableError as e:
      failure = exe & ": cannot start: " & e.msg
      break
  for (p, j) in running:
    let f = reap(p, j)
    if f.len > 0 and failure.len == 0: failure = f
  if failure.len > 0: return err(niuvError(ekBuild, failure))
  ok()

proc runStep(exe: string, args: seq[string], what: string): NResult[void] {.raises: [].} =
  let r = ?runProcess(exe, args)
  if r.code != 0:
    return err(niuvError(ekBuild, what & " failed (exit " & $r.code & "):\n" & tail(r.output, MaxCompilerOutput)))
  ok()

proc writeSource(path, content: string): NResult[void] {.raises: [].} =
  try:
    writeFile(path, content)
    ok()
  except CatchableError as e:
    err(niuvError(ekIo, path & ": " & e.msg))

proc buildWasm*(tc: WasmToolchain, req: WasmRequest): NResult[WasmOutput] {.raises: [].} =
  ## nim -> C (--compileOnly), every C file -> a wasm32 object, the C entry,
  ## the builtins, one link into <outDir>/<name>.wasm, and with `aot` the
  ## wasmtime AOT module <outDir>/<name>.cwasm. The stage is emptied first:
  ## C files left by an earlier program would otherwise be linked in.
  if not fileExists(req.program):
    return err(niuvError(ekUsage, req.program & " does not exist"))
  if req.shape == wsComponent:
    if req.world.len == 0 or req.exports.len == 0:
      return err(niuvError(ekUsage, "a component needs a world and at least one export"))
    if not dirExists(req.witDir):
      return err(niuvError(ekUsage, req.witDir & " is not a directory of WIT files"))
    if not fileExists(req.program.parentDir / "panicoverride.nim"):
      return err(niuvError(ekUsage, "--os:standalone needs panicoverride.nim next to " & req.program &
                           " (Nim includes it from the program's directory); its panic should trap " &
                           "(`{.emit: \"__builtin_trap();\".}`), not loop"))
    if tc.wasmTools.len == 0:
      return err(niuvError(ekTool, "a component needs wasm-tools (the toolchain was looked for without it)"))
  let cDir = req.stageDir / "c"
  let oDir = req.stageDir / "o"
  try:
    removeDir(req.stageDir)
    createDir(oDir)
    createDir(req.outDir)
  except CatchableError as e:
    return err(niuvError(ekIo, req.stageDir & ": " & e.msg))
  let nimLib = ?nimLibDir(tc, req.program)
  ?runStep(tc.nim, nimArgs(req, cDir), "nim for " & req.program)
  var jobs: seq[seq[string]]
  var objects: seq[string]
  try:
    for kind, c in walkDir(cDir):
      if kind == pcFile and c.endsWith(".c"):
        let o = oDir / (c.extractFilename.changeFileExt("") & ".o")
        jobs.add nimCArgs(tc, req.simd, nimLib, c, o)
        objects.add o
  except CatchableError as e:
    return err(niuvError(ekIo, cDir & ": " & e.msg))
  ?runAll(tc.clang, jobs, req.stageDir / "log")
  var output = WasmOutput()
  if req.shape == wsCommand:
    let startC = req.stageDir / "start.c"
    ?writeSource(startC, StartSource)
    ?runStep(tc.clang, ownCArgs(tc, req.simd, startC, req.stageDir / "start.o"), "clang for the C entry")
    objects.add req.stageDir / "start.o"
    output.wasm = req.outDir / (req.name & ".wasm")
  else:
    output.wasm = req.outDir / (req.name & ".core.wasm")
  var builtins = tc.compilerRt
  if builtins.len > 0:
    output.builtins = bkCompilerRt
  else:
    output.builtins = bkMulti3Shim
    let shimC = req.stageDir / "multi3.c"
    builtins = req.stageDir / "multi3.o"
    ?writeSource(shimC, Multi3Source)
    ?runStep(tc.clang, ownCArgs(tc, req.simd, shimC, builtins), "clang for the __multi3 shim")
    output.notes.add "no wasm32 compiler-rt next to " & tc.clang & ": linked niuv's __multi3 shim " &
                     "(`brew install wasi-runtimes` would provide compiler-rt; the owner's call)"
  let args =
    case req.shape
    of wsCommand: linkArgs(tc, req.simd, objects, builtins, output.wasm)
    of wsComponent: componentLinkArgs(tc, req.simd, objects, req.exports, builtins, output.wasm)
  let link = ?runProcess(tc.clang, args)
  if link.code != 0:
    var msg = "link failed (exit " & $link.code & "):\n" & tail(link.output, MaxCompilerOutput)
    if output.builtins == bkMulti3Shim and "undefined symbol: __" in link.output:
      msg.add "\nniuv's shim provides __multi3 only; this program needs more of compiler-rt " &
              "(`brew install wasi-runtimes` would provide it; the owner's call)"
    return err(niuvError(ekBuild, msg))
  if req.shape == wsComponent:
    let embedded = req.stageDir / (req.name & ".embedded.wasm")
    output.component = req.outDir / (req.name & ".component.wasm")
    ?runStep(tc.wasmTools, @["component", "embed", req.witDir, "--world", req.world, output.wasm, "-o", embedded],
             "wasm-tools component embed")
    ?runStep(tc.wasmTools, @["component", "new", embedded, "-o", output.component], "wasm-tools component new")
  if req.aot:
    output.cwasm = req.outDir / (req.name & ".cwasm")
    ?runStep(tc.wasmtime, @["compile", "-o", output.cwasm, output.wasm], "wasmtime compile")
  ok(output)

proc stageFor*(stageRoot, outDir, name: string): string {.raises: [].} =
  ## One stage per output directory and program, so two builds never share one.
  stageRoot / "wasm" / sha256Hex(outDir)[0 ..< 16] / name
