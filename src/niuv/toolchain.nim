## The tools niuv drives: where they are, which version they really are, and
## the SHA-256 of their executable (NIV-13).
##
## `via = "mise"` only finds the install directory. The version and the hash
## are then read from the executable itself, so the lock check is the same
## whether mise or PATH found it.

import std/[options, os, strutils]
import ./[errors, exec, hashing, workspace]

type
  ToolInfo* = object
    name*: string
    version*: string
    exe*: string           ## absolute, symlinks resolved
    sha256*: string
    binDir*: string        ## where it was found, for the PATH of a build

proc exeName(tool: string): string {.raises: [].} =
  ## erlang is pinned by `erlc`, the compiler that makes the .beam files.
  if tool == "erlang": "erlc" else: tool

proc toolErr[T](msg: string): NResult[T] {.raises: [].} =
  err(niuvError(ekTool, msg))

proc onPath(exe: string): NResult[string] {.raises: [].} =
  try:
    ok(findExe(exe))
  except CatchableError as e:
    err(niuvError(ekIo, "searching PATH for " & exe & ": " & e.msg))

proc locate(spec: ToolSpec): NResult[string] {.raises: [].} =
  let exe = exeName(spec.name)
  case spec.via
  of "mise":
    let mise = ?onPath("mise")
    if mise.len == 0: return toolErr[string]("tool " & spec.name & ": via = \"mise\" but mise is not on PATH")
    let r = ?runProcess(mise, @["where", spec.name & "@" & spec.version])
    if r.code != 0:
      return toolErr[string]("tool " & spec.name & ": mise does not have " & spec.name & "@" &
                             spec.version & ": " & r.output.strip())
    let path = r.output.strip() / "bin" / exe
    if not fileExists(path):
      return toolErr[string]("tool " & spec.name & ": " & path & " does not exist")
    ok(path)
  else:
    let path = ?onPath(exe)
    if path.len == 0:
      return toolErr[string]("tool " & spec.name & ": '" & exe & "' is not on PATH")
    ok(path)

proc versionOf(spec: ToolSpec, exe: string): NResult[string] {.raises: [].} =
  case spec.name
  of "nim":
    let r = ?runProcess(exe, @["--version"])
    for line in r.output.splitLines:
      let at = line.find("Version ")
      if at >= 0: return ok(line[at + 8 .. ^1].split(' ')[0])
    toolErr[string]("tool nim: no 'Version' in the output of '" & exe & " --version'")
  of "gleam":
    let r = ?runProcess(exe, @["--version"])
    let parts = r.output.strip().split(' ')
    if parts.len == 2 and parts[0] == "gleam": return ok(parts[1])
    toolErr[string]("tool gleam: cannot read a version from '" & r.output.strip() & "'")
  of "erlang":
    let erl = parentDir(exe) / "erl"
    if not fileExists(erl): return toolErr[string]("tool erlang: " & erl & " does not exist")
    const probe = "{ok,V}=file:read_file(filename:join([code:root_dir(),\"releases\"," &
                  "erlang:system_info(otp_release),\"OTP_VERSION\"]))," &
                  "io:format(\"~s\",[string:trim(V)]),halt()."
    let r = ?runProcess(erl, @["-noshell", "-eval", probe])
    if r.code != 0: return toolErr[string]("tool erlang: " & erl & " failed: " & r.output.strip())
    ok(r.output.strip())
  else:
    toolErr[string]("tool " & spec.name & " is not one niuv drives")

proc probeTool*(spec: ToolSpec): NResult[ToolInfo] {.raises: [].} =
  ## Finds the tool, reads its real version and requires it to equal the pin.
  let found = ?locate(spec)
  var real: string
  try:
    real = expandFilename(found)
  except CatchableError as e:
    return toolErr[ToolInfo]("tool " & spec.name & ": " & found & ": " & e.msg)
  let actual = ?versionOf(spec, real)
  if actual != spec.version:
    return toolErr[ToolInfo]("tool " & spec.name & ": declared " & spec.version & " but " & real &
                             " is " & actual)
  ok(ToolInfo(name: spec.name, version: actual, exe: real, sha256: ?sha256File(real),
              binDir: parentDir(found)))

proc probeTools*(ws: Workspace, names: openArray[string]): NResult[seq[ToolInfo]] {.raises: [].} =
  ## The named tools, each of which the workspace must pin.
  var infos: seq[ToolInfo]
  for n in names:
    let spec = ws.tool(n)
    if spec.isNone:
      return toolErr[seq[ToolInfo]]("the workspace pins no [tools." & n & "] in " & ws.file)
    infos.add ?probeTool(spec.get)
  ok(infos)

proc pathWith*(tools: openArray[ToolInfo]): string {.raises: [].} =
  ## PATH with the tools' directories first, so that `gleam` finds the `erlc`
  ## niuv pinned and not another one.
  var dirs: seq[string]
  for t in tools:
    if t.binDir.len > 0 and t.binDir notin dirs: dirs.add t.binDir
  dirs.add getEnv("PATH")
  dirs.join($PathSep)
