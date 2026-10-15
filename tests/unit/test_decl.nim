## E tests for the declaration niuv.toml: NIV-01 .. NIV-06 and NIV-10.

import std/[strutils, unittest]
import ../../src/niuv/[decl, errors]

const testFile* = "tests/unit/test_decl.nim"

const Minimal = """
[package]
name = "demo"
version = "0.1.0"
license = "Apache-2.0"
"""

proc parsed(text: string, dir = "/w/demo"): NResult[PackageDecl] =
  parseDeclText(text, "niuv.toml", dir)

suite "NIV-01 package table":
  test "Given the three required keys, When parsed, Then name version license are read":
    let d = parsed(Minimal)
    check d.isOk
    check d.get.name == "demo"
    check d.get.version == "0.1.0"
    check d.get.license == "Apache-2.0"

  test "Given a missing license, When parsed, Then it is refused naming the key and the file":
    let d = parsed("[package]\nname = \"demo\"\nversion = \"0.1.0\"\n")
    check d.isErr
    check d.error.kind == ekDecl
    check "license" in d.error.msg
    check "niuv.toml" in d.error.msg

  test "Given no package table, When parsed, Then it is refused":
    check parsed("[nim]\n").isErr

  test "Given a name with a space or a slash, When parsed, Then it is refused":
    check parsed(Minimal.replace("demo", "de mo")).isErr
    check parsed(Minimal.replace("demo", "de/mo")).isErr

  test "Given a version that is not x.y.z, When parsed, Then it is refused":
    check parsed(Minimal.replace("0.1.0", "0.1")).isErr
    check parsed(Minimal.replace("0.1.0", "v0.1.0")).isErr

  test "Given an empty license, When parsed, Then it is refused":
    check parsed(Minimal.replace("Apache-2.0", "")).isErr

  test "Given an unknown key in package, When parsed, Then it is refused":
    let d = parsed(Minimal & "colour = \"red\"\n")
    check d.isErr
    check "colour" in d.error.msg

  test "Given an unknown top-level table, When parsed, Then it is refused":
    let d = parsed(Minimal & "\n[rust]\nx = 1\n")
    check d.isErr
    check "rust" in d.error.msg

  test "Given malformed TOML, When parsed, Then the parse error is returned with the file name":
    let d = parsed("[package\nname = ")
    check d.isErr
    check d.error.kind == ekDecl
    check "niuv.toml" in d.error.msg

  test "Given a wrong type, When parsed, Then it is refused naming the key":
    let d = parsed(Minimal.replace("\"demo\"", "3"))
    check d.isErr
    check "name" in d.error.msg

suite "NIV-02 nim table":
  test "Given an empty nim table, When parsed, Then src defaults to src":
    let d = parsed(Minimal & "\n[nim]\n")
    check d.isOk
    check d.get.nim.present
    check d.get.nim.src == "src"
    check d.get.nim.bins.len == 0

  test "Given no nim table, When parsed, Then nim is absent":
    check not parsed(Minimal).get.nim.present

  test "Given bins, When parsed, Then name main flags sealed are read in order":
    let d = parsed(Minimal & """

[nim]
src = "lib"
flags = ["--mm:orc", "--panics:on"]

[[nim.bin]]
name = "a_child"
main = "child/a.nim"
flags = ["-d:release"]
sealed = true

[[nim.bin]]
name = "b_child"
main = "child/b.nim"
""")
    check d.isOk
    let n = d.get.nim
    check n.src == "lib"
    check n.flags == @["--mm:orc", "--panics:on"]
    check n.bins.len == 2
    check n.bins[0].name == "a_child"
    check n.bins[0].main == "child/a.nim"
    check n.bins[0].flags == @["-d:release"]
    check n.bins[0].sealed
    check n.bins[1].name == "b_child"
    check not n.bins[1].sealed
    check n.bins[1].flags.len == 0

  test "Given two bins with one name, When parsed, Then it is refused":
    let d = parsed(Minimal & """

[nim]
[[nim.bin]]
name = "x"
main = "x.nim"
[[nim.bin]]
name = "x"
main = "y.nim"
""")
    check d.isErr
    check "x" in d.error.msg

  test "Given a bin without main, When parsed, Then it is refused":
    check parsed(Minimal & "\n[nim]\n[[nim.bin]]\nname = \"x\"\n").isErr

  test "Given flags that are not strings, When parsed, Then it is refused":
    check parsed(Minimal & "\n[nim]\nflags = [1]\n").isErr

  test "Given an unknown key in nim, When parsed, Then it is refused":
    check parsed(Minimal & "\n[nim]\nopt = \"speed\"\n").isErr

suite "NIV-03 gleam table":
  test "Given an empty gleam table, When parsed, Then root defaults to dot and sealed to false":
    let d = parsed(Minimal & "\n[gleam]\n")
    check d.isOk
    check d.get.gleam.present
    check d.get.gleam.root == "."
    check not d.get.gleam.sealed

  test "Given root and sealed, When parsed, Then they are read":
    let d = parsed(Minimal & "\n[gleam]\nroot = \"gleam/x\"\nsealed = true\n")
    check d.get.gleam.root == "gleam/x"
    check d.get.gleam.sealed

  test "Given an unknown key in gleam, When parsed, Then it is refused":
    check parsed(Minimal & "\n[gleam]\ntarget = \"erlang\"\n").isErr

suite "NIV-04 wasm table":
  test "Given an entry, When parsed, Then entry and sealed are read":
    let d = parsed(Minimal & "\n[wasm]\nentry = \"wasm/main.wat\"\nsealed = true\n")
    check d.isOk
    check d.get.wasm.present
    check d.get.wasm.entry == "wasm/main.wat"
    check d.get.wasm.sealed

  test "Given a wasm table without entry, When parsed, Then it is refused":
    check parsed(Minimal & "\n[wasm]\nsealed = true\n").isErr

  test "Given an unknown key in wasm, When parsed, Then it is refused":
    check parsed(Minimal & "\n[wasm]\nentry = \"a\"\nopt = 1\n").isErr

suite "NIV-05 dependencies":
  test "Given workspace names, When parsed, Then the names are read in order":
    let d = parsed(Minimal & "\n[dependencies]\nworkspace = [\"nim-hpke\", \"nim-secret\"]\n")
    check d.isOk
    check d.get.workspaceDeps == @["nim-hpke", "nim-secret"]

  test "Given an external dependency, When parsed, Then source version and src are read":
    let d = parsed(Minimal & """

[dependencies.external.bearssl]
source = "github.com/status-im/nim-bearssl"
version = "0.2.13"
src = "."
""")
    check d.isOk
    check d.get.externals.len == 1
    let e = d.get.externals[0]
    check e.name == "bearssl"
    check e.source == "github.com/status-im/nim-bearssl"
    check e.version == "0.2.13"
    check e.src == "."

  test "Given an external without src, When parsed, Then src defaults to dot":
    let d = parsed(Minimal & "\n[dependencies.external.r]\nsource = \"github.com/a/b\"\nversion = \"1.0.0\"\n")
    check d.get.externals[0].src == "."

  test "Given an external without source, When parsed, Then it is refused":
    check parsed(Minimal & "\n[dependencies.external.r]\nversion = \"1.0.0\"\n").isErr

  test "Given a source with a scheme and .git, When parsed, Then it is kept as written":
    let d = parsed(Minimal & "\n[dependencies.external.r]\nsource = \"https://github.com/a/b.git\"\nversion = \"1.0.0\"\n")
    check d.get.externals[0].source == "https://github.com/a/b.git"

  test "Given an unknown key in dependencies, When parsed, Then it is refused":
    check parsed(Minimal & "\n[dependencies]\nnimble = [\"x\"]\n").isErr

suite "NIV-06 package root":
  test "Given no root, When parsed, Then the root is the declaration directory":
    let d = parsed(Minimal, "/w/demo")
    check d.get.root == "/w/demo"
    check d.get.declDir == "/w/demo"

  test "Given a relative root, When parsed, Then it is resolved from the declaration directory":
    let d = parsed(Minimal.replace("license =", "root = \"../../src/pkg\"\nlicense ="), "/w/decls/demo")
    check d.get.root == "/w/src/pkg"
    check d.get.declDir == "/w/decls/demo"

  test "Given a root, When the path helpers run, Then src and main are counted from the root":
    let d = parsed(Minimal.replace("license =", "root = \"/x/pkg\"\nlicense =") & """

[nim]
src = "src"
[[nim.bin]]
name = "c"
main = "child/c.nim"
""")
    check d.get.nimSrcDir == "/x/pkg/src"
    check d.get.inRoot(d.get.nim.bins[0].main) == "/x/pkg/child/c.nim"

suite "NIV-10 no version ranges":
  proc ext(version: string): NResult[PackageDecl] =
    parsed(Minimal & "\n[dependencies.external.r]\nsource = \"github.com/a/b\"\nversion = \"" &
           version & "\"\n")

  test "Given a range notation, When parsed, Then it is refused as a range":
    for v in [">= 0.2.13", "^0.2.13", "~0.2.13", "*", "0.2.13, 0.3.0", ">=0.1.0 <0.3.0", "0.2.x"]:
      let d = ext(v)
      check d.isErr
      check d.error.kind == ekRange

  test "Given a version that is not x.y.z and not a range, When parsed, Then it is refused":
    check ext("latest").isErr
    check ext("0.2").isErr

  test "Given an exact x.y.z, When parsed, Then it is accepted":
    check ext("0.2.13").isOk
