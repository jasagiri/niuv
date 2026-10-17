## E tests for the manifest: NIV-18, and NIV-29 (format version 2: the target
## and the OTP version; version 1 is still read).

import std/[strutils, unittest]
import cbor_det
import ../../src/niuv/[artifact, errors, hashing, manifest]

const testFile* = "tests/unit/test_manifest.nim"

const
  linux = "aarch64-linux-musl"
  mac = "aarch64-macos-none"

proc art(name: string, kind: ArtifactKind, content: string, path = "/p/x"): Artifact =
  Artifact(name: name, kind: kind, path: path, sha256: sha256Hex(content), size: content.len.int64)

proc hexOf(s: string): string =
  for c in s: result.add toHex(ord(c), 2).toLowerAscii

proc rawOf(hex: string): string =
  for i in 0 ..< hex.len div 2:
    result.add chr(parseHexInt(hex[2 * i .. 2 * i + 1]))

proc enc(package, version: string, arts: seq[Artifact], target = mac): NResult[string] =
  ## The OTP version follows the artifacts: a beam among them needs one.
  var otp = ""
  for a in arts:
    if a.kind == akBeam: otp = "29.1.1"
  encodeManifest(package, version, arts, target, otp)

proc v1Item(name, kind, content: string): CborValue =
  cMap(@[entry(1, cText(name)), entry(2, cText(kind)), entry(3, cBytes(rawOf(sha256Hex(content)))),
         entry(4, cUint(uint64(content.len)))])

proc v1Manifest(package, version: string, items: seq[CborValue]): string =
  ## A format-version-1 manifest, the bytes niuv wrote before NIV-29.
  encode(cMap(@[entry(1, cUint(1)), entry(2, cText(package)), entry(3, cText(version)),
                entry(4, cArray(items))])).value

suite "NIV-18 manifest":
  test "Given one artifact, When encoded, Then the bytes are the deterministic CBOR of the fixed layout":
    let m = enc("r", "1.0.0", @[art("a", akNimChild, "abc")], linux)
    check m.isOk
    check hexOf(m.get) == "a6" & "0102" & "026172" & "0365" & "312e302e30" & "0481" & "a4" &
      "016161" & "0269" & "6e696d2d6368696c64" & "03" & "5820" &
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" & "0403" &
      "0572" & hexOf(linux) & "0660"

  test "Given a manifest, When decoded, Then name kind SHA-256 and size come back":
    let m = enc("pkg", "2.3.4", @[art("x", akBeam, "hello"), art("y", akNimChild, "world!")]).get
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
    check enc("r", "1.0.0", @[a, b, c]).get == enc("r", "1.0.0", @[c, a, b]).get

  test "Given the same content at other paths, When encoded, Then the bytes are equal":
    check enc("r", "1.0.0", @[art("a", akBeam, "1", "/one/a")]).get ==
          enc("r", "1.0.0", @[art("a", akBeam, "1", "/two/deeper/a")]).get

  test "Given a sealed mark, When encoded, Then the manifest does not carry it":
    var s = art("a", akBeam, "1")
    s.sealed = true
    check enc("r", "1.0.0", @[s]).get == enc("r", "1.0.0", @[art("a", akBeam, "1")]).get

  test "Given a manifest, When its CBOR is read, Then only the layout's keys exist and no signature":
    let m = enc("r", "1.0.0", @[art("a", akBeam, "1")]).get
    let v = decode(m).value
    check v.kind == ckMap
    var keys: seq[uint64]
    for e in v.entries: keys.add e.key
    check keys == @[1'u64, 2, 3, 4, 5, 6]
    let item = v.entries[3].value.items[0]
    check item.entries.len == 4
    check item.entries[2].value.kind == ckBytes
    check item.entries[2].value.bytesVal.len == 32

  test "Given two artifacts of one kind and name, When encoded, Then it is refused":
    let r = enc("r", "1.0.0", @[art("a", akBeam, "1"), art("a", akBeam, "2")])
    check r.isErr
    check "a" in r.error.msg

  test "Given the same name in two kinds, When encoded, Then it is accepted":
    check enc("r", "1.0.0", @[art("a", akBeam, "1"), art("a", akNimChild, "2")]).isOk

  test "Given a SHA-256 that is not 64 hex digits, When encoded, Then it is refused":
    var bad = art("a", akBeam, "1")
    bad.sha256 = "zz"
    check enc("r", "1.0.0", @[bad]).isErr

  test "Given bytes that are not a manifest, When decoded, Then it is refused":
    check decodeManifest("not cbor").isErr
    check decodeManifest(encode(cMap(@[entry(1, cUint(2))])).value).isErr

  test "Given an unknown format version, When decoded, Then it is refused":
    let m = enc("r", "1.0.0", @[]).get
    let v = decode(m).value
    var changed = v
    changed.entries[0] = entry(1, cUint(9))
    check decodeManifest(encode(changed).value).isErr

  test "Given an empty artifact list, When encoded and decoded, Then it is a valid empty manifest":
    let d = decodeManifest(enc("r", "1.0.0", @[]).get)
    check d.isOk
    check d.get.entries.len == 0

suite "NIV-29 manifest format version 2":
  test "Given a build for a target, When encoded and decoded, Then the version is 2 and the target comes back":
    let d = decodeManifest(enc("r", "1.0.0", @[art("a", akNimChild, "1")], linux).get).get
    check d.formatVersion == 2
    check d.target == linux

  test "Given a beam, When encoded with the OTP version, Then the OTP version comes back":
    let d = decodeManifest(encodeManifest("r", "1.0.0", @[art("a", akBeam, "1")], linux, "29.1.1").get).get
    check d.otpVersion == "29.1.1"

  test "Given no beam, When encoded with an empty OTP version, Then the OTP version is the empty string":
    let d = decodeManifest(enc("r", "1.0.0", @[art("a", akNimChild, "1")]).get).get
    check d.otpVersion == ""

  test "Given a beam and no OTP version, When encoded, Then it is refused":
    let r = encodeManifest("r", "1.0.0", @[art("a", akBeam, "1")], linux, "")
    check r.isErr
    check "OTP" in r.error.msg

  test "Given an OTP version and no beam, When encoded, Then it is refused":
    let r = encodeManifest("r", "1.0.0", @[art("a", akNimChild, "1")], linux, "29.1.1")
    check r.isErr
    check "OTP" in r.error.msg

  test "Given a target niuv does not know, When encoded, Then it is refused":
    check encodeManifest("r", "1.0.0", @[], "x86_64-linux-glibc", "").isErr
    check encodeManifest("r", "1.0.0", @[], "", "").isErr

  test "Given the same build for two targets, When encoded, Then the bytes differ and each says its own target":
    let a = enc("r", "1.0.0", @[art("a", akNimChild, "1")], linux).get
    let b = enc("r", "1.0.0", @[art("a", akNimChild, "1")], mac).get
    check a != b
    check decodeManifest(a).get.target == linux
    check decodeManifest(b).get.target == mac

  test "Given a version 1 manifest, When decoded, Then it is read with the target and OTP version unknown":
    let d = decodeManifest(v1Manifest("old", "0.9.0", @[v1Item("x", "beam", "hello")]))
    check d.isOk
    check d.get.formatVersion == 1
    check d.get.package == "old" and d.get.version == "0.9.0"
    check d.get.entries.len == 1 and d.get.entries[0].sha256 == sha256Hex("hello")
    check d.get.target == "" and d.get.otpVersion == ""

  test "Given a version 1 manifest with six keys, When decoded, Then it is refused (version 1 has four)":
    var v = decode(enc("r", "1.0.0", @[]).get).value
    v.entries[0] = entry(1, cUint(1))
    check decodeManifest(encode(v).value).isErr

  test "Given a version 2 manifest with four keys, When decoded, Then it is refused (version 2 has six)":
    var v = decode(v1Manifest("r", "1.0.0", @[])).value
    v.entries[0] = entry(1, cUint(2))
    check decodeManifest(encode(v).value).isErr

  test "Given a version 2 manifest whose target is not text, When decoded, Then it is refused":
    var v = decode(enc("r", "1.0.0", @[]).get).value
    v.entries[4] = entry(5, cUint(1))
    check decodeManifest(encode(v).value).isErr

  test "Given a version 2 manifest with a beam and an empty OTP version, When decoded, Then it is refused":
    var v = decode(encodeManifest("r", "1.0.0", @[art("a", akBeam, "1")], linux, "29.1.1").get).value
    v.entries[5] = entry(6, cText(""))
    check decodeManifest(encode(v).value).isErr
