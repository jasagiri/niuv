## E tests for the child form: NIV-21.

import std/[os, osproc, streams, strutils, unittest]
import cbor_det
import nim_frames/[child, frames]
import ../../src/niuv/[child, cli, errors, manifest]
import support

const testFile* = "tests/unit/test_child.nim"

proc pkgToml(name: string, extra = ""): string =
  "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n" & extra

proc makeWorkspace(dir: string): string =
  writeTree(dir, {
    "app/niuv.toml": pkgToml("app", "\n[nim]\n[[nim.bin]]\nname = \"hello\"\nmain = \"child/hello.nim\"\n"),
    "app/child/hello.nim": "echo \"from the child\"\n",
    "app/src/placeholder.nim": "discard",
    "niuv.workspace.toml": "[workspace]\nmembers = [\"app\"]\n[tools.nim]\nversion = \"" & realNim().version & "\"\n"})
  dir / "niuv.workspace.toml"

proc request(kind: uint64, ws, package, outDir: string): CborValue =
  cMap(@[entry(1, cUint(kind)), entry(2, cText(ws)), entry(3, cText(package)), entry(4, cText(outDir))])

proc errorCode(reply: CborValue): uint64 =
  ## [1, [code, detail]] -> code
  doAssert reply.kind == ckArray and reply.items[0].uintVal == 1
  reply.items[1].items[0].uintVal

suite "NIV-21 child form":
  test "Given a build request, When handled, Then the reply carries the manifest bytes of the build":
    let d = freshDir("child-ok")
    let w = makeWorkspace(d)
    check runCli(@["lock", "--workspace", w]).code == 0
    let reply = handleRequest(request(1, w, "app", d / "out"))
    check reply.kind == ckArray
    check reply.items[0].uintVal == 0
    let m = lookup(reply.items[1], 1)
    check m.found
    check m.value.kind == ckBytes
    check m.value.bytesVal == readFile(d / "out" / "niuv.manifest.cbor")
    check decodeManifest(m.value.bytesVal).get.entries[0].name == "hello"

  test "Given a package the workspace lacks, When handled, Then the reply is not-found":
    let d = freshDir("child-nopkg")
    let w = makeWorkspace(d)
    check errorCode(handleRequest(request(1, w, "ghost", d / "out"))) == ecNotFound

  test "Given a workspace file that does not exist, When handled, Then the reply is not-found":
    let d = freshDir("child-nows")
    check errorCode(handleRequest(request(1, d / "nope.toml", "app", d / "out"))) == ecNotFound

  test "Given no lock, When handled, Then the reply is refused and says to lock":
    let d = freshDir("child-nolock")
    let w = makeWorkspace(d)
    let reply = handleRequest(request(1, w, "app", d / "out"))
    check errorCode(reply) == ecRefused
    check "niuv lock" in reply.items[1].items[1].textVal

  test "Given a request of another kind, When handled, Then the reply is unknown-kind":
    let d = freshDir("child-kind")
    check errorCode(handleRequest(request(9, "w", "app", "o"))) == ecUnknownKind

  test "Given a request that is not a map of the right fields, When handled, Then the reply is malformed":
    check errorCode(handleRequest(cText("build"))) == ecMalformed
    check errorCode(handleRequest(cMap(@[entry(1, cUint(1))]))) == ecMalformed
    check errorCode(handleRequest(cMap(@[entry(1, cUint(1)), entry(2, cUint(5)), entry(3, cText("a")),
                                         entry(4, cText("b"))]))) == ecMalformed

  test "Given the niuv binary, When it is started as a child, Then it says ready, answers a request and ends on EOF":
    let d = freshDir("child-process")
    let w = makeWorkspace(d)
    check runCli(@["lock", "--workspace", w]).code == 0
    let exe = d / "niuv-bin"
    let (o, code) = execCmdEx("nim c --hints:off -o:" & exe & " " & (currentSourcePath().parentDir() / ".." / ".." / "src" / "niuv.nim"))
    check code == 0
    if code != 0: echo o
    let p = startProcess(exe, args = ["child"], options = {poStdErrToStdout})
    let inFd = cint(p.inputHandle)
    let outFd = cint(p.outputHandle)
    let ready = readFrame(outFd)
    check ready.ok
    check decode(ready.value).value.items[0].uintVal == 0
    check writeFrame(inFd, encode(request(1, w, "app", d / "out")).value).ok
    let answer = readFrame(outFd)
    check answer.ok
    let reply = decode(answer.value).value
    check reply.items[0].uintVal == 0
    check lookup(reply.items[1], 1).value.bytesVal == readFile(d / "out" / "niuv.manifest.cbor")
    p.inputStream.close()
    check p.waitForExit() == 0
    p.close()
