## E tests for resolution: NIV-08 (closure) and NIV-09 (two versions of one name).

import std/[os, sequtils, strutils, unittest]
import ../../src/niuv/[decl, errors, resolve, workspace]
import support

const testFile* = "tests/unit/test_resolve.nim"

proc pkg(name: string, deps: openArray[string] = [], externals = ""): PackageDecl =
  var text = "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n[nim]\n"
  if deps.len > 0 or externals.len > 0:
    text.add "[dependencies]\n"
    if deps.len > 0:
      text.add "workspace = [" & deps.mapIt("\"" & it & "\"").join(", ") & "]\n"
    text.add externals
  parseDeclText(text, "niuv.toml", "/w/" & name).get

proc ws(pkgs: seq[PackageDecl], roots: seq[string] = @[]): Workspace =
  Workspace(file: "/w/niuv.workspace.toml", dir: "/w", packages: pkgs, externalRoots: roots)

proc extDecl(name, source, version: string): string =
  "[dependencies.external." & name & "]\nsource = \"" & source & "\"\nversion = \"" & version & "\"\n"

suite "NIV-08 closure":
  test "Given a chain a -> b -> c, When resolved from a, Then the order is dependencies first":
    let w = ws(@[pkg("a", ["b"]), pkg("b", ["c"]), pkg("c")])
    let c = resolveClosure(w, "a")
    check c.isOk
    check c.get.packages.mapIt(it.name) == @["c", "b", "a"]
    check c.get.root == "a"

  test "Given a diamond, When resolved, Then each package appears once and siblings are in name order":
    let w = ws(@[pkg("top", ["z", "m"]), pkg("z", ["base"]), pkg("m", ["base"]), pkg("base")])
    let c = resolveClosure(w, "top")
    check c.get.packages.mapIt(it.name) == @["base", "m", "z", "top"]

  test "Given packages outside the closure, When resolved, Then they are left out":
    let w = ws(@[pkg("a", ["b"]), pkg("b"), pkg("stray")])
    check resolveClosure(w, "a").get.packages.mapIt(it.name) == @["b", "a"]

  test "Given the declaration order changes, When resolved, Then the closure is the same":
    let a = resolveClosure(ws(@[pkg("a", ["b", "c"]), pkg("b"), pkg("c")]), "a").get
    let b = resolveClosure(ws(@[pkg("c"), pkg("b"), pkg("a", ["c", "b"])]), "a").get
    check a.packages.mapIt(it.name) == b.packages.mapIt(it.name)

  test "Given a dependency name the workspace lacks, When resolved, Then it is refused naming it and its asker":
    let r = resolveClosure(ws(@[pkg("a", ["ghost"])]), "a")
    check r.isErr
    check r.error.kind == ekResolve
    check "ghost" in r.error.msg
    check "a" in r.error.msg

  test "Given an unknown root, When resolved, Then it is refused":
    let r = resolveClosure(ws(@[pkg("a")]), "nope")
    check r.isErr
    check r.error.kind == ekResolve

  test "Given a cycle a -> b -> a, When resolved, Then it is refused showing the path":
    let r = resolveClosure(ws(@[pkg("a", ["b"]), pkg("b", ["a"])]), "a")
    check r.isErr
    check r.error.kind == ekResolve
    check "a -> b -> a" in r.error.msg

  test "Given a package depending on itself, When resolved, Then it is refused":
    check resolveClosure(ws(@[pkg("a", ["a"])]), "a").isErr

  test "Given an external found in a root, When resolved, Then its directory is returned":
    let root = freshDir("res-ext")
    createDir(root / "githubcom_statusimnimbearssl_0213")
    let w = ws(@[pkg("a", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.13"))], @[root])
    let c = resolveClosure(w, "a")
    check c.isOk
    check c.get.externals.len == 1
    check c.get.externals[0].name == "bearssl"
    check c.get.externals[0].dir == root / "githubcom_statusimnimbearssl_0213"

  test "Given an external in the pkgs2 form name-version-hash, When resolved, Then it is found":
    let root = freshDir("res-pkgs2")
    createDir(root / "results-0.5.1-a9c011f74bc9ed5c91103917b9f382b12e82a9e7")
    createDir(root / "results-0.5.10-ffffffffffffffffffffffffffffffffffffffff")
    let w = ws(@[pkg("a", [], extDecl("results", "github.com/arnetheduck/nim-results", "0.5.1"))], @[root])
    let c = resolveClosure(w, "a")
    check c.isOk
    check c.get.externals[0].dir == root / "results-0.5.1-a9c011f74bc9ed5c91103917b9f382b12e82a9e7"

  test "Given an external found in no root, When resolved, Then the roots and expected names are shown":
    let root = freshDir("res-miss")
    let w = ws(@[pkg("a", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.13"))], @[root])
    let r = resolveClosure(w, "a")
    check r.isErr
    check r.error.kind == ekResolve
    check root in r.error.msg
    check "githubcom_statusimnimbearssl_0213" in r.error.msg
    check "bearssl-0.2.13-" in r.error.msg

  test "Given the same version in the pkgs2 form twice, When resolved, Then it is refused as ambiguous":
    let root = freshDir("res-amb")
    createDir(root / "r-1.0.0-aaaa")
    createDir(root / "r-1.0.0-bbbb")
    let w = ws(@[pkg("a", [], extDecl("r", "github.com/x/r", "1.0.0"))], @[root])
    let r = resolveClosure(w, "a")
    check r.isErr
    check "ambiguous" in r.error.msg

  test "Given two roots holding the dependency, When resolved, Then the first root wins":
    let r1 = freshDir("res-first")
    let r2 = freshDir("res-second")
    createDir(r1 / "r-1.0.0-aaaa")
    createDir(r2 / "r-1.0.0-bbbb")
    let w = ws(@[pkg("a", [], extDecl("r", "github.com/x/r", "1.0.0"))], @[r1, r2])
    check resolveClosure(w, "a").get.externals[0].dir == r1 / "r-1.0.0-aaaa"

suite "NIV-09 two versions of one name":
  proc findable(): seq[string] =
    let root = freshDir("conf-roots")
    createDir(root / "githubcom_statusimnimbearssl_026")
    createDir(root / "githubcom_statusimnimbearssl_0213")
    @[root]

  test "Given BearSSL 0.2.6 and 0.2.13 in one closure, When resolved, Then it is refused naming both askers":
    let w = ws(@[
      pkg("app", ["store", "keeper"]),
      pkg("store", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.13")),
      pkg("keeper", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.6"))], findable())
    let r = resolveClosure(w, "app")
    check r.isErr
    check r.error.kind == ekConflict
    check "bearssl" in r.error.msg
    check "0.2.6" in r.error.msg and "0.2.13" in r.error.msg
    check "keeper" in r.error.msg and "store" in r.error.msg

  test "Given the same version asked twice, When resolved, Then there is one entry":
    let w = ws(@[
      pkg("app", ["store", "keeper"]),
      pkg("store", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.13")),
      pkg("keeper", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.13"))], findable())
    let c = resolveClosure(w, "app")
    check c.isOk
    check c.get.externals.len == 1

  test "Given one name from two sources, When resolved, Then it is refused":
    let w = ws(@[
      pkg("app", ["x", "y"]),
      pkg("x", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.13")),
      pkg("y", [], extDecl("bearssl", "github.com/someone/fork", "0.2.13"))], findable())
    let r = resolveClosure(w, "app")
    check r.isErr
    check r.error.kind == ekConflict

  test "Given source spellings that differ only by scheme and .git, When resolved, Then they are the same source":
    let w = ws(@[
      pkg("app", ["x", "y"]),
      pkg("x", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.13")),
      pkg("y", [], extDecl("bearssl", "https://github.com/status-im/nim-bearssl.git", "0.2.13"))], findable())
    check resolveClosure(w, "app").isOk

  test "Given the conflict is outside the closure, When resolved, Then it does not matter":
    let w = ws(@[
      pkg("app", ["store"]),
      pkg("store", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.13")),
      pkg("other", [], extDecl("bearssl", "github.com/status-im/nim-bearssl", "0.2.6"))], findable())
    check resolveClosure(w, "app").isOk
