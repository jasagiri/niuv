## E tests for the manifest: NIV-18.

import std/[strutils, unittest]
import cbor_det
import ../../src/niuv/[artifact, errors, hashing, manifest]

const testFile* = "tests/unit/test_manifest.nim"

proc art(name: string, kind: ArtifactKind, content: string, path = "/p/x"): Artifact =
  Artifact(name: name, kind: kind, path: path, sha256: sha256Hex(content), size: content.len.int64)

proc hexOf(s: string): string =
  for c in s: result.add toHex(ord(c), 2).toLowerAscii

suite "NIV-18 manifest":
  test "Given one artifact, When encoded, Then the bytes are the deterministic CBOR of the fixed layout":
    let m = encodeManifest("r", "1.0.0", @[art("a", akNimChild, "abc")])
    check m.isOk
    check hexOf(m.get) == "a4" & "0101" & "026172" & "0365" & "312e302e30" & "0481" & "a4" &
      "016161" & "0269" & "6e696d2d6368696c64" & "03" & "5820" &
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" & "0403"

  test "Given a manifest, When decoded, Then name kind SHA-256 and size come back":
    let m = encodeManifest("pkg", "2.3.4", @[art("x", akBeam, "hello"), art("y", akNimChild, "world!")]).get
    let d = decodeManifest(m)
    check d.isOk
    check d.get.package == "pkg"
    check d.get.version == "2.3.4"
    check d.get.entries.len == 2
    check d.get.entries[0].name == "x" and d.get.entries[0].kind == akBeam
    check d.get.entries[0].sha256 == sha256Hex("hello") and d.get.entries[0].size == 5
    check d.get.entries[1].name == "y" and d.get.entries[1].kind == akNimChild and d.get.entries[1].size == 6

  test "Given artifacts in another order, When encoded, Then the bytes are equal":
    let a = art("a", akBeam, "1")
    let b = art("b", akNimChild, "2")
    let c = art("c", akBeam, "3")
    check encodeManifest("r", "1.0.0", @[a, b, c]).get == encodeManifest("r", "1.0.0", @[c, a, b]).get

  test "Given the same content at other paths, When encoded, Then the bytes are equal":
    check encodeManifest("r", "1.0.0", @[art("a", akBeam, "1", "/one/a")]).get ==
          encodeManifest("r", "1.0.0", @[art("a", akBeam, "1", "/two/deeper/a")]).get

  test "Given a sealed mark, When encoded, Then the manifest does not carry it":
    var s = art("a", akBeam, "1")
    s.sealed = true
    check encodeManifest("r", "1.0.0", @[s]).get == encodeManifest("r", "1.0.0", @[art("a", akBeam, "1")]).get

  test "Given a manifest, When its CBOR is read, Then only the layout's keys exist and no signature":
    let m = encodeManifest("r", "1.0.0", @[art("a", akBeam, "1")]).get
    let v = decode(m).value
    check v.kind == ckMap
    var keys: seq[uint64]
    for e in v.entries: keys.add e.key
    check keys == @[1'u64, 2, 3, 4]
    let item = v.entries[3].value.items[0]
    check item.entries.len == 4
    check item.entries[2].value.kind == ckBytes
    check item.entries[2].value.bytesVal.len == 32

  test "Given two artifacts of one kind and name, When encoded, Then it is refused":
    let r = encodeManifest("r", "1.0.0", @[art("a", akBeam, "1"), art("a", akBeam, "2")])
    check r.isErr
    check "a" in r.error.msg

  test "Given the same name in two kinds, When encoded, Then it is accepted":
    check encodeManifest("r", "1.0.0", @[art("a", akBeam, "1"), art("a", akNimChild, "2")]).isOk

  test "Given a SHA-256 that is not 64 hex digits, When encoded, Then it is refused":
    var bad = art("a", akBeam, "1")
    bad.sha256 = "zz"
    check encodeManifest("r", "1.0.0", @[bad]).isErr

  test "Given bytes that are not a manifest, When decoded, Then it is refused":
    check decodeManifest("not cbor").isErr
    check decodeManifest(encode(cMap(@[entry(1, cUint(2))])).value).isErr

  test "Given an unknown format version, When decoded, Then it is refused":
    let m = encodeManifest("r", "1.0.0", @[]).get
    let v = decode(m).value
    var changed = v
    changed.entries[0] = entry(1, cUint(9))
    check decodeManifest(encode(changed).value).isErr

  test "Given an empty artifact list, When encoded and decoded, Then it is a valid empty manifest":
    let d = decodeManifest(encodeManifest("r", "1.0.0", @[]).get)
    check d.isOk
    check d.get.entries.len == 0
