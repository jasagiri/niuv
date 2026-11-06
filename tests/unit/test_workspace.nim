## E tests for the workspace niuv.workspace.toml: NIV-07.

import std/[options, os, strutils, unittest]
import ../../src/niuv/[decl, errors, workspace]
import support

const testFile* = "tests/unit/test_workspace.nim"

proc pkgToml(name: string, extra = ""): string =
  "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n" & extra

proc wsFile(root, body: string): string =
  writeTree(root, {"niuv.workspace.toml": body})
  root / "niuv.workspace.toml"

suite "NIV-07 workspace":
  test "Given two members, When loaded, Then the name table points to their directories":
    let d = freshDir("ws-two")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha"), "deep/b/niuv.toml": pkgToml("beta")})
    let ws = loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\", \"deep/b\"]\n"))
    check ws.isOk
    check ws.get.packages.len == 2
    check ws.get.find("alpha").get.declDir == d / "a"
    check ws.get.find("beta").get.declDir == d / "deep" / "b"
    check ws.get.find("gamma").isNone

  test "Given two members with one name, When loaded, Then it is refused naming both":
    let d = freshDir("ws-dup")
    writeTree(d, {"a/niuv.toml": pkgToml("same"), "b/niuv.toml": pkgToml("same")})
    let ws = loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\", \"b\"]\n"))
    check ws.isErr
    check ws.error.kind == ekWorkspace
    check "same" in ws.error.msg
    check "a" in ws.error.msg and "b" in ws.error.msg

  test "Given a member directory without niuv.toml, When loaded, Then it is refused":
    let d = freshDir("ws-nodecl")
    createDir(d / "a")
    let ws = loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\"]\n"))
    check ws.isErr
    check ws.error.kind == ekWorkspace

  test "Given a member with an invalid declaration, When loaded, Then the declaration error is returned":
    let d = freshDir("ws-baddecl")
    writeTree(d, {"a/niuv.toml": "[package]\nname = \"a\"\n"})
    let ws = loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\"]\n"))
    check ws.isErr
    check ws.error.kind == ekDecl
    check "niuv.toml" in ws.error.msg

  test "Given the same directory listed twice, When loaded, Then it is refused":
    let d = freshDir("ws-twice")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha")})
    let ws = loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\", \"./a\"]\n"))
    check ws.isErr

  test "Given a declaration that points at a root, When loaded, Then the package root is that directory":
    let d = freshDir("ws-root")
    writeTree(d, {"decls/a/niuv.toml": pkgToml("alpha", "").replace("license", "root = \"../../src/a\"\nlicense"),
                  "src/a/x.nim": "discard"})
    let ws = loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"decls/a\"]\n"))
    check ws.isOk
    check ws.get.find("alpha").get.root == d / "src" / "a"

  test "Given a nim bin whose main is missing, When loaded, Then it is refused naming the file":
    let d = freshDir("ws-nomain")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha", "\n[nim]\n[[nim.bin]]\nname = \"x\"\nmain = \"x.nim\"\n"),
                  "a/src/lib.nim": "discard"})
    let ws = loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\"]\n"))
    check ws.isErr
    check ws.error.kind == ekWorkspace
    check "x.nim" in ws.error.msg

  test "Given a nim table whose src directory is missing, When loaded, Then it is refused":
    let d = freshDir("ws-nosrc")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha", "\n[nim]\nsrc = \"lib\"\n")})
    check loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\"]\n")).isErr

  test "Given a gleam root without gleam.toml, When loaded, Then it is refused":
    let d = freshDir("ws-nogleam")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha", "\n[gleam]\n")})
    check loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\"]\n")).isErr

  test "Given a wasm component whose entry, wit or path is missing, When loaded, Then it is refused naming it (NIV-50)":
    let comp = "\n[[wasm.component]]\nname = \"p\"\nentry = \"g/main.nim\"\nwit = \"wit\"\nworld = \"a:b/c\"\nexport = [\"run\"]\n"
    let full = {"a/g/main.nim": "discard", "a/wit/p.wit": "package a:b;"}
    for (what, missing) in [("entry", "a/g/main.nim"), ("wit", "a/wit/p.wit")]:
      let d = freshDir("ws-nowasm-" & what)
      writeTree(d, {"a/niuv.toml": pkgToml("alpha", comp)})
      for (rel, content) in full:
        if rel != missing: writeTree(d, {rel: content})
      let ws = loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\"]\n"))
      check ws.isErr
      check ws.error.kind == ekWorkspace
      check "'p'" in ws.error.msg
    let d = freshDir("ws-nowasm-path")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha", comp & "paths = [\"sdk\"]\n"), "a/g/main.nim": "discard",
                  "a/wit/p.wit": "package a:b;"})
    check loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\"]\n")).isErr

  test "Given a wasm component path that leaves the workspace, When loaded, Then it is refused (NIV-50)":
    let d = freshDir("ws-wasm-outside")
    writeTree(d / "w", {"a/niuv.toml": pkgToml("alpha",
      "\n[[wasm.component]]\nname = \"p\"\nentry = \"g/main.nim\"\nwit = \"wit\"\nworld = \"a:b/c\"\n" &
      "export = [\"run\"]\npaths = [\"../../../sdk\"]\n"),
      "a/g/main.nim": "discard", "a/wit/p.wit": "package a:b;"})
    let ws = loadWorkspace(wsFile(d / "w", "[workspace]\nmembers = [\"a\"]\n"))
    check ws.isErr
    check "leaves the workspace" in ws.error.msg

  test "Given a wasm component path in a sibling directory of the package inside the workspace, When loaded, Then it is accepted":
    let d = freshDir("ws-wasm-sibling")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha",
      "\n[[wasm.component]]\nname = \"p\"\nentry = \"g/main.nim\"\nwit = \"wit\"\nworld = \"a:b/c\"\n" &
      "export = [\"run\"]\npaths = [\"../sdk/src\"]\n"),
      "a/g/main.nim": "discard", "a/wit/p.wit": "package a:b;", "sdk/src/x.nim": "discard"})
    check loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\"]\n")).isOk

  test "Given tool pins, When loaded, Then they are read":
    let d = freshDir("ws-tools")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha")})
    let ws = loadWorkspace(wsFile(d,
      "[workspace]\nmembers = [\"a\"]\n[tools.nim]\nversion = \"2.2.12\"\nvia = \"mise\"\n[tools.gleam]\nversion = \"1.19.1\"\n"))
    check ws.isOk
    check ws.get.tool("nim").get.version == "2.2.12"
    check ws.get.tool("nim").get.via == "mise"
    check ws.get.tool("gleam").get.via == ""
    check ws.get.tool("erlang").isNone

  test "Given a tool niuv does not drive, When loaded, Then it is refused":
    let d = freshDir("ws-badtool")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha")})
    check loadWorkspace(wsFile(d,
      "[workspace]\nmembers = [\"a\"]\n[tools.rustc]\nversion = \"1.0.0\"\n")).isErr

  test "Given a tool version that is not exact, When loaded, Then it is refused":
    let d = freshDir("ws-toolrange")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha")})
    let ws = loadWorkspace(wsFile(d,
      "[workspace]\nmembers = [\"a\"]\n[tools.nim]\nversion = \">= 2.0.0\"\n"))
    check ws.isErr
    check ws.error.kind == ekRange

  test "Given external roots with a variable, When loaded, Then the variable is expanded":
    let d = freshDir("ws-roots")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha")})
    putEnv("NIUV_TEST_ROOT", "/opt/ext")
    let ws = loadWorkspace(wsFile(d,
      "[workspace]\nmembers = [\"a\"]\n[external]\nroots = [\"$NIUV_TEST_ROOT/pkgs\", \"rel/dir\"]\n"))
    check ws.isOk
    check ws.get.externalRoots == @["/opt/ext/pkgs", d / "rel" / "dir"]

  test "Given an unset variable in a root, When loaded, Then it is refused":
    let d = freshDir("ws-unset")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha")})
    delEnv("NIUV_TEST_UNSET")
    check loadWorkspace(wsFile(d,
      "[workspace]\nmembers = [\"a\"]\n[external]\nroots = [\"$NIUV_TEST_UNSET/x\"]\n")).isErr

  test "Given an unknown key, When loaded, Then it is refused":
    let d = freshDir("ws-unknown")
    writeTree(d, {"a/niuv.toml": pkgToml("alpha")})
    check loadWorkspace(wsFile(d, "[workspace]\nmembers = [\"a\"]\nextra = 1\n")).isErr

  test "Given no members, When loaded, Then it is refused":
    let d = freshDir("ws-empty")
    check loadWorkspace(wsFile(d, "[workspace]\nmembers = []\n")).isErr
