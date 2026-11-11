## Acceptance (not part of test_all): a real closure of the foundation's `gl-*` packages, built from two
## different places, has the same SHA-256 for every shipped .beam, Erlang FFI and Hex packages included.
##
## The closure (what is there since the fukai agents moved to Nim, decision 147): `gl-upgrade-coordinator`, which
## depends on `gl-hotswap` in its own gleam.toml (a dependency between two real packages), `gl-port` and
## `gl-unix-frames` (each with its own Erlang FFI file), `gl-cbor-det` and `gl-mfa-supervisor`, and the Hex packages
## gleam_stdlib and gleam_erlang (the lock of gl-upgrade-coordinator pins them). Only the root is made here: a
## fixture package `gl-closure` that depends on the five packages by path and imports each, so that one root has the
## whole closure (no package of the foundation needs all of them).
##
## It reads the sibling repository (foundation) next to niuv, copies the Gleam packages into two trees of different
## depth, and builds each with its own stage directory. It needs `gleam` and `erl` on PATH and gleam's Hex cache to
## hold gleam_stdlib and gleam_erlang (`gleam deps download` in gl-upgrade-coordinator fills it). It fails, it does
## not skip, when the sibling repository is missing.
##
##   nim c -r --opt:speed tests/acceptance/test_gleam_closure_places.nim

import std/[algorithm, os, osproc, sequtils, strutils, unittest]
import ../../src/niuv/[artifact, cli, errors, gleambuild, hashing, resolve, toolchain, workspace]

let sources = normalizedPath(currentSourcePath().parentDir() / ".." / ".." / ".." / "..")

const root = "gl-closure"      ## the fixture package that needs the others

const packages = [
  ("gl-cbor-det", "foundation/gl-cbor-det"),
  ("gl-port", "foundation/gl-port"),
  ("gl-unix-frames", "foundation/gl-unix-frames"),
  ("gl-hotswap", "foundation/gl-hotswap"),
  ("gl-mfa-supervisor", "foundation/gl-mfa-supervisor"),
  ("gl-upgrade-coordinator", "foundation/gl-upgrade-coordinator")]

const needs = {
  "gl-upgrade-coordinator": "[\"gl-hotswap\"]",
  root: "[\"gl-cbor-det\", \"gl-port\", \"gl-unix-frames\", \"gl-mfa-supervisor\", \"gl-upgrade-coordinator\"]"}

const closureGleam = """name = "gl_closure"
version = "0.1.0"
licences = ["Apache-2.0"]
target = "erlang"

[dependencies]
gleam_stdlib = ">= 1.0.0 and < 2.0.0"
gleam_erlang = ">= 1.3.0 and < 2.0.0"
gl_cbor_det = { path = "../foundation/gl-cbor-det" }
gl_port = { path = "../foundation/gl-port" }
gl_unix_frames = { path = "../foundation/gl-unix-frames" }
gl_mfa_supervisor = { path = "../foundation/gl-mfa-supervisor" }
gl_upgrade_coordinator = { path = "../foundation/gl-upgrade-coordinator" }
"""

const closureSource = """import gl_cbor_det as _cbor
import gl_mfa_supervisor as _supervisor
import gl_port as _port
import gl_unix_frames as _frames
import gl_upgrade_coordinator as _coordinator

pub fn closure() -> Int {
  5
}
"""

proc copyTree(src, dst: string) =
  for rel in listFiles(src, [".git", ".jj", "build"]).get:
    createDir(parentDir(dst / rel))
    copyFile(src / rel, dst / rel)

proc declare(place, name, dir, deps: string, members: var seq[string]) =
  createDir(place / "decls" / name)
  writeFile(place / "decls" / name / "niuv.toml",
    "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\nroot = \"" & dir &
    "\"\n\n[gleam]\n" & (if deps.len > 0: "\n[dependencies]\nworkspace = " & deps & "\n" else: ""))
  members.add "\"decls/" & name & "\""

proc setUpPlace(place: string): string =
  ## Copies the packages under `place` (same layout as the sources), makes the fixture root next to them, and
  ## writes a workspace whose declarations point at the copies.
  removeDir(place)
  var members: seq[string]
  for (name, rel) in packages:
    copyTree(sources / rel, place / "src" / rel)
    var deps = ""
    for (n, list) in needs:
      if n == name: deps = list
    declare(place, name, place / "src" / rel, deps, members)
  let top = place / "src" / "closure"
  createDir(top / "src")
  writeFile(top / "gleam.toml", closureGleam)
  writeFile(top / "src" / "gl_closure.gleam", closureSource)
  # the Hex versions are the lock of gl-upgrade-coordinator (gleam_stdlib and gleam_erlang, as that package pins them)
  copyFile(sources / "foundation" / "gl-upgrade-coordinator" / "manifest.toml", top / "manifest.toml")
  var deps = ""
  for (n, list) in needs:
    if n == root: deps = list
  declare(place, root, top, deps, members)
  writeFile(place / "niuv.workspace.toml", "[workspace]\nmembers = [" & members.join(", ") & "]\n")
  place / "niuv.workspace.toml"

proc toolsFromPath(): (ToolInfo, ToolInfo) =
  let g = execCmdEx("gleam --version")[0].strip().split(' ')[1]
  let e = execCmdEx("erl -noshell -eval 'io:format(\"~s\",[string:trim(element(2,file:read_file(filename:join([code:root_dir(),\"releases\",erlang:system_info(otp_release),\"OTP_VERSION\"]))))]),halt().'")[0].strip()
  (probeTool(ToolSpec(name: "gleam", version: g)).get, probeTool(ToolSpec(name: "erlang", version: e)).get)

proc hashes(r: GleamResult): seq[string] =
  r.artifacts.mapIt(it.name & " " & it.sha256).sorted

suite "N2 acceptance: a closure of gl-* packages from two places":
  test "Given the gl-* closure built in two places, When every .beam is hashed, Then all SHA-256 are equal":
    let base = getTempDir() / "niuv-acceptance"
    let (gleam, erlang) = toolsFromPath()
    let wsA = loadWorkspace(setUpPlace(base / "a")).get
    let wsB = loadWorkspace(setUpPlace(base / "b" / "much" / "deeper" / "place")).get
    let ra = buildGleam(gleam, erlang, wsA, resolveClosure(wsA, root).get, base / "a-out", base / "a-stage")
    let rb = buildGleam(gleam, erlang, wsB, resolveClosure(wsB, root).get, base / "b-out", base / "b-stage" / "x")
    check ra.isOk and rb.isOk
    let ha = hashes(ra.get)
    let hb = hashes(rb.get)
    check ha.len >= 40
    check ha == hb
    for want in ["gl_port_ffi", "gl_unix_frames_ffi", "gleam_stdlib", "gleam_erlang_ffi", "gl_cbor_det",
                 "gl_hotswap", "gl_upgrade_coordinator", "gl_mfa_supervisor", "gl_closure", "gleam@list"]:
      check ra.get.artifacts.anyIt(it.name == want)
    check ra.get.hex.mapIt(it.name).sorted == @["gleam_erlang", "gleam_stdlib"]
    for c in ra.get.hex:
      check c.licenses == @["Apache-2.0"]
    for i in 0 ..< ha.len:
      if ha[i] != hb[i]: echo "DIFFERS: ", ha[i], " <> ", hb[i]

suite "N2 acceptance: a GPL-3.0 dependency of a sealed closure root":
  test "Given gpl-dep added to the sealed root, When built through the command line, Then it is refused naming it":
    let base = getTempDir() / "niuv-acceptance-gpl"
    let (gleam, erlang) = toolsFromPath()
    let wsFile = setUpPlace(base)
    # The root now depends on a GPL-3.0 package and is sealed.
    createDir(base / "src" / "gpl-dep" / "src")
    writeFile(base / "src" / "gpl-dep" / "gleam.toml", "name = \"gpl_dep\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\n")
    writeFile(base / "src" / "gpl-dep" / "src" / "gpl_dep.gleam", "pub fn x() -> Int {\n  1\n}\n")
    createDir(base / "decls" / "gpl-dep")
    writeFile(base / "decls" / "gpl-dep" / "niuv.toml",
      "[package]\nname = \"gpl-dep\"\nversion = \"0.1.0\"\nlicense = \"GPL-3.0-only\"\nroot = \"" &
      (base / "src" / "gpl-dep") & "\"\n\n[gleam]\n")
    let rootDecl = base / "decls" / root / "niuv.toml"
    writeFile(rootDecl, readFile(rootDecl).replace("[gleam]\n", "[gleam]\nsealed = true\n")
      .replace("workspace = [", "workspace = [\"gpl-dep\", "))
    writeFile(wsFile, readFile(wsFile).replace("\"decls/gl-closure\"", "\"decls/gl-closure\", \"decls/gpl-dep\"") &
      "\n[tools.gleam]\nversion = \"" & gleam.version & "\"\n[tools.erlang]\nversion = \"" & erlang.version & "\"\n")
    check runCli(@["lock", "--workspace", wsFile]).code == 0
    let r = runCli(@["build", root, "--workspace", wsFile, "--out", base / "out", "--stage", base / "stage"])
    check r.code != 0
    check "gpl-dep" in r.stderr and "GPL-3.0-only" in r.stderr
    check not dirExists(base / "stage")
    check not dirExists(base / "out" / "beam")
    # Without the seal the same declaration builds: the gate is for sealed artifacts.
    writeFile(rootDecl, readFile(rootDecl).replace("sealed = true\n", ""))
    check runCli(@["lock", "--workspace", wsFile]).code == 0
    let open = runCli(@["build", root, "--workspace", wsFile, "--out", base / "out", "--stage", base / "stage"])
    check open.code == 0
