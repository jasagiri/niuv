## niuv: the build tool for Nim, Gleam and WASM. See README.md.

import std/os
import niuv/cli

proc main(): int {.raises: [].} =
  let args =
    try: commandLineParams()
    except CatchableError: @[]
  let r = runCli(args)
  try:
    stdout.write r.stdout
    stderr.write r.stderr
  except IOError:
    return 70
  r.code

quit main()
