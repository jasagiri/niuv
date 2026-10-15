## Running a program and keeping its output, as a value.

import std/[os, osproc, streams, strtabs]
import ./errors

type
  RunResult* = object
    output*: string        ## standard output and standard error together
    code*: int

proc runProcess*(exe: string, args: seq[string], workDir = "",
                 env: seq[(string, string)] = @[]): NResult[RunResult] {.raises: [].} =
  ## Runs `exe` (a path, not searched on PATH) and waits. `env` is added to
  ## the environment of this process; a key already there is replaced.
  var p: Process
  try:
    var table: StringTableRef = nil
    if env.len > 0:
      table = newStringTable(modeCaseSensitive)
      for k, v in envPairs(): table[k] = v
      for (k, v) in env: table[k] = v
    p = startProcess(exe, workingDir = workDir, args = args, env = table,
                     options = {poStdErrToStdout})
  except CatchableError as e:
    return err(niuvError(ekIo, exe & ": cannot start: " & e.msg))
  var res = RunResult()
  try:
    res.output = p.outputStream.readAll()
    res.code = p.waitForExit()
    p.close()
  except CatchableError as e:
    var msg = exe & ": " & e.msg
    try:
      p.close()
    except CatchableError as closing:
      msg.add "; closing the process also failed: " & closing.msg
    return err(niuvError(ekIo, msg))
  ok(res)
