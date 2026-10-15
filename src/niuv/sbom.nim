## The bill of materials and the license gate (NIV-19, NIV-20).
##
## The SBOM is a CycloneDX 1.5 JSON document, cut down to the fields niuv
## knows: the component's name, version and licenses. It carries no hashes,
## purls or dependency graph yet (Future).

import std/[algorithm, json]
import ./[errors, license, resolve]

type
  Component* = object
    name*, version*: string
    licenses*: seq[string]   ## empty: not declared

proc byName(a, b: Component): int {.raises: [].} =
  result = cmp(a.name, b.name)
  if result == 0: result = cmp(a.version, b.version)

proc nimComponents*(c: Closure): seq[Component] {.raises: [].} =
  ## The packages of the closure that contribute Nim code, and its externals.
  for d in c.packages:
    if d.nim.present:
      result.add Component(name: d.name, version: d.version, licenses: @[d.license])
  for e in c.externals:
    result.add Component(name: e.name, version: e.version,
                         licenses: if e.license.len > 0: @[e.license] else: @[])
  result.sort(byName)

proc gleamComponents*(c: Closure, hex: seq[Component]): seq[Component] {.raises: [].} =
  ## The packages of the closure that contribute Gleam code, and the Hex
  ## packages `gleam` fetched for them (read from their own gleam.toml).
  for d in c.packages:
    if d.gleam.present:
      result.add Component(name: d.name, version: d.version, licenses: @[d.license])
  result.add hex
  result.sort(byName)

proc licenseNode(licenses: seq[string]): JsonNode {.raises: [].} =
  result = newJArray()
  if licenses.len == 0:
    result.add %*{"license": {"name": "NOASSERTION"}}
    return
  for l in licenses:
    if ' ' in l or '(' in l: result.add %*{"expression": l}
    else: result.add %*{"license": {"id": l}}

proc renderSbom*(rootName, rootVersion: string, comps: seq[Component]): string {.raises: [].} =
  let components = newJArray()
  for c in comps.sorted(byName):
    components.add %*{"type": "library", "name": c.name, "version": c.version,
                      "licenses": licenseNode(c.licenses)}
  let doc = %*{
    "bomFormat": "CycloneDX",
    "specVersion": "1.5",
    "version": 1,
    "metadata": {"component": {"type": "application", "name": rootName, "version": rootVersion}},
    "components": components}
  doc.pretty & "\n"

proc checkLicenses*(comps: seq[Component], sealed: bool, what: string): NResult[void] {.raises: [].} =
  ## Open when nothing is sealed. For a sealed artifact every license must be
  ## known and none may be in the v3 copyleft family.
  if not sealed: return ok()
  for c in comps:
    if c.licenses.len == 0:
      return err(niuvError(ekLicense, "sealed artifact of '" & what & "': the license of '" & c.name &
        "' is unknown; a sealed artifact needs every license known (declare it in niuv.toml)"))
    for l in c.licenses:
      if isCopyleftV3(l):
        return err(niuvError(ekLicense, "sealed artifact of '" & what & "': '" & c.name & "' " &
          c.version & " is under " & l & "; GPL-3.0, LGPL-3.0 and AGPL-3.0 must not be in a sealed artifact"))
  ok()
