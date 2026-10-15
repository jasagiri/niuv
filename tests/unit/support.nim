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

import std/osproc
import ../../src/niuv/[errors, toolchain, workspace]

## Probing hashes the executable, which is slow in a debug build for a 25 MB
## gleam; each tool is probed once per test process.
var nimCache, gleamCache, erlangCache: ToolInfo

proc realNim*(): ToolInfo =
  ## The nim on PATH, found the same way a user would pin it.
  if nimCache.name.len == 0:
    let (o, _) = execCmdEx("nim --version")
    let version = o.splitLines()[0].split("Version ")[1].split(' ')[0]
    nimCache = probeTool(ToolSpec(name: "nim", version: version, via: "")).get
  nimCache

proc realGleam*(): ToolInfo =
  if gleamCache.name.len == 0:
    let (o, _) = execCmdEx("gleam --version")
    gleamCache = probeTool(ToolSpec(name: "gleam", version: o.strip().split(' ')[1], via: "")).get
  gleamCache

proc realErlang*(): ToolInfo =
  if erlangCache.name.len == 0:
    let (o, _) = execCmdEx("erl -noshell -eval 'io:format(\"~s\",[string:trim(element(2,file:read_file(filename:join([code:root_dir(),\"releases\",erlang:system_info(otp_release),\"OTP_VERSION\"]))))]),halt().'")
    erlangCache = probeTool(ToolSpec(name: "erlang", version: o.strip(), via: "")).get
  erlangCache
