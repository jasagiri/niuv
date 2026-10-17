## E tests for the Linux build in the builder image: NIV-27 (the host's call
## and its re-check), NIV-28 (what the guest is told), NIV-31 (no network, a
## Hex copy handed over).
##
## `kite` is replaced by a shell script that records its arguments and, as the
## guest would, writes prepared files into the directory mounted at /out. The
## real kite starting a real guest is tests/acceptance/test_builder_guest.nim.

import std/[options, os, sequtils, strutils, unittest]
import ../../src/niuv/[artifact, cli, errors, hashing, inbuilder, lock, manifest, resolve, toolchain, workspace]
import support

const testFile* = "tests/unit/test_inbuilder.nim"

const
  linux = "aarch64-linux-musl"
  digest = "sha256:" & "cd".repeat(32)
  image = "niuv/builder@" & digest
  fakeKite = """#!/bin/sh
printf '%s\n' "$@" > "$FAKE_KITE_LOG"
out=""
for a in "$@"; do
  case "$a" in
    --mount:*:/out:rw) m=${a#--mount:}; out=${m%:/out:rw} ;;
  esac
done
if [ -n "$FAKE_KITE_OUT" ] && [ -n "$out" ]; then cp -R "$FAKE_KITE_OUT"/. "$out"/; fi
if [ -n "$FAKE_KITE_SAY" ]; then echo "$FAKE_KITE_SAY"; fi
exit ${FAKE_KITE_EXIT:-0}
"""

proc pkgToml(name: string, extra = ""): string =
  "[package]\nname = \"" & name & "\"\nversion = \"0.1.0\"\nlicense = \"Apache-2.0\"\n" & extra

type Rig = object
  dir, ws, kiteDir, log: string

proc setUp(name: string, kiteLabel = "0.1.0"): Rig =
  ## A workspace of `app` (a Nim bin `hello`, depends on `lib`) and `lib`, that
  ## pins nim and a fake kite; the host lock; the Linux lock with a builder.
  let d = freshDir(name)
  writeTree(d, {
    "app/niuv.toml": pkgToml("app", "\n[nim]\n[[nim.bin]]\nname = \"hello\"\nmain = \"child/hello.nim\"\n" &
      "[dependencies]\nworkspace = [\"lib\"]\n"),
    "app/child/hello.nim": "import greeter\necho greet(\"guest\")\n",
    "app/src/placeholder.nim": "discard",
    "lib/niuv.toml": pkgToml("lib", "\n[nim]\n"),
    "lib/src/greeter.nim": "proc greet*(n: string): string = \"hello \" & n\n",
    "kitebin/kite": fakeKite,
    "niuv.workspace.toml": "[workspace]\nmembers = [\"app\", \"lib\"]\n[tools.nim]\nversion = \"" & realNim().version &
      "\"\n[tools.kite]\nversion = \"" & kiteLabel & "\"\n"})
  setFilePermissions(d / "kitebin" / "kite", {fpUserRead, fpUserWrite, fpUserExec})
  Rig(dir: d, ws: d / "niuv.workspace.toml", kiteDir: d / "kitebin", log: d / "kite-args.txt")

proc writeLinuxLock(r: Rig, withBuilder = true, imageName = image, erlang = "") =
  ## What `niuv lock --target aarch64-linux-musl` leaves: the guest's tool
  ## pins (nim at some SHA-256 of the Linux binary; no kite; erlang when asked)
  ## and the builder.
  let ws = loadWorkspace(r.ws).get
  var tools = @[ToolInfo(name: "nim", version: realNim().version, exe: "/guest/nim", sha256: "11".repeat(32))]
  if erlang.len > 0:
    tools.add ToolInfo(name: "erlang", version: erlang, exe: "/guest/erlc", sha256: "33".repeat(32))
  let l = buildLock(ws, tools, if withBuilder: some(LockedBuilder(image: imageName)) else: none(LockedBuilder)).get
  check writeLock(ws, l, linux).isOk

proc withKite(r: Rig, body: proc ()) =
  ## Runs `body` with the fake kite first on PATH, and the environment of the fake set.
  let oldPath = getEnv("PATH")
  putEnv("PATH", r.kiteDir & ":" & oldPath)
  putEnv("FAKE_KITE_LOG", r.log)
  try:
    body()
  finally:
    putEnv("PATH", oldPath)
    for k in ["FAKE_KITE_LOG", "FAKE_KITE_OUT", "FAKE_KITE_EXIT", "FAKE_KITE_SAY"]: delEnv(k)

proc lockHost(r: Rig) =
  withKite(r, proc () = check runCli(@["lock", "--workspace", r.ws]).code == 0)

proc guestOutput(r: Rig, name: string, bin = "ELF-hello", target = linux): string =
  ## What a well-behaved guest leaves in /out.
  let g = r.dir / name
  removeDir(g)
  createDir(g)
  writeFile(g / "hello", bin)
  let a = Artifact(name: "hello", kind: akNimChild, path: g / "hello", sha256: sha256Hex(bin), size: bin.len.int64)
  writeFile(g / "niuv.manifest.cbor", encodeManifest("app", "0.1.0", @[a], target, "").get)
  writeFile(g / "niuv.sbom.cdx.json", "{}")
  g

proc build(r: Rig, extra: seq[string] = @[]): CliResult =
  runCli(@["build", "app", "--workspace", r.ws, "--target", linux, "--in-builder", "--out", r.dir / "out",
           "--stage", r.dir / "stage"] & extra)

proc ready(name: string): Rig =
  ## Host lock, Linux lock, and a good guest output for the fake kite to leave.
  let r = setUp(name)
  lockHost(r)
  writeLinuxLock(r)
  r

proc kiteArgsSeen(r: Rig): seq[string] =
  readFile(r.log).splitLines.filterIt(it.len > 0)

suite "NIV-27 coverRoots":
  test "Given directories inside one another, When covered, Then only the outer ones remain":
    check coverRoots(["/a/b", "/a/b/c", "/d"], 8).get == @["/a/b", "/d"]

  test "Given the same directory twice, When covered, Then it is once":
    check coverRoots(["/a/b", "/a/b"], 8).get == @["/a/b"]

  test "Given more directories than the limit, When covered, Then the two with the deepest shared parent are merged":
    check coverRoots(["/x/y/p", "/x/y/q", "/z/w"], 2).get == @["/x/y", "/z/w"]

  test "Given directories that share nothing below /, When the limit is too low, Then it is refused, never /":
    let r = coverRoots(["/a", "/b", "/c"], 2)
    check r.isErr
    check "mount" in r.error.msg

  test "Given a limit that is met, When covered, Then nothing is merged":
    check coverRoots(["/x/y/p", "/x/y/q", "/z/w"], 3).get == @["/x/y/p", "/x/y/q", "/z/w"]

suite "NIV-27 what the guest gets":
  test "Given a workspace, When the mounts are planned, Then sources are read-only at their own paths and only /out is writable":
    let r = setUp("ib-mounts")
    let ws = loadWorkspace(r.ws).get
    let c = resolveClosure(ws, "app").get
    let m = planMounts(ws, [c], r.dir / "o", r.dir / "c", "").get
    check m.len <= MaxMounts
    for x in m:
      if x.dst == GuestOut: check not x.readOnly
      else: check x.readOnly
    check m.filterIt(not it.readOnly).len == 1
    check m.anyIt(it.dst == GuestCtl and it.src == r.dir / "c")
    check m.anyIt(it.dst == r.dir and it.src == r.dir)
    check m.allIt(it.dst != GuestHex)

  test "Given a Hex copy, When the mounts are planned, Then it is read-only at /hex":
    let r = setUp("ib-mounts-hex")
    let ws = loadWorkspace(r.ws).get
    let m = planMounts(ws, [resolveClosure(ws, "app").get], r.dir / "o", r.dir / "c", r.dir / "h").get
    check m.anyIt(it.dst == GuestHex and it.src == r.dir / "h" and it.readOnly)

  test "Given members in other directories, When the mounts are planned, Then each is mounted and none overlaps another":
    let r = setUp("ib-mounts-far")
    let far = freshDir("ib-mounts-far-lib")
    writeTree(far, {"niuv.toml": pkgToml("far", "\n[nim]\n"), "src/far.nim": "discard"})
    writeFile(r.ws, readFile(r.ws).replace("members = [\"app\", \"lib\"]", "members = [\"app\", \"lib\", \"" & relativePath(far, r.dir) & "\"]"))
    let ws = loadWorkspace(r.ws).get
    let m = planMounts(ws, [resolveClosure(ws, "app").get], r.dir / "o", r.dir / "c", "").get
    check m.anyIt(it.dst == far)
    for a in m:
      for b in m:
        if a.dst != b.dst: check not (a.dst.startsWith(b.dst & "/"))

  test "Given a source directory that holds /out, When the mounts are planned, Then it is refused":
    let r = setUp("ib-mounts-root")
    var ws = loadWorkspace(r.ws).get
    ws.dir = "/"
    check planMounts(ws, [], r.dir / "o", r.dir / "c", "").isErr

  test "Given settings, When kite's arguments are made, Then the image is by digest, the guest has no --net, and the status is asked for":
    let s = GuestSettings(image: image, signature: "/s.sig", cpu: 2, memoryMb: 2048)
    let a = kiteArgs(s, "id1", @[GuestMount(src: "/src", dst: "/src", readOnly: true),
                                 GuestMount(src: "/o", dst: GuestOut, readOnly: false)])
    check a[0] == "run"
    check "--image:" & image in a
    check "--signature:/s.sig" in a
    check "--exit-status" in a
    check "--cmdline:init=" & GuestEntry in a
    check "--mount:/src:/src:ro" in a
    check "--mount:/o:/out:rw" in a
    check a.allIt(not it.startsWith("--net"))
    check a.allIt(not it.startsWith("--kernel") and not it.startsWith("--initrd"))

  test "Given a kernel and an initrd, When kite's arguments are made, Then they are passed on":
    let a = kiteArgs(GuestSettings(image: image, kernel: "/k", initrd: "/i", cpu: 1, memoryMb: 512), "id", @[])
    check "--kernel:/k" in a and "--initrd:/i" in a

  test "Given arguments with quotes and spaces, When the guest script is made, Then niuv gets each one intact":
    let sc = guestScript(@["build", "a b", "it's"], false)
    check sc.startsWith("#!/bin/sh\n")
    check "exec niuv 'build' 'a b' 'it'\\''s'\n" in sc
    check "/hex" notin sc

  test "Given a Hex copy, When the guest script is made, Then it copies /hex into gleam's cache before niuv runs":
    let sc = guestScript(@["build"], true)
    check "cp -R /hex " in sc
    check sc.find("cp -R /hex") < sc.find("exec niuv")

suite "NIV-27 niuv build --in-builder":
  test "Given locks and a well-behaved guest, When built in the builder, Then the artifacts are listed, verified and in the output directory":
    let r = ready("ib-ok")
    let g = guestOutput(r, "ok-guest")
    var res: CliResult
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      res = r.build())
    check res.code == 0
    check "hello nim-child " & sha256Hex("ELF-hello") in res.stdout
    check "manifest " & r.dir / "out" / "niuv.manifest.cbor" in res.stdout
    check readFile(r.dir / "out" / "hello") == "ELF-hello"
    let m = decodeManifest(readFile(r.dir / "out" / "niuv.manifest.cbor")).get
    check m.formatVersion == 2 and m.target == linux

  test "Given a run, When kite was called, Then it got the image of the lock, no network and the status option":
    let r = ready("ib-args")
    let g = guestOutput(r, "args-guest")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      check r.build().code == 0)
    let a = kiteArgsSeen(r)
    check "--image:" & image in a
    check "--exit-status" in a
    check a.allIt(not it.startsWith("--net"))
    check a.anyIt(it == "--mount:" & r.dir / "out" & ":/out:rw")
    check a.filterIt(it.endsWith(":rw")).len == 1

  test "Given --signature, --kernel and --initrd, When built, Then kite gets them":
    let r = ready("ib-sig")
    let g = guestOutput(r, "sig-guest")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      check r.build(@["--signature", "/x/b.sig", "--kernel", "/x/k", "--initrd", "/x/i", "--cpu", "3", "--memory", "4096"]).code == 0)
    let a = kiteArgsSeen(r)
    check "--signature:/x/b.sig" in a and "--kernel:/x/k" in a and "--initrd:/x/i" in a
    check "--cpu:3" in a and "--memory:4096" in a

  test "Given the Linux lock without a [builder], When built in the builder, Then it is refused and no guest starts":
    let r = setUp("ib-nobuilder")
    lockHost(r)
    writeLinuxLock(r, withBuilder = false)
    withKite(r, proc () =
      let res = r.build()
      check res.code != 0
      check "[builder]" in res.stderr
      check not fileExists(r.log))

  test "Given no lock for the target, When built in the builder, Then it is refused naming the file":
    let r = setUp("ib-nolock")
    lockHost(r)
    withKite(r, proc () =
      let res = r.build()
      check res.code != 0
      check "niuv.aarch64-linux-musl.lock" in res.stderr
      check not fileExists(r.log))

  test "Given a package edited after the Linux lock, When built in the builder, Then it is refused before the guest starts (NIV-12)":
    let r = ready("ib-stale")
    writeFile(r.dir / "lib" / "src" / "greeter.nim", "proc greet*(n: string): string = \"changed\"\n")
    withKite(r, proc () =
      let res = r.build()
      check res.code != 0
      check "lib" in res.stderr and "niuv lock --target " & linux in res.stderr
      check not fileExists(r.log))

  test "Given a kite whose SHA-256 is not the one in niuv.lock, When built in the builder, Then it is refused before the guest starts":
    let r = ready("ib-kitesha")
    writeFile(r.kiteDir / "kite", fakeKite & "# another kite\n")
    withKite(r, proc () =
      let res = r.build()
      check res.code != 0
      check "kite" in res.stderr and "SHA-256" in res.stderr
      check not fileExists(r.log))

  test "Given a workspace that declares another kite version than the lock, When built in the builder, Then it is refused":
    let r = ready("ib-kitever")
    writeFile(r.ws, readFile(r.ws).replace("version = \"0.1.0\"", "version = \"0.2.0\""))
    withKite(r, proc () =
      let res = r.build()
      check res.code != 0
      check "kite" in res.stderr and "0.1.0" in res.stderr
      check not fileExists(r.log))

  test "Given a workspace that pins no kite, When built in the builder, Then it is refused":
    let r = ready("ib-nokite")
    writeFile(r.ws, readFile(r.ws).replace("[tools.kite]\nversion = \"0.1.0\"\n", ""))
    withKite(r, proc () =
      let res = r.build()
      check res.code != 0
      check "kite" in res.stderr)

  test "Given a guest that ends with a status other than 0, When built in the builder, Then it is refused with the end of its output":
    let r = ready("ib-exit")
    let g = guestOutput(r, "exit-guest")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      putEnv("FAKE_KITE_EXIT", "3")
      putEnv("FAKE_KITE_SAY", "nim: error: out of luck")
      let res = r.build()
      check res.code != 0
      check "status 3" in res.stderr
      check "out of luck" in res.stderr)

  test "Given a guest that leaves one byte of a file changed, When built in the builder, Then the host's hash refuses it":
    let r = ready("ib-bytes")
    let g = guestOutput(r, "bytes-guest")
    writeFile(g / "hello", "ELF-hellO")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "hello" in res.stderr and sha256Hex("ELF-hellO") in res.stderr)

  test "Given a guest that changes the size and the content, When built in the builder, Then it is refused":
    let r = ready("ib-size")
    let g = guestOutput(r, "size-guest")
    writeFile(g / "hello", "ELF-hello-longer")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "hello" in res.stderr)

  test "Given a guest that leaves a file the manifest does not list, When built in the builder, Then it is refused":
    let r = ready("ib-extra")
    let g = guestOutput(r, "extra-guest")
    writeFile(g / "backdoor", "x")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "backdoor" in res.stderr)

  test "Given a guest that leaves a file inside a directory the manifest does not list, When built in the builder, Then it is refused":
    let r = ready("ib-extra-dir")
    let g = guestOutput(r, "extradir-guest")
    createDir(g / "beam" / "evil")
    writeFile(g / "beam" / "evil" / "x.beam", "x")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "beam/evil/x.beam" in res.stderr)

  test "Given a guest that leaves no manifest, When built in the builder, Then it is refused":
    let r = ready("ib-nomanifest")
    let g = guestOutput(r, "nomanifest-guest")
    removeFile(g / "niuv.manifest.cbor")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "niuv.manifest.cbor" in res.stderr)

  test "Given a guest that leaves no SBOM, When built in the builder, Then it is refused":
    let r = ready("ib-nosbom")
    let g = guestOutput(r, "nosbom-guest")
    removeFile(g / "niuv.sbom.cdx.json")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "niuv.sbom.cdx.json" in res.stderr)

  test "Given a manifest for another target, When built in the builder, Then it is refused":
    let r = ready("ib-othertarget")
    let g = guestOutput(r, "other-guest", target = "aarch64-macos-none")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "aarch64-macos-none" in res.stderr)

  test "Given a manifest of format version 1, When built in the builder, Then it is refused (the guest must write version 2)":
    let r = ready("ib-v1")
    let g = guestOutput(r, "v1-guest")
    # version 1 bytes: {1: 1, 2: "app", 3: "0.1.0", 4: []}
    writeFile(g / "niuv.manifest.cbor", "\xA4\x01\x01\x02\x63app\x03\x650.1.0\x04\x80")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "version" in res.stderr)

  test "Given a manifest that lists a bin the package does not declare, When built in the builder, Then it is refused":
    let r = ready("ib-undeclared")
    let g = guestOutput(r, "undeclared-guest")
    writeFile(g / "extra", "ELF")
    let arts = @[Artifact(name: "hello", kind: akNimChild, sha256: sha256Hex("ELF-hello"), size: 9),
                 Artifact(name: "extra", kind: akNimChild, sha256: sha256Hex("ELF"), size: 3)]
    writeFile(g / "niuv.manifest.cbor", encodeManifest("app", "0.1.0", arts, linux, "").get)
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "extra" in res.stderr)

  test "Given a manifest that names a file outside the output directory, When built in the builder, Then it is refused":
    let r = ready("ib-escape")
    let g = guestOutput(r, "escape-guest")
    let arts = @[Artifact(name: "hello", kind: akNimChild, sha256: sha256Hex("ELF-hello"), size: 9),
                 Artifact(name: "../evil", kind: akBeam, sha256: sha256Hex("x"), size: 1)]
    writeFile(g / "niuv.manifest.cbor", encodeManifest("app", "0.1.0", arts, linux, "29.1.1").get)
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "not a file name" in res.stderr)

  test "Given a manifest for another package or version, When built in the builder, Then it is refused":
    let r = ready("ib-otherpkg")
    let g = guestOutput(r, "otherpkg-guest")
    let a = Artifact(name: "hello", kind: akNimChild, sha256: sha256Hex("ELF-hello"), size: 9)
    writeFile(g / "niuv.manifest.cbor", encodeManifest("app", "9.9.9", @[a], linux, "").get)
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "9.9.9" in res.stderr)

  test "Given an output directory that already holds a file, When built in the builder, Then it is refused and no guest starts":
    let r = ready("ib-dirty")
    createDir(r.dir / "out")
    writeFile(r.dir / "out" / "old", "x")
    withKite(r, proc () =
      let res = r.build()
      check res.code != 0
      check "not empty" in res.stderr
      check not fileExists(r.log))

  test "Given a target that is not Linux, When built in the builder, Then it is refused":
    let r = ready("ib-notlinux")
    withKite(r, proc () =
      let res = runCli(@["build", "app", "--workspace", r.ws, "--target", "aarch64-macos-none", "--in-builder",
                         "--out", r.dir / "out", "--stage", r.dir / "stage"])
      check res.code != 0
      check "Linux" in res.stderr)

  test "Given a package with Gleam and no Hex copy, When built in the builder, Then it is refused: the guest has no network":
    let r = ready("ib-nohex")
    writeTree(r.dir, {"app/gleam.toml": "name = \"app\"\nversion = \"0.1.0\"\ntarget = \"erlang\"\n"})
    writeFile(r.dir / "app" / "niuv.toml", readFile(r.dir / "app" / "niuv.toml") & "[gleam]\n")
    # the lock moved with the declaration: lock again
    withKite(r, proc () =
      check runCli(@["lock", "--workspace", r.ws]).code == 0)
    writeLinuxLock(r)
    withKite(r, proc () =
      let res = r.build(@["--hex-cache", r.dir / "no-such-hex"])
      check res.code != 0
      check "Hex" in res.stderr and "--hex-cache" in res.stderr
      check not fileExists(r.log))

proc withBeams(g: string, apps: openArray[(string, string)], otp = "29.1.1") =
  ## Adds beams `beam/<app>/<module>.beam` to a guest output and rewrites its manifest.
  var arts = @[Artifact(name: "hello", kind: akNimChild, sha256: sha256Hex("ELF-hello"), size: 9)]
  for (app, module) in apps:
    createDir(g / "beam" / app)
    writeFile(g / "beam" / app / (module & ".beam"), "BEAM-" & module)
    arts.add Artifact(name: module, kind: akBeam, sha256: sha256Hex("BEAM-" & module), size: ("BEAM-" & module).len.int64)
  writeFile(g / "niuv.manifest.cbor", encodeManifest("app", "0.1.0", arts, linux, otp).get)

suite "NIV-27 beams in the guest's output":
  test "Given beams of the pinned OTP in beam/<app>/, When built in the builder, Then they are verified and listed":
    let r = setUp("ib-beams")
    lockHost(r)
    writeLinuxLock(r, erlang = "29.1.1")
    let g = guestOutput(r, "beams-guest")
    withBeams(g, [("app", "app_mod"), ("gleam_stdlib", "gleam@list")])
    var res: CliResult
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      res = r.build())
    check res.code == 0
    check "app_mod beam " in res.stdout and "gleam@list beam " in res.stdout
    check decodeManifest(readFile(r.dir / "out" / "niuv.manifest.cbor")).get.otpVersion == "29.1.1"

  test "Given beams made by another OTP than the lock pins, When built in the builder, Then it is refused naming both":
    let r = setUp("ib-otp")
    lockHost(r)
    writeLinuxLock(r, erlang = "29.1.1")
    let g = guestOutput(r, "otp-guest")
    withBeams(g, [("app", "app_mod")], otp = "28.0")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "28.0" in res.stderr and "29.1.1" in res.stderr)

  test "Given beams and a lock that pins no erlang, When built in the builder, Then it is refused":
    let r = ready("ib-otp-none")
    let g = guestOutput(r, "otpnone-guest")
    withBeams(g, [("app", "app_mod")])
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "OTP" in res.stderr)

  test "Given one module in two applications, When built in the builder, Then it is refused":
    let r = setUp("ib-twoapps")
    lockHost(r)
    writeLinuxLock(r, erlang = "29.1.1")
    let g = guestOutput(r, "twoapps-guest")
    withBeams(g, [("app", "app_mod")])
    createDir(g / "beam" / "other")
    writeFile(g / "beam" / "other" / "app_mod.beam", "BEAM-app_mod")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "app_mod" in res.stderr)

  test "Given a listed beam that is missing, When built in the builder, Then it is refused":
    let r = setUp("ib-nobeam")
    lockHost(r)
    writeLinuxLock(r, erlang = "29.1.1")
    let g = guestOutput(r, "nobeam-guest")
    withBeams(g, [("app", "app_mod")])
    removeFile(g / "beam" / "app" / "app_mod.beam")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "app_mod" in res.stderr)

  test "Given a symbolic link in the output, When built in the builder, Then it is refused":
    let r = ready("ib-symlink")
    let g = guestOutput(r, "symlink-guest")
    removeFile(g / "hello")
    createSymlink("/etc/hosts", g / "hello")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = r.build()
      check res.code != 0
      check "regular file" in res.stderr)

suite "NIV-27 niuv lock --in-builder":
  proc guestLock(r: Rig, name: string, mutate: proc (l: var Lock) = nil): string =
    ## The lock a guest would write: the workspace's pins and the Linux tools.
    let ws = loadWorkspace(r.ws).get
    var l = buildLock(ws, @[ToolInfo(name: "nim", version: realNim().version, exe: "/g/nim", sha256: "22".repeat(32))],
                      some(LockedBuilder(image: image))).get
    if mutate != nil: mutate(l)
    let g = r.dir / name
    removeDir(g)
    createDir(g)
    check writeLockFile(g / lockFileName(linux), l).isOk
    g

  test "Given a guest that writes a lock, When locked in the builder, Then the host keeps it as niuv.<target>.lock with the builder it named":
    let r = setUp("ibl-ok")
    lockHost(r)
    let okLock = guestLock(r, "ok-lock")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", okLock)
      let res = runCli(@["lock", "--workspace", r.ws, "--target", linux, "--in-builder", "--builder", image,
                         "--stage", r.dir / "stage"])
      check res.code == 0
      let l = readLockFile(r.dir / lockFileName(linux)).get
      check l.builder.get.image == image
      check l.tools.mapIt(it.name) == @["nim"]
      check l.tools[0].sha256 == "22".repeat(32))
    let a = kiteArgsSeen(r)
    check "--image:" & image in a

  test "Given a guest lock with a package hash the host does not compute, When locked in the builder, Then it is refused and nothing is written":
    let r = setUp("ibl-badpkg")
    lockHost(r)
    let g = guestLock(r, "badpkg-lock", proc (l: var Lock) = l.packages[0].sha256 = "00".repeat(32))
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = runCli(@["lock", "--workspace", r.ws, "--target", linux, "--in-builder", "--builder", image,
                         "--stage", r.dir / "stage"])
      check res.code != 0
      check not fileExists(r.dir / lockFileName(linux)))

  test "Given a guest lock that names another builder image, When locked in the builder, Then it is refused":
    let r = setUp("ibl-otherimage")
    lockHost(r)
    let g = guestLock(r, "otherimage-lock", proc (l: var Lock) = l.builder = some(LockedBuilder(image: "evil/x@sha256:" & "00".repeat(32))))
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      let res = runCli(@["lock", "--workspace", r.ws, "--target", linux, "--in-builder", "--builder", image,
                         "--stage", r.dir / "stage"])
      check res.code != 0
      check not fileExists(r.dir / lockFileName(linux)))

  test "Given a guest lock that pins another nim version than the workspace, When locked in the builder, Then it is refused":
    let r = setUp("ibl-otherver")
    lockHost(r)
    let g = guestLock(r, "otherver-lock", proc (l: var Lock) = l.tools[0].version = "1.0.0")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", g)
      check runCli(@["lock", "--workspace", r.ws, "--target", linux, "--in-builder", "--builder", image,
                     "--stage", r.dir / "stage"]).code != 0)

  test "Given no builder image anywhere, When locked in the builder, Then it is refused":
    let r = setUp("ibl-noimage")
    lockHost(r)
    withKite(r, proc () =
      let res = runCli(@["lock", "--workspace", r.ws, "--target", linux, "--in-builder", "--stage", r.dir / "stage"])
      check res.code != 0
      check "--builder" in res.stderr
      check not fileExists(r.log))

  test "Given an existing target lock with a builder, When locked in the builder without --builder, Then that builder is used":
    let r = setUp("ibl-keep")
    lockHost(r)
    writeLinuxLock(r)
    let keepLock = guestLock(r, "keep-lock")
    withKite(r, proc () =
      putEnv("FAKE_KITE_OUT", keepLock)
      check runCli(@["lock", "--workspace", r.ws, "--target", linux, "--in-builder", "--stage", r.dir / "stage"]).code == 0)
    check "--image:" & image in kiteArgsSeen(r)
