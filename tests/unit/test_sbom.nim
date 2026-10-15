## E tests for the SBOM and the license gate: NIV-19, NIV-20.

import std/[json, os, strutils, unittest]
import ../../src/niuv/[decl, errors, resolve, sbom, workspace]
import support

const testFile* = "tests/unit/test_sbom.nim"

proc pkg(name, license: string, deps: openArray[string] = [], externals = "",
         extra = "[nim]\n"): PackageDecl =
  var text = "[package]\nname = \"" & name & "\"\nversion = \"1.0.0\"\nlicense = \"" & license & "\"\n" & extra
  if deps.len > 0 or externals.len > 0:
    text.add "[dependencies]\n"
    if deps.len > 0:
      var names: seq[string]
      for d in deps: names.add "\"" & d & "\""
      text.add "workspace = [" & names.join(", ") & "]\n"
    text.add externals
  parseDeclText(text, "niuv.toml", "/w/" & name).get

proc closureOf(pkgs: seq[PackageDecl], root: string): Closure =
  let ext = freshDir("sbom-ext")
  createDir(ext / "e-2.0.0-aaaa")
  let ws = Workspace(file: "/w/niuv.workspace.toml", dir: "/w", packages: pkgs, externalRoots: @[ext])
  resolveClosure(ws, root).get

suite "NIV-19 sbom":
  test "Given a closure, When components are listed, Then each package has name version and license":
    let c = closureOf(@[pkg("app", "Apache-2.0", ["lib"]), pkg("lib", "MIT")], "app")
    let comps = nimComponents(c)
    check comps.len == 2
    check comps[0].name == "app" and comps[0].version == "1.0.0" and comps[0].licenses == @["Apache-2.0"]
    check comps[1].name == "lib" and comps[1].licenses == @["MIT"]

  test "Given a package without a nim table, When nim components are listed, Then it is left out":
    let c = closureOf(@[pkg("app", "Apache-2.0", ["lib"]), pkg("lib", "MIT", extra = "[gleam]\n")], "app")
    check nimComponents(c).len == 1

  test "Given the rendered SBOM, When parsed as JSON, Then it is a CycloneDX 1.5 document with the components":
    let c = closureOf(@[pkg("app", "Apache-2.0", ["lib"]), pkg("lib", "MIT")], "app")
    let j = parseJson(renderSbom("app", "1.0.0", nimComponents(c)))
    check j["bomFormat"].getStr == "CycloneDX"
    check j["specVersion"].getStr == "1.5"
    check j["metadata"]["component"]["name"].getStr == "app"
    check j["components"].len == 2
    check j["components"][1]["name"].getStr == "lib"
    check j["components"][1]["licenses"][0]["license"]["id"].getStr == "MIT"

  test "Given a license expression, When rendered, Then it is an expression and not an id":
    let c = closureOf(@[pkg("app", "MIT OR Apache-2.0")], "app")
    let j = parseJson(renderSbom("app", "1.0.0", nimComponents(c)))
    check j["components"][0]["licenses"][0]["expression"].getStr == "MIT OR Apache-2.0"

  test "Given an external without a license, When rendered, Then the license is NOASSERTION, never invented":
    let ext = "[dependencies.external.e]\nsource = \"github.com/a/e\"\nversion = \"2.0.0\"\n"
    let c = closureOf(@[pkg("app", "MIT", externals = ext)], "app")
    let comps = nimComponents(c)
    check comps[1].name == "e"
    check comps[1].licenses.len == 0
    let j = parseJson(renderSbom("app", "1.0.0", comps))
    check j["components"][1]["licenses"][0]["license"]["name"].getStr == "NOASSERTION"

  test "Given an external with a declared license, When listed, Then the license is carried":
    let ext = "[dependencies.external.e]\nsource = \"github.com/a/e\"\nversion = \"2.0.0\"\nlicense = \"MIT\"\n"
    let c = closureOf(@[pkg("app", "MIT", externals = ext)], "app")
    check nimComponents(c)[1].licenses == @["MIT"]

  test "Given the same input rendered twice, When compared, Then the bytes are equal and the order is by name":
    let c1 = closureOf(@[pkg("app", "MIT", ["zeta", "alpha"]), pkg("zeta", "MIT"), pkg("alpha", "MIT")], "app")
    let a = renderSbom("app", "1.0.0", nimComponents(c1))
    check a == renderSbom("app", "1.0.0", nimComponents(c1))
    check a.find("alpha") < a.find("zeta")

suite "NIV-20 license gate":
  proc gated(license: string, sealed: bool, family = "nim"): NResult[void] =
    let c = closureOf(@[pkg("app", "Apache-2.0", ["dep"]), pkg("dep", license)], "app")
    checkLicenses(nimComponents(c), sealed, "app")

  test "Given a sealed artifact and GPL-3.0 in the closure, When gated, Then it is refused naming package and license":
    for l in ["GPL-3.0-only", "GPL-3.0-or-later", "GPL-3.0", "GPL-3.0+", "LGPL-3.0-only", "LGPL-3.0-or-later",
              "AGPL-3.0-only", "AGPL-3.0-or-later", "gpl-3.0-only"]:
      let r = gated(l, true)
      check r.isErr
      check r.error.kind == ekLicense
      check "dep" in r.error.msg
      check l in r.error.msg

  test "Given a sealed artifact and an expression that lists GPL-3.0, When gated, Then it is refused":
    check gated("MIT OR GPL-3.0-only", true).isErr
    check gated("(MIT AND LGPL-3.0-or-later)", true).isErr

  test "Given licenses that are not v3 copyleft, When gated, Then they pass":
    for l in ["MIT", "Apache-2.0", "BSD-3-Clause", "GPL-2.0-only", "LGPL-2.1-only", "MPL-2.0", "ISC"]:
      check gated(l, true).isOk

  test "Given GPL-3.0 and no sealed artifact, When gated, Then the gate is open":
    check gated("GPL-3.0-only", false).isOk

  test "Given a sealed artifact and a package whose license is unknown, When gated, Then it is refused as unknown":
    let ext = "[dependencies.external.e]\nsource = \"github.com/a/e\"\nversion = \"2.0.0\"\n"
    let c = closureOf(@[pkg("app", "MIT", externals = ext)], "app")
    let r = checkLicenses(nimComponents(c), true, "app")
    check r.isErr
    check r.error.kind == ekLicense
    check "'e'" in r.error.msg
    check "unknown" in r.error.msg

  test "Given an unknown license and no sealed artifact, When gated, Then it passes":
    let ext = "[dependencies.external.e]\nsource = \"github.com/a/e\"\nversion = \"2.0.0\"\n"
    let c = closureOf(@[pkg("app", "MIT", externals = ext)], "app")
    check checkLicenses(nimComponents(c), false, "app").isOk
