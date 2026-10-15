## Acceptance (not part of test_all): the real fukai/agent, built from two
## different places, has the same SHA-256 for every shipped .beam, Erlang
## FFI and Hex packages included.
##
## It reads the sibling repositories (fukai, foundation) next to niuv, copies
## the Gleam packages of the agent's closure into two trees of different
## depth, and builds each with its own stage directory. It needs `gleam` and
## `erl` on PATH and gleam's Hex cache to hold gleam_stdlib and gleam_erlang
## (the agent's manifest.toml pins them). It fails, it does not skip, when the
## sibling repositories are missing.
##
##   nim c -r --opt:speed tests/acceptance/test_fukai_agent.nim

import std/[algorithm, os, osproc, sequtils, strutils, unittest]
import ../../src/niuv/[artifact, cli, errors, gleambuild, hashing, resolve, toolchain, workspace]

let sources = normalizedPath(currentSourcePath().parentDir() / ".." / ".." / ".." / "..")

const packages = [
  ("gl-cbor-det", "foundation/gl-cbor-det", ""),
  ("gl-port", "foundation/gl-port", ""),
  ("gl-hotswap", "foundation/gl-hotswap", ""),
  ("gl-mfa-supervisor", "foundation/gl-mfa-supervisor", ""),
  ("fukai-column", "fukai/database/gleam/fukai_column", ""),
  ("fukai-store", "fukai/store", "gleam/fukai_store"),
  ("fukai-agent", "fukai/agent", "")]

const needs = {
  "fukai-store": "[\"gl-cbor-det\", \"gl-port\"]",
  "fukai-agent": "[\"gl-mfa-supervisor\", \"gl-hotswap\", \"gl-cbor-det\", \"fukai-column\", \"fukai-store\"]"}

proc copyTree(src, dst: string) =
  for rel in listFiles(src, [".git", ".jj", "build"]).get:
    createDir(parentDir(dst / rel))
    copyFile(src / rel, dst / rel)

proc setUpPlace(place: string): string =
  ## Copies the packages under `place` (same layout as the sources) and
  ## writes a workspace whose declarations point at the copies.
  removeDir(place)
  var members: seq[string]
  for (name, rel, gleamRoot) in packages:
    copyTree(sources / rel, place / "src" / rel)
    var deps = ""
    for (n, list) in needs:
      if n == name: deps = "\n[dependencies]\nworkspace = " & list & "\n"
    createDir(place / "decls" / name)
    writeFile(place / "decls" / name / "niuv.toml",
      "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\nroot = \"" &
      (place / "src" / rel) & "\"\n\n[gleam]\n" & (if gleamRoot.len > 0: "root = \"" & gleamRoot & "\"\n" else: "") & deps)
    members.add "\"decls/" & name & "\""
  writeFile(place / "niuv.workspace.toml", "[workspace]\nmembers = [" & members.join(", ") & "]\n")
  place / "niuv.workspace.toml"

proc toolsFromPath(): (ToolInfo, ToolInfo) =
  let g = execCmdEx("gleam --version")[0].strip().split(' ')[1]
  let e = execCmdEx("erl -noshell -eval 'io:format(\"~s\",[string:trim(element(2,file:read_file(filename:join([code:root_dir(),\"releases\",erlang:system_info(otp_release),\"OTP_VERSION\"]))))]),halt().'")[0].strip()
  (probeTool(ToolSpec(name: "gleam", version: g)).get, probeTool(ToolSpec(name: "erlang", version: e)).get)

proc hashes(r: GleamResult): seq[string] =
  r.artifacts.mapIt(it.name & " " & it.sha256).sorted

suite "N2 acceptance: fukai/agent from two places":
  test "Given the real agent built in two places, When every .beam is hashed, Then all SHA-256 are equal":
    let base = getTempDir() / "niuv-acceptance"
    let (gleam, erlang) = toolsFromPath()
    let wsA = loadWorkspace(setUpPlace(base / "a")).get
    let wsB = loadWorkspace(setUpPlace(base / "b" / "much" / "deeper" / "place")).get
    let ra = buildGleam(gleam, erlang, resolveClosure(wsA, "fukai-agent").get, base / "a-out", base / "a-stage")
    let rb = buildGleam(gleam, erlang, resolveClosure(wsB, "fukai-agent").get, base / "b-out", base / "b-stage" / "x")
    check ra.isOk and rb.isOk
    let ha = hashes(ra.get)
    let hb = hashes(rb.get)
    check ha.len >= 50
    check ha == hb
    for want in ["fukai_agent_ffi", "fukai_column_ffi", "gleam_stdlib", "gleam_erlang_ffi", "gl_cbor_det",
                 "gleam@list"]:
      check ra.get.artifacts.anyIt(it.name == want)
    check ra.get.hex.mapIt(it.name).sorted == @["gleam_erlang", "gleam_stdlib"]
    for c in ra.get.hex:
      check c.licenses == @["Apache-2.0"]
    for i in 0 ..< ha.len:
      if ha[i] != hb[i]: echo "DIFFERS: ", ha[i], " <> ", hb[i]

suite "N2 acceptance: a GPL-3.0 dependency of a sealed agent":
  test "Given gpl-dep added to the sealed agent, When built through the command line, Then it is refused naming it":
    let base = getTempDir() / "niuv-acceptance-gpl"
    let (gleam, erlang) = toolsFromPath()
    let wsFile = setUpPlace(base)
    # The agent now depends on a GPL-3.0 package and is sealed.
    createDir(base / "src" / "gpl-dep" / "src")
    writeFile(base / "src" / "gpl-dep" / "gleam.toml", "name = \"gpl_dep\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\n")
    writeFile(base / "src" / "gpl-dep" / "src" / "gpl_dep.gleam", "pub fn x() -> Int {\n  1\n}\n")
    createDir(base / "decls" / "gpl-dep")
    writeFile(base / "decls" / "gpl-dep" / "niuv.toml",
      "[package]\nname = \"gpl-dep\"\nversion = \"0.1.0\"\nlicense = \"GPL-3.0-only\"\nroot = \"" &
      (base / "src" / "gpl-dep") & "\"\n\n[gleam]\n")
    let agentDecl = base / "decls" / "fukai-agent" / "niuv.toml"
    writeFile(agentDecl, readFile(agentDecl).replace("[gleam]\n", "[gleam]\nsealed = true\n")
      .replace("workspace = [", "workspace = [\"gpl-dep\", "))
    writeFile(wsFile, readFile(wsFile).replace("\"decls/fukai-agent\"", "\"decls/fukai-agent\", \"decls/gpl-dep\"") &
      "\n[tools.gleam]\nversion = \"" & gleam.version & "\"\n[tools.erlang]\nversion = \"" & erlang.version & "\"\n")
    check runCli(@["lock", "--workspace", wsFile]).code == 0
    let r = runCli(@["build", "fukai-agent", "--workspace", wsFile, "--out", base / "out", "--stage", base / "stage"])
    check r.code != 0
    check "gpl-dep" in r.stderr and "GPL-3.0-only" in r.stderr
    check not dirExists(base / "stage")
    check not dirExists(base / "out" / "beam")
    # Without the seal the same declaration builds: the gate is for sealed artifacts.
    writeFile(agentDecl, readFile(agentDecl).replace("sealed = true\n", ""))
    check runCli(@["lock", "--workspace", wsFile]).code == 0
    let open = runCli(@["build", "fukai-agent", "--workspace", wsFile, "--out", base / "out", "--stage", base / "stage"])
    check open.code == 0
