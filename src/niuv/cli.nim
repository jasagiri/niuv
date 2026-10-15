## The command line (NIV-22): lock, check, build, child. Nothing else.

import std/[os, strutils, tables]
import ./[artifact, build, errors, lock, resolve, workspace]

type
  CliResult* = object
    code*: int
    stdout*, stderr*: string

const
  Usage = """usage: niuv <command> [options]

commands:
  lock                      pin tools, packages and external dependencies (writes niuv.lock)
  check <package>           resolve the closure of a package and list it
  build <package>           build the package's artifacts [--out DIR] [--bin NAME]...
  child                     serve one build request on frames (for the key keeper's children)

options:
  --workspace FILE          the niuv.workspace.toml (default: the nearest one above the current directory)
"""

type
  Parsed = object
    positional: seq[string]
    opts: Table[string, seq[string]]

proc fail(msg: string, code = 1): CliResult {.raises: [].} =
  CliResult(code: code, stderr: "niuv: " & msg & "\n")

proc usageFail(msg: string): CliResult {.raises: [].} =
  CliResult(code: 2, stderr: "niuv: " & msg & "\n\n" & Usage)

proc parseArgs(args: seq[string], valued: openArray[string]): Result[Parsed, string] {.raises: [].} =
  var p = Parsed()
  var i = 0
  while i < args.len:
    let a = args[i]
    if a.startsWith("--"):
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

proc cmdLock(args: seq[string]): CliResult {.raises: [].} =
  let p = parseArgs(args, ["--workspace"])
  if p.isErr: return usageFail(p.error)
  if p.get.positional.len > 0: return usageFail("lock takes no arguments")
  let ws = openWorkspace(p.get)
  if ws.isErr: return fail($ws.error)
  let l = lockWorkspace(ws.get)
  if l.isErr: return fail($l.error)
  let w = writeLock(ws.get, l.get)
  if w.isErr: return fail($w.error)
  CliResult(stdout: "locked " & $l.get.packages.len & " packages, " & $l.get.externals.len &
                    " external dependencies, " & $l.get.tools.len & " tools in " & lockPath(ws.get) & "\n")

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
  let p = parseArgs(args, ["--workspace", "--out", "--bin"])
  if p.isErr: return usageFail(p.error)
  if p.get.positional.len != 1: return usageFail("build needs one package name")
  let ws = openWorkspace(p.get)
  if ws.isErr: return fail($ws.error)
  let package = p.get.positional[0]
  let outGiven = p.get.opts.getOrDefault("--out")
  var outDir = ws.get.dir / "build" / "niuv" / package
  if outGiven.len > 0:
    try:
      outDir = absolutePath(outGiven[^1])
    except CatchableError as e:
      return fail("--out " & outGiven[^1] & ": " & e.msg)
  let r = buildPackage(ws.get, package, outDir, p.get.opts.getOrDefault("--bin"))
  if r.isErr: return fail($r.error)
  var o = ""
  for a in r.get.artifacts:
    o.add a.name & " " & $a.kind & " " & a.sha256 & " " & $a.size & " " & a.path & "\n"
  for n in r.get.notes: o.add "note: " & n & "\n"
  CliResult(stdout: o)

proc runCli*(args: seq[string]): CliResult {.raises: [].} =
  if args.len == 0: return usageFail("no command")
  case args[0]
  of "--help", "-h", "help": CliResult(stdout: Usage)
  of "lock": cmdLock(args[1 .. ^1])
  of "check": cmdCheck(args[1 .. ^1])
  of "build": cmdBuild(args[1 .. ^1])
  of "child": usageFail("child is not implemented yet")
  else: usageFail("unknown command '" & args[0] & "'")
