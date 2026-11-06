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

const
  Comp = "\n[[wasm.component]]\nname = \"probe\"\nentry = \"guest/main.nim\"\nwit = \"wit\"\n" &
         "world = \"niuv:probe/probe\"\nexport = [\"run\"]\n"

proc without(key: string): string =
  ## Comp with the line that starts with `key` left out.
  var o = ""
  for line in Comp.splitLines():
    if not line.startsWith(key & " "): o.add line & "\n"
  o

suite "NIV-49 wasm components":
  test "Given a component with every key, When parsed, Then each is read":
    let d = parsed(Minimal & Comp & "stack_size = 1048576\npaths = [\"../sdk/src\"]\nflags = [\"-d:x\"]\n" &
                   "no_simd = true\nsealed = true\n")
    check d.isOk
    check d.get.wasm.present
    let c = d.get.wasm.components[0]
    check c.name == "probe" and c.entry == "guest/main.nim" and c.wit == "wit"
    check c.world == "niuv:probe/probe" and c.exports == @["run"]
    check c.stackSize == 1048576 and c.paths == @["../sdk/src"] and c.flags == @["-d:x"]
    check c.noSimd and c.sealed

  test "Given only the required keys, When parsed, Then the stack is the default, SIMD is on and it is not sealed":
    let c = parsed(Minimal & Comp).get.wasm.components[0]
    check c.stackSize == 0 and not c.noSimd and not c.sealed and c.paths.len == 0

  test "Given a component without one of name, entry, wit, world or export, When parsed, Then it is refused naming the key":
    for key in ["name", "entry", "wit", "world", "export"]:
      let d = parsed(Minimal & without(key))
      check d.isErr
      check ("'" & key & "'") in d.error.msg

  test "Given a wasm table with no component, or the old entry key, When parsed, Then it is refused":
    check parsed(Minimal & "\n[wasm]\n").isErr
    check parsed(Minimal & "\n[wasm]\nentry = \"wasm/main.wat\"\n").isErr

  test "Given an unknown key in a component, When parsed, Then it is refused":
    check parsed(Minimal & Comp & "opt = 1\n").isErr

  test "Given two components of one name, or a component named like a nim bin, When parsed, Then it is refused":
    check parsed(Minimal & Comp & Comp).isErr
    check parsed(Minimal & "\n[nim]\n[[nim.bin]]\nname = \"probe\"\nmain = \"m.nim\"\n" & Comp).isErr

  test "Given a stack size outside 64 KiB..64 MiB, not a multiple of 16 or not a number, When parsed, Then it is refused":
    for v in ["1024", "67108880", "65537", "\"big\"", "-16"]:
      check parsed(Minimal & Comp & "stack_size = " & v & "\n").isErr

suite "NIV-50 component paths are relative":
  test "Given an absolute entry, wit or path, When parsed, Then it is refused":
    check parsed(Minimal & Comp.replace("guest/main.nim", "/etc/main.nim")).isErr
    check parsed(Minimal & Comp.replace("\"wit\"", "\"/wit\"")).isErr
    check parsed(Minimal & Comp & "paths = [\"/abs\"]\n").isErr

  test "Given a path that climbs out of the package, When parsed, Then it is accepted: the workspace decides":
    check parsed(Minimal & Comp & "paths = [\"../sdk/src\"]\n").isOk
