## E tests for the lock: NIV-11 (content), NIV-12 (stale), NIV-13 (tool pin),
## NIV-25 (one lock per target) and NIV-26 (the builder image).

import std/[options, os, osproc, sequtils, strutils, unittest]
import ../../src/niuv/[errors, hashing, lock, resolve, toolchain, workspace]
import support

const testFile* = "tests/unit/test_lock.nim"

suite "NIV-11 content hash":
  test "Given the bytes abc, When hashed, Then the SHA-256 is the standard vector":
    check sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

  test "Given a file, When hashed, Then it equals the hash of its bytes":
    let d = freshDir("hash-file")
    writeTree(d, {"a.txt": "abc"})
    check sha256File(d / "a.txt").get == sha256Hex("abc")

  test "Given a missing file, When hashed, Then an io error is returned":
    let r = sha256File(getTempDir() / "niuv-test-no-such-file")
    check r.isErr
    check r.error.kind == ekIo

  test "Given the same files created in another order, When tree-hashed, Then the hash is equal":
    let a = freshDir("tree-a")
    let b = freshDir("tree-b")
    writeTree(a, {"x/1.nim": "one", "y.nim": "two"})
    writeTree(b, {"y.nim": "two", "x/1.nim": "one"})
    check treeHash(a).get == treeHash(b).get

  test "Given one byte changed, When tree-hashed, Then the hash differs":
    let a = freshDir("tree-c")
    let b = freshDir("tree-d")
    writeTree(a, {"x.nim": "one"})
    writeTree(b, {"x.nim": "onE"})
    check treeHash(a).get != treeHash(b).get

  test "Given a file renamed, When tree-hashed, Then the hash differs":
    let a = freshDir("tree-e")
    let b = freshDir("tree-f")
    writeTree(a, {"x.nim": "one"})
    writeTree(b, {"y.nim": "one"})
    check treeHash(a).get != treeHash(b).get

  test "Given a skipped directory, When its content changes, Then the hash does not":
    let a = freshDir("tree-g")
    let b = freshDir("tree-h")
    writeTree(a, {"x.nim": "one", "build/o": "1", "sub/build/p": "1"})
    writeTree(b, {"x.nim": "one", "build/o": "2", "sub/build/p": "2"})
    check treeHash(a, ["build"]).get == treeHash(b, ["build"]).get
    check treeHash(a).get != treeHash(b).get

  test "Given a directory that does not exist, When tree-hashed, Then an io error is returned":
    let r = treeHash(getTempDir() / "niuv-test-no-such-dir")
    check r.isErr
    check r.error.kind == ekIo

# ---- lock content, staleness and tool pins -------------------------------

proc pkgToml(name: string, extra = ""): string =
  "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n" & extra

proc makeWorkspace(dir: string): Workspace =
  ## A workspace of `app` (depends on `lib` and the external `ext`) and `lib`.
  writeTree(dir, {
    "app/niuv.toml": pkgToml("app", "\n[nim]\n[[nim.bin]]\nname = \"run\"\nmain = \"child/run.nim\"\n" &
      "[dependencies]\nworkspace = [\"lib\"]\n[dependencies.external.ext]\nsource = \"github.com/a/ext\"\nversion = \"1.2.3\"\n"),
    "app/src/app.nim": "discard",
    "app/child/run.nim": "discard",
    "app/tests/ignored.nim": "discard",
    "lib/niuv.toml": pkgToml("lib", "\n[nim]\n"),
    "lib/src/lib.nim": "discard",
    "ext/githubcom_aext_123/ext.nim": "discard",
    "niuv.workspace.toml": "[workspace]\nmembers = [\"app\", \"lib\"]\n[external]\nroots = [\"ext\"]\n"})
  loadWorkspace(dir / "niuv.workspace.toml").get

const nimTool = ToolInfo(name: "nim", version: "2.2.12", exe: "/x/nim", sha256: "aa")

suite "NIV-11 lock content":
  test "Given a workspace, When locked, Then packages externals and tools are recorded":
    let d = freshDir("lock-content")
    let ws = makeWorkspace(d)
    let l = buildLock(ws, @[nimTool])
    check l.isOk
    check l.get.tools == @[LockedTool(name: "nim", version: "2.2.12", sha256: "aa")]
    check l.get.packages.mapIt(it.name) == @["app", "lib"]
    check l.get.packages[0].path == "app"
    check l.get.packages[0].sha256.len == 64
    check l.get.externals.len == 1
    check l.get.externals[0].name == "ext"
    check l.get.externals[0].source == "github.com/a/ext"
    check l.get.externals[0].version == "1.2.3"
    check l.get.externals[0].sha256 == treeHash(d / "ext" / "githubcom_aext_123", [".git", ".jj"]).get

  test "Given the same workspace locked twice, When rendered, Then the bytes are equal":
    let d = freshDir("lock-twice")
    let ws = makeWorkspace(d)
    check renderLock(buildLock(ws, @[nimTool]).get) == renderLock(buildLock(ws, @[nimTool]).get)

  test "Given a rendered lock, When parsed and rendered again, Then the bytes are equal":
    let d = freshDir("lock-roundtrip")
    let text = renderLock(buildLock(makeWorkspace(d), @[nimTool]).get)
    let again = parseLock(text, "niuv.lock")
    check again.isOk
    check renderLock(again.get) == text

  test "Given a file outside the declared sources, When it changes, Then the package hash does not":
    let d = freshDir("lock-outside")
    let ws = makeWorkspace(d)
    let before = buildLock(ws, @[nimTool]).get
    writeFile(d / "app" / "tests" / "ignored.nim", "changed")
    check buildLock(ws, @[nimTool]).get.packages[0].sha256 == before.packages[0].sha256

  test "Given a source file, When it changes, Then the package hash changes":
    let d = freshDir("lock-src")
    let ws = makeWorkspace(d)
    let before = buildLock(ws, @[nimTool]).get
    writeFile(d / "app" / "src" / "app.nim", "changed")
    check buildLock(ws, @[nimTool]).get.packages[0].sha256 != before.packages[0].sha256

  test "Given the declaration, When it changes, Then the package hash changes":
    let d = freshDir("lock-decl")
    let before = buildLock(makeWorkspace(d), @[nimTool]).get
    let f = d / "lib" / "niuv.toml"
    writeFile(f, readFile(f) & "flags = [\"-d:release\"]\n")
    check buildLock(loadWorkspace(d / "niuv.workspace.toml").get, @[nimTool]).get.packages[1].sha256 !=
          before.packages[1].sha256

  test "Given a main beside siblings in its directory, When a sibling changes, Then the package hash changes":
    let d = freshDir("lock-sibling")
    discard makeWorkspace(d)
    writeFile(d / "app" / "child" / "helper.nim", "one")
    let before = buildLock(loadWorkspace(d / "niuv.workspace.toml").get, @[nimTool]).get
    writeFile(d / "app" / "child" / "helper.nim", "two")
    check buildLock(loadWorkspace(d / "niuv.workspace.toml").get, @[nimTool]).get.packages[0].sha256 !=
          before.packages[0].sha256

  test "Given two members that pin one external name two ways, When locked, Then it is refused naming both pins":
    let d = freshDir("lock-two-pins")
    writeTree(d, {
      "one/niuv.toml": pkgToml("one", "\n[dependencies.external.ext]\nsource = \"github.com/a/ext\"\nversion = \"1.2.3\"\n"),
      "two/niuv.toml": pkgToml("two", "\n[dependencies.external.ext]\nsource = \"github.com/a/ext\"\nversion = \"1.2.4\"\n"),
      "ext/githubcom_aext_123/ext.nim": "discard",
      "ext/githubcom_aext_124/ext.nim": "discard",
      "niuv.workspace.toml": "[workspace]\nmembers = [\"one\", \"two\"]\n[external]\nroots = [\"ext\"]\n"})
    let ws = loadWorkspace(d / "niuv.workspace.toml").get
    let l = buildLock(ws, @[nimTool])
    check l.isErr
    check l.error.kind == ekConflict
    check "1.2.3" in l.error.msg and "1.2.4" in l.error.msg

  test "Given a lock with a key niuv does not know, When parsed, Then it is refused":
    let d = freshDir("lock-unknown")
    let text = renderLock(buildLock(makeWorkspace(d), @[nimTool]).get) & "surprise = 1\n"
    check parseLock(text, "niuv.lock").isErr

  test "Given a lock of another version, When parsed, Then it is refused":
    let r = parseLock("lock-version = 99\n", "niuv.lock")
    check r.isErr
    check r.error.kind == ekLock

suite "NIV-12 stale lock":
  test "Given no niuv.lock, When read, Then it is refused asking for niuv lock":
    let d = freshDir("stale-none")
    let ws = makeWorkspace(d)
    let r = readLock(ws)
    check r.isErr
    check r.error.kind == ekLock
    check "niuv lock" in r.error.msg

  test "Given a written lock, When read back, Then it equals what was written":
    let d = freshDir("stale-write")
    let ws = makeWorkspace(d)
    let l = buildLock(ws, @[nimTool]).get
    check writeLock(ws, l).isOk
    check readLock(ws).get == l

  test "Given a fresh lock, When checked against the closure, Then it passes":
    let d = freshDir("stale-fresh")
    let ws = makeWorkspace(d)
    let l = buildLock(ws, @[nimTool]).get
    check checkLock(l, ws, resolveClosure(ws, "app").get).isOk

  test "Given a source changed after locking, When checked, Then it is refused naming the package":
    let d = freshDir("stale-src")
    let ws = makeWorkspace(d)
    let l = buildLock(ws, @[nimTool]).get
    writeFile(d / "lib" / "src" / "lib.nim", "changed")
    let r = checkLock(l, ws, resolveClosure(ws, "app").get)
    check r.isErr
    check r.error.kind == ekLock
    check "lib" in r.error.msg
    check "niuv lock" in r.error.msg

  test "Given an external changed after locking, When checked, Then it is refused naming it":
    let d = freshDir("stale-ext")
    let ws = makeWorkspace(d)
    let l = buildLock(ws, @[nimTool]).get
    writeFile(d / "ext" / "githubcom_aext_123" / "ext.nim", "changed")
    let r = checkLock(l, ws, resolveClosure(ws, "app").get)
    check r.isErr
    check "ext" in r.error.msg

  test "Given a package missing from the lock, When checked, Then it is refused":
    let d = freshDir("stale-missing")
    let ws = makeWorkspace(d)
    var l = buildLock(ws, @[nimTool]).get
    l.packages.delete(1)
    let r = checkLock(l, ws, resolveClosure(ws, "app").get)
    check r.isErr
    check "lib" in r.error.msg

  test "Given a package that moved, When checked, Then it is refused":
    let d = freshDir("stale-moved")
    let ws = makeWorkspace(d)
    var l = buildLock(ws, @[nimTool]).get
    l.packages[1].path = "elsewhere/lib"
    check checkLock(l, ws, resolveClosure(ws, "app").get).isErr

  test "Given an external pinned at another version, When checked, Then it is refused":
    let d = freshDir("stale-pin")
    let ws = makeWorkspace(d)
    var l = buildLock(ws, @[nimTool]).get
    l.externals[0].version = "9.9.9"
    check checkLock(l, ws, resolveClosure(ws, "app").get).isErr

proc firstLine(cmd: string, args: openArray[string]): string =
  let (o, _) = execCmdEx(cmd & " " & args.join(" "))
  o.splitLines()[0]

suite "NIV-13 tool pin":
  test "Given the nim on PATH, When probed with its own version, Then exe and SHA-256 are recorded":
    let line = firstLine("nim", ["--version"])
    let version = line.split("Version ")[1].split(' ')[0]
    let t = probeTool(ToolSpec(name: "nim", version: version, via: ""))
    check t.isOk
    check t.get.version == version
    check t.get.sha256 == sha256File(t.get.exe).get
    check t.get.exe.isAbsolute

  test "Given a version the tool does not have, When probed, Then it is refused naming both":
    let t = probeTool(ToolSpec(name: "nim", version: "0.0.1", via: ""))
    check t.isErr
    check t.error.kind == ekTool
    check "0.0.1" in t.error.msg

  test "Given a tool pinned in the lock, When the actual version differs, Then the check refuses":
    let locked = Lock(tools: @[LockedTool(name: "nim", version: "2.2.12", sha256: "aa")])
    let r = checkTools(locked, @[ToolInfo(name: "nim", version: "2.2.13", exe: "/x", sha256: "aa")])
    check r.isErr
    check r.error.kind == ekTool
    check "2.2.12" in r.error.msg and "2.2.13" in r.error.msg

  test "Given a tool pinned in the lock, When the executable's SHA-256 differs, Then the check refuses":
    let locked = Lock(tools: @[LockedTool(name: "nim", version: "2.2.12", sha256: "aa")])
    let r = checkTools(locked, @[ToolInfo(name: "nim", version: "2.2.12", exe: "/x", sha256: "bb")])
    check r.isErr
    check r.error.kind == ekTool
    check "SHA-256" in r.error.msg

  test "Given a needed tool the lock does not pin, When checked, Then it is refused":
    let r = checkTools(Lock(), @[ToolInfo(name: "nim", version: "2.2.12", exe: "/x", sha256: "aa")])
    check r.isErr
    check r.error.kind == ekTool

  test "Given matching tools, When checked, Then it passes":
    let locked = Lock(tools: @[LockedTool(name: "nim", version: "2.2.12", sha256: "aa")])
    check checkTools(locked, @[ToolInfo(name: "nim", version: "2.2.12", exe: "/x", sha256: "aa")]).isOk

  test "Given a tool that is not on PATH, When probed, Then it is refused naming the tool":
    let saved = getEnv("PATH")
    putEnv("PATH", freshDir("empty-path"))
    let t = probeTool(ToolSpec(name: "nim", version: "2.2.12", via: ""))
    putEnv("PATH", saved)
    check t.isErr
    check t.error.kind == ekTool
    check "nim" in t.error.msg

const
  digest = "sha256:" & "ab".repeat(32)
  image = "niuv/builder@" & digest
  linux = "aarch64-linux-musl"

suite "NIV-25 one lock per target":
  test "Given no target, When the lock is placed, Then it is niuv.lock next to the workspace file":
    let d = freshDir("lock-t-none")
    let ws = makeWorkspace(d)
    check lockPath(ws) == d / "niuv.lock"
    check lockFileName("") == "niuv.lock"

  test "Given a target, When the lock is placed, Then it is niuv.<target>.lock":
    let d = freshDir("lock-t-named")
    let ws = makeWorkspace(d)
    check lockPath(ws, linux) == d / "niuv.aarch64-linux-musl.lock"

  test "Given locks written for two targets, When read, Then each file holds its own tools":
    let d = freshDir("lock-t-two")
    let ws = makeWorkspace(d)
    let a = buildLock(ws, @[nimTool]).get
    let b = buildLock(ws, @[ToolInfo(name: "nim", version: "2.2.12", exe: "/y/nim", sha256: "bb")]).get
    check writeLock(ws, a).isOk
    check writeLock(ws, b, linux).isOk
    check readLock(ws).get.tools[0].sha256 == "aa"
    check readLock(ws, linux).get.tools[0].sha256 == "bb"

  test "Given the same workspace locked for two targets, When compared, Then packages and externals are equal":
    let d = freshDir("lock-t-same")
    let ws = makeWorkspace(d)
    let a = buildLock(ws, @[nimTool]).get
    let b = buildLock(ws, @[ToolInfo(name: "nim", version: "2.2.12", exe: "/y/nim", sha256: "bb")]).get
    check a.packages == b.packages
    check a.externals == b.externals
    check a.tools != b.tools

  test "Given a target without a lock file, When read, Then it is refused naming that file":
    let d = freshDir("lock-t-missing")
    let ws = makeWorkspace(d)
    check writeLock(ws, buildLock(ws, @[nimTool]).get).isOk
    let r = readLock(ws, linux)
    check r.isErr
    check "niuv.aarch64-linux-musl.lock" in r.error.msg

  test "Given a stale target lock, When checked, Then the message names the target's lock and its command":
    let d = freshDir("lock-t-stale")
    let ws = makeWorkspace(d)
    let l = buildLock(ws, @[nimTool]).get
    writeFile(d / "lib" / "src" / "lib.nim", "echo 1")
    let r = checkLock(l, ws, resolveClosure(ws, "app").get, linux)
    check r.isErr
    check "niuv lock --target " & linux in r.error.msg

  test "Given a tool the target's lock does not pin, When checked, Then the message names that lock":
    let l = Lock()
    let r = checkTools(l, @[nimTool], linux)
    check r.isErr
    check "niuv.aarch64-linux-musl.lock" in r.error.msg

suite "NIV-26 builder image":
  test "Given an image by digest with a slash in its name, When checked, Then it is accepted":
    check checkBuilderImage(image).get.image == image

  test "Given a tag instead of a digest, When checked, Then it is refused":
    for s in ["niuv/builder:latest", "niuv/builder", "niuv/builder:1@" & digest, "niuv/builder@latest"]:
      check checkBuilderImage(s).isErr

  test "Given a name without a slash, When checked, Then it is refused":
    check checkBuilderImage("builder@" & digest).isErr
    check checkBuilderImage("/builder@" & digest).isErr

  test "Given a digest that is not 64 lowercase hex, When checked, Then it is refused":
    check checkBuilderImage("niuv/builder@sha256:" & "ab".repeat(31)).isErr
    check checkBuilderImage("niuv/builder@sha256:" & "AB".repeat(32)).isErr
    check checkBuilderImage("niuv/builder@sha512:" & "ab".repeat(32)).isErr

  test "Given a lock with a builder, When rendered, parsed and rendered, Then the bytes are equal":
    let d = freshDir("lock-b-roundtrip")
    let ws = makeWorkspace(d)
    let l = buildLock(ws, @[nimTool], some(LockedBuilder(image: image))).get
    let text = renderLock(l)
    check "[builder]\nimage = \"" & image & "\"" in text
    let back = parseLock(text, "x.lock")
    check back.isOk
    check back.get.builder.get.image == image
    check renderLock(back.get) == text

  test "Given a lock without a builder, When rendered, Then there is no [builder] table":
    let d = freshDir("lock-b-none")
    let ws = makeWorkspace(d)
    check "[builder]" notin renderLock(buildLock(ws, @[nimTool]).get)

  test "Given a lock whose builder is a tag, When parsed, Then it is refused":
    let text = "lock-version = 1\n[builder]\nimage = \"niuv/builder:latest\"\n"
    let r = parseLock(text, "x.lock")
    check r.isErr
    check "builder" in r.error.msg

  test "Given a builder table with another key, When parsed, Then it is refused":
    let text = "lock-version = 1\n[builder]\nimage = \"" & image & "\"\nsignature = \"x\"\n"
    check parseLock(text, "x.lock").isErr
