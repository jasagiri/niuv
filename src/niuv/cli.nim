## The command line (NIV-22, NIV-39): lock, check, build, child, wasm. Nothing else.

import std/[options, os, sequtils, strutils, tables]
import ./[artifact, build, child, errors, inbuilder, lock, resolve, wasm, workspace]

type
  CliResult* = object
    code*: int
    stdout*, stderr*: string

const
  Usage = """usage: niuv <command> [options]

commands:
  lock                      pin tools, packages and external dependencies (writes niuv.lock, or niuv.<target>.lock)
  check <package>           resolve the closure of a package and list it
  build <package>           build the package's artifacts [--out DIR] [--bin NAME]... [--stage DIR]
  child                     serve one build request on frames (for the key keeper's children)
  wasm <program.nim>        build one Nim program as a wasm32-wasip1 command module (not locked)
                            [--out DIR] [--name NAME] [--stage DIR] [--nim-flag F]... [--no-simd] [--aot]
                            [--llvm DIR] [--sysroot DIR]

options:
  --workspace FILE          the niuv.workspace.toml (default: the nearest one above the current directory)
  --target T                lock and build for target T (aarch64-linux-musl, aarch64-macos-none): this
                            machine's own, or another one with --in-builder
  --builder NAME@sha256:D   lock --target: the builder image the target's build runs in
  --in-builder              lock and build --target T in the builder image, in a kite guest without network
  --repin-builder           lock --in-builder --builder X: move a builder image the lock already pins to X
    --signature FILE, --kernel FILE, --initrd FILE, --cpu N, --memory MB   how the guest is started
    --hex-cache DIR         gleam's Hex copy, handed to the guest read-only
  --in-guest                (set by --in-builder) niuv runs in the builder guest: tools are looked up on
                            PATH, and the external roots are the --external-root ones
    --external-root DIR     (with --in-guest, repeatable) a directory to look for external dependencies in
    --lock-out FILE         (lock) write the lock there instead of next to the workspace file
  --stage DIR             where scratch files go (build, and lock --in-builder)
"""

type
  Parsed = object
    positional: seq[string]
    opts: Table[string, seq[string]]

proc fail(msg: string, code = 1): CliResult {.raises: [].} =
  CliResult(code: code, stderr: "niuv: " & msg & "\n")

proc usageFail(msg: string): CliResult {.raises: [].} =
  CliResult(code: 2, stderr: "niuv: " & msg & "\n\n" & Usage)

const
  GuestOptions = ["--signature", "--kernel", "--initrd", "--cpu", "--memory", "--hex-cache"]

proc parseArgs(args: seq[string], valued: openArray[string],
               flags: openArray[string] = []): Result[Parsed, string] {.raises: [].} =
  var p = Parsed()
  var i = 0
  while i < args.len:
    let a = args[i]
    if a.startsWith("--"):
      if a in flags:
        p.opts.mgetOrPut(a, @[]).add ""
        inc i
        continue
      if a notin valued: return err("unknown option " & a)
      if i + 1 >= args.len: return err("option " & a & " needs a value")
      p.opts.mgetOrPut(a, @[]).add args[i + 1]
      i += 2
    else:
      p.positional.add a
      inc i
  ok(p)

proc findWorkspaceFile(start: string): NResult[string] {.raises: [].} =
  var dir = start
  while true:
    let f = dir / "niuv.workspace.toml"
    if fileExists(f): return ok(f)
    let up = parentDir(dir)
    if up == dir or up.len == 0:
      return err(niuvError(ekWorkspace, "no niuv.workspace.toml found from " & start & " upward (use --workspace)"))
    dir = up

proc openWorkspace(p: Parsed): NResult[Workspace] {.raises: [].} =
  let given = p.opts.getOrDefault("--workspace")
  if given.len > 0: return loadWorkspace(given[^1])
  var cwd: string
  try:
    cwd = getCurrentDir()
  except CatchableError as e:
    return err(niuvError(ekIo, "current directory: " & e.msg))
  loadWorkspace(?findWorkspaceFile(cwd))

type
  Mode = object
    target: string           ## "" when --target was not given (NIV-24, NIV-25)
    inBuilder, inGuest: bool
    guest: BuilderOptions
    externalRoots: seq[string]

proc positiveInt(p: Parsed, name: string): Result[int, string] {.raises: [].} =
  let given = p.opts.getOrDefault(name)
  if given.len == 0: return ok(0)
  try:
    let n = parseInt(given[^1])
    if n <= 0: return err(name & " must be a positive number")
    ok(n)
  except ValueError:
    err(name & " must be a number, not '" & given[^1] & "'")

proc readMode(p: Parsed): Result[Mode, string] {.raises: [].} =
  ## The options that say where the build runs, checked against each other.
  var m = Mode()
  let tg = p.opts.getOrDefault("--target")
  if tg.len > 0: m.target = tg[^1]
  m.inBuilder = p.opts.hasKey("--in-builder")
  m.inGuest = p.opts.hasKey("--in-guest")
  if m.inBuilder and m.inGuest: return err("--in-builder and --in-guest are not used together")
  if m.inBuilder and m.target.len == 0: return err("--in-builder needs --target")
  if p.opts.hasKey("--external-root") and not m.inGuest: return err("--external-root is for --in-guest")
  if not m.inBuilder:
    for o in GuestOptions:
      if p.opts.hasKey(o): return err(o & " is for --in-builder")
  let sig = p.opts.getOrDefault("--signature")
  let kernel = p.opts.getOrDefault("--kernel")
  let initrd = p.opts.getOrDefault("--initrd")
  let hex = p.opts.getOrDefault("--hex-cache")
  m.guest = BuilderOptions(signature: if sig.len > 0: sig[^1] else: "", kernel: if kernel.len > 0: kernel[^1] else: "",
                           initrd: if initrd.len > 0: initrd[^1] else: "", hexCache: if hex.len > 0: hex[^1] else: "")
  m.guest.cpu = ?positiveInt(p, "--cpu")
  m.guest.memoryMb = ?positiveInt(p, "--memory")
  for r in p.opts.getOrDefault("--external-root"):
    try:
      m.externalRoots.add normalizedPath(absolutePath(r))
    except CatchableError as e:
      return err("--external-root " & r & ": " & e.msg)
  ok(m)

proc openWorkspace(p: Parsed, m: Mode): NResult[Workspace] {.raises: [].} =
  var ws = ?openWorkspace(p)
  if m.inGuest: ws.externalRoots = m.externalRoots   # NIV-28: what the host passed, not the host's own paths
  ok(ws)

proc cmdLock(args: seq[string]): CliResult {.raises: [].} =
  let p = parseArgs(args, @["--workspace", "--target", "--builder", "--lock-out", "--stage"] & @GuestOptions & @["--external-root"],
                    ["--in-builder", "--in-guest", "--repin-builder"])
  if p.isErr: return usageFail(p.error)
  if p.get.positional.len > 0: return usageFail("lock takes no arguments")
  let mode = readMode(p.get)
  if mode.isErr: return usageFail(mode.error)
  let m = mode.get
  let builderGiven = p.get.opts.getOrDefault("--builder")
  if builderGiven.len > 0 and m.target.len == 0: return usageFail("--builder needs --target")
  let repin = p.get.opts.hasKey("--repin-builder")
  if repin and not m.inBuilder: return usageFail("--repin-builder is for --in-builder")
  if p.get.opts.hasKey("--lock-out") and m.target.len == 0: return usageFail("--lock-out needs --target")
  let ws = openWorkspace(p.get, m)
  if ws.isErr: return fail($ws.error)
  var image = none(LockedBuilder)
  if builderGiven.len > 0:
    let b = checkBuilderImage(builderGiven[^1])
    if b.isErr: return fail($b.error)
    image = some(b.get)
  var l: Lock
  let stageGiven = p.get.opts.getOrDefault("--stage")
  if m.inBuilder:
    let r = lockInBuilder(ws.get, m.target, (if builderGiven.len > 0: builderGiven[^1] else: ""),
                          (if stageGiven.len > 0: stageGiven[^1] else: defaultStageRoot()), m.guest, repin)
    if r.isErr: return fail($r.error)
    l = r.get
  else:
    let r = lockWorkspace(ws.get, m.target, image, m.inGuest)
    if r.isErr: return fail($r.error)
    l = r.get
  let outGiven = p.get.opts.getOrDefault("--lock-out")
  let dest = if outGiven.len > 0: outGiven[^1] else: lockPath(ws.get, m.target)
  let w = writeLockFile(dest, l)
  if w.isErr: return fail($w.error)
  CliResult(stdout: "locked " & $l.packages.len & " packages, " & $l.externals.len &
                    " external dependencies, " & $l.tools.len & " tools in " & dest & "\n")

proc cmdCheck(args: seq[string]): CliResult {.raises: [].} =
  let p = parseArgs(args, ["--workspace"])
  if p.isErr: return usageFail(p.error)
  if p.get.positional.len != 1: return usageFail("check needs one package name")
  let ws = openWorkspace(p.get)
  if ws.isErr: return fail($ws.error)
  let c = resolveClosure(ws.get, p.get.positional[0])
  if c.isErr: return fail($c.error)
  var o = ""
  for d in c.get.packages: o.add "package " & d.name & " " & d.version & " " & d.root & "\n"
  for e in c.get.externals: o.add "external " & e.name & " " & e.version & " " & e.dir & "\n"
  CliResult(stdout: o)

proc cmdBuild(args: seq[string]): CliResult {.raises: [].} =
  let p = parseArgs(args, @["--workspace", "--out", "--bin", "--stage", "--target"] & @GuestOptions & @["--external-root"],
                    ["--in-builder", "--in-guest"])
  if p.isErr: return usageFail(p.error)
  if p.get.positional.len != 1: return usageFail("build needs one package name")
  let mode = readMode(p.get)
  if mode.isErr: return usageFail(mode.error)
  let m = mode.get
  let ws = openWorkspace(p.get, m)
  if ws.isErr: return fail($ws.error)
  let package = p.get.positional[0]
  let outGiven = p.get.opts.getOrDefault("--out")
  var outDir = ws.get.dir / "build" / "niuv" / package
  if outGiven.len > 0:
    try:
      outDir = normalizedPath(absolutePath(outGiven[^1]))
    except CatchableError as e:
      return fail("--out " & outGiven[^1] & ": " & e.msg)
  let stageGiven = p.get.opts.getOrDefault("--stage")
  let stageRoot = if stageGiven.len > 0: stageGiven[^1] else: defaultStageRoot()
  var artifacts: seq[Artifact]
  var notes: seq[string]
  var manifestPath, sbomPath: string
  if m.inBuilder:
    let r = buildInBuilder(ws.get, package, m.target, outDir, stageRoot, p.get.opts.getOrDefault("--bin"), m.guest)
    if r.isErr: return fail($r.error)
    artifacts = r.get.outcome.artifacts
    manifestPath = r.get.outcome.manifestPath
    sbomPath = r.get.outcome.sbomPath
  else:
    let r = buildPackage(ws.get, package, outDir, stageRoot, p.get.opts.getOrDefault("--bin"), m.target, m.inGuest)
    if r.isErr: return fail($r.error)
    artifacts = r.get.artifacts
    notes = r.get.notes
    manifestPath = r.get.manifestPath
    sbomPath = r.get.sbomPath
  var o = ""
  for a in artifacts:
    o.add a.name & " " & $a.kind & " " & a.sha256 & " " & $a.size & " " & a.path & "\n"
  for n in notes: o.add "note: " & n & "\n"
  o.add "manifest " & manifestPath & "\n"
  o.add "sbom " & sbomPath & "\n"
  CliResult(stdout: o)

proc cmdWasm(args: seq[string]): CliResult {.raises: [].} =
  let p = parseArgs(args, ["--out", "--name", "--stage", "--nim-flag", "--llvm", "--sysroot"], ["--no-simd", "--aot"])
  if p.isErr: return usageFail(p.error)
  if p.get.positional.len != 1: return usageFail("wasm needs one Nim program")
  let last = proc (name, default: string): string =
    let given = p.get.opts.getOrDefault(name)
    if given.len > 0: given[^1] else: default
  var program, outDir: string
  try:
    program = normalizedPath(absolutePath(p.get.positional[0]))
    outDir = normalizedPath(absolutePath(last("--out", program.parentDir / "build" / Wasm32Wasip1)))
  except CatchableError as e:
    return fail(e.msg)
  let name = last("--name", program.extractFilename.changeFileExt(""))
  let aot = p.get.opts.hasKey("--aot")
  let tc = findWasmToolchain(last("--llvm", DefaultLlvmBin), last("--sysroot", DefaultWasiSysroot), aot)
  if tc.isErr: return fail($tc.error)
  let req = WasmRequest(program: program, outDir: outDir, name: name,
                        stageDir: stageFor(last("--stage", defaultStageRoot()), outDir, name),
                        nimFlags: p.get.opts.getOrDefault("--nim-flag"),
                        simd: not p.get.opts.hasKey("--no-simd"), aot: aot)
  let r = buildWasm(tc.get, req)
  if r.isErr: return fail($r.error)
  var o = "wasm " & r.get.wasm & "\n"
  if r.get.cwasm.len > 0: o.add "cwasm " & r.get.cwasm & "\n"
  CliResult(stdout: o, stderr: r.get.notes.mapIt("niuv: note: " & it & "\n").join(""))

proc runCli*(args: seq[string]): CliResult {.raises: [].} =
  if args.len == 0: return usageFail("no command")
  case args[0]
  of "--help", "-h", "help": CliResult(stdout: Usage)
  of "lock": cmdLock(args[1 .. ^1])
  of "check": cmdCheck(args[1 .. ^1])
  of "build": cmdBuild(args[1 .. ^1])
  of "child": CliResult(code: runBuildChild())
  of "wasm": cmdWasm(args[1 .. ^1])
  else: usageFail("unknown command '" & args[0] & "'")
