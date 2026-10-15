## Helpers shared by the tests: throw-away directories and file trees.

import std/[os, strutils]

proc freshDir*(name: string): string =
  ## An empty directory under the system temp directory, named for the test.
  let d = getTempDir() / ("niuv-test-" & name)
  removeDir(d)
  createDir(d)
  d

proc writeTree*(root: string, files: openArray[(string, string)]) =
  ## Writes `files` (relative path, content) under `root`.
  for (rel, content) in files:
    let p = root / rel
    createDir(parentDir(p))
    writeFile(p, content)

proc dedent*(s: string): string =
  s.strip(leading = true, trailing = false, chars = {'\n'})
