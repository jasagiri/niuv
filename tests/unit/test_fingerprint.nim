## E tests for the fingerprint of niuv's own sources: NIV-46.

import std/[os, strutils, unittest]
import ../../src/niuv/[cli, errors, fingerprint]
import support

const testFile* = "tests/unit/test_fingerprint.nim"

proc sourceTree(name: string): string =
  let d = freshDir(name)
  writeTree(d, {"src/niuv.nim": "echo 1\n", "src/niuv/wasm/start.c": "int x;\n", "nim.cfg": "--mm:orc\n",
                "src/niuv/notes.md": "not a source\n", "README.md": "not a source\n"})
  d

suite "NIV-46 the fingerprint of niuv's sources":
  test "Given the same files in any order, When fingerprinted, Then the fingerprint is the same, and differs when a name or a byte differs":
    let a = fingerprintOf(@[("src/a.nim", "x"), ("src/b.nim", "y")])
    check a == fingerprintOf(@[("src/b.nim", "y"), ("src/a.nim", "x")])
    check a != fingerprintOf(@[("src/a.nim", "x"), ("src/b.nim", "z")])
    check a != fingerprintOf(@[("src/a.nim", "x"), ("src/c.nim", "y")])
    check a != fingerprintOf(@[("src/a.nim", "xy"), ("src/b.nim", "")])
    check a.len == 64

  test "Given this test binary and the sources it was built from, When compared, Then they match":
    check freshness(BuildFingerprint, SourceRoot).get == frFresh
    check sourceFingerprint(SourceRoot).get == BuildFingerprint

  test "Given a source tree, When a source changes, Then it is stale, and files that are not sources do not count":
    let d = sourceTree("fp-tree")
    let built = sourceFingerprint(d).get
    check freshness(built, d).get == frFresh
    writeFile(d / "README.md", "changed\n")
    writeFile(d / "src" / "niuv" / "notes.md", "changed\n")
    check freshness(built, d).get == frFresh
    writeFile(d / "src" / "niuv" / "wasm" / "start.c", "int y;\n")
    check freshness(built, d).get == frStale
    check freshness(built, d / "absent").get == frNoSources

  test "Given a stale binary, When a command runs, Then it is refused with the rebuild command, but --version and --help still answer":
    let d = sourceTree("fp-stale")
    let built = sourceFingerprint(d).get
    writeFile(d / "nim.cfg", "--mm:arc\n")
    for args in [@["lock"], @["build", "app"], @["wasm", "x.nim"], @["child"]]:
      let r = runCli(args, built, d)
      check r.code == 1
      check "rebuild it: nim c" in r.stderr
    let v = runCli(@["--version"], built, d)
    check v.code == 0
    check built in v.stdout
    check "STALE" in v.stdout
    check runCli(@["--help"], built, d).code == 0

  test "Given a fresh binary, When --version runs, Then it prints the version and the fingerprint and says they match":
    let v = runCli(@["--version"])
    check v.code == 0
    check v.stdout.startsWith("niuv 0.")
    check BuildFingerprint in v.stdout
    check "matches the sources" in v.stdout
