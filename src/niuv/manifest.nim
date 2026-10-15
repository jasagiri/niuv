## The manifest of one build: what was made, by name, kind, SHA-256 and size
## (NIV-18). Deterministic CBOR (nim-cbor-det). It is not signed: the key to
## sign with lives on the other side of the line niuv does not cross.
##
## Layout, all keys unsigned integers:
##   {1: format version (1), 2: package, 3: package version,
##    4: [{1: name, 2: kind, 3: SHA-256 (32 bytes), 4: size}, ...]}
## Entries are sorted by kind then name; paths are not recorded, so the same
## content gives the same bytes wherever it was built.

import std/[algorithm, strutils]
import cbor_det
import ./[artifact, errors]

const
  FormatVersion = 1'u64

type
  ManifestEntry* = object
    name*: string
    kind*: ArtifactKind
    sha256*: string        ## 64 lowercase hex digits
    size*: int64

  ManifestDoc* = object
    package*, version*: string
    entries*: seq[ManifestEntry]

proc fail[T](msg: string): NResult[T] {.raises: [].} =
  err(niuvError(ekIo, "manifest: " & msg))

proc hexToRaw(hex: string): NResult[string] {.raises: [].} =
  if hex.len != 64: return fail[string]("'" & hex & "' is not a SHA-256 of 64 hex digits")
  proc nibble(c: char): int {.raises: [].} =
    case c
    of '0'..'9': ord(c) - ord('0')
    of 'a'..'f': ord(c) - ord('a') + 10
    else: -1
  var raw = newString(32)
  for i in 0 ..< 32:
    let hi = nibble(hex[2 * i])
    let lo = nibble(hex[2 * i + 1])
    if hi < 0 or lo < 0: return fail[string]("'" & hex & "' is not lowercase hex")
    raw[i] = chr(hi * 16 + lo)
  ok(raw)

proc rawToHex(raw: string): string {.raises: [].} =
  for c in raw:
    result.add toHex(ord(c), 2).toLowerAscii

proc encodeManifest*(package, version: string, artifacts: seq[Artifact]): NResult[string] {.raises: [].} =
  var sorted = artifacts
  sorted.sort(proc (a, b: Artifact): int =
    result = cmp($a.kind, $b.kind)
    if result == 0: result = cmp(a.name, b.name))
  var items: seq[CborValue]
  for i, a in sorted:
    if i > 0 and sorted[i - 1].kind == a.kind and sorted[i - 1].name == a.name:
      return fail[string]("two " & $a.kind & " artifacts are named '" & a.name & "'")
    let raw = ?hexToRaw(a.sha256)
    items.add cMap(@[entry(1, cText(a.name)), entry(2, cText($a.kind)), entry(3, cBytes(raw)),
                     entry(4, cUint(uint64(a.size)))])
  let doc = cMap(@[entry(1, cUint(FormatVersion)), entry(2, cText(package)), entry(3, cText(version)),
                   entry(4, cArray(items))])
  let enc = encode(doc)
  if not enc.ok: return fail[string]("cannot encode: " & errorName(enc.error))
  ok(enc.value)

proc field(m: CborValue, key: uint64): NResult[CborValue] {.raises: [].} =
  let f = lookup(m, key)
  if not f.found: return fail[CborValue]("key " & $key & " is missing")
  ok(f.value)

proc decodeManifest*(data: string): NResult[ManifestDoc] {.raises: [].} =
  let dec = decode(data)
  if not dec.ok: return fail[ManifestDoc]("not deterministic CBOR: " & errorName(dec.error))
  let top = dec.value
  if top.kind != ckMap or top.entries.len != 4:
    return fail[ManifestDoc]("the top level is not a map of 4 keys")
  let fv = ?field(top, 1)
  if fv.kind != ckUint or fv.uintVal != FormatVersion:
    return fail[ManifestDoc]("unknown format version")
  var doc = ManifestDoc()
  let pk = ?field(top, 2)
  let ver = ?field(top, 3)
  let arr = ?field(top, 4)
  if pk.kind != ckText or ver.kind != ckText or arr.kind != ckArray:
    return fail[ManifestDoc]("a field has the wrong type")
  doc.package = pk.textVal
  doc.version = ver.textVal
  for it in arr.items:
    if it.kind != ckMap or it.entries.len != 4: return fail[ManifestDoc]("an entry is not a map of 4 keys")
    let n = ?field(it, 1)
    let k = ?field(it, 2)
    let h = ?field(it, 3)
    let s = ?field(it, 4)
    if n.kind != ckText or k.kind != ckText or h.kind != ckBytes or h.bytesVal.len != 32 or s.kind != ckUint:
      return fail[ManifestDoc]("an entry has a field of the wrong type")
    var kind: ArtifactKind
    case k.textVal
    of "beam": kind = akBeam
    of "nim-child": kind = akNimChild
    of "wasm": kind = akWasm
    else: return fail[ManifestDoc]("unknown kind '" & k.textVal & "'")
    doc.entries.add ManifestEntry(name: n.textVal, kind: kind, sha256: rawToHex(h.bytesVal),
                                  size: int64(s.uintVal))
  ok(doc)
