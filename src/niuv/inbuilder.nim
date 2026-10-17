## `--in-builder` (NIV-27, NIV-28, NIV-31): the host runs niuv inside the
## builder image, in a kite guest, and then checks what came out.
##
## The host never believes the guest. Before the guest starts, the host
## checks `kite` against the host lock and the packages against the target's
## lock; the guest gets no network and sees the sources read-only. After it
## ends, the host reads the manifest the guest wrote and hashes every file
## again. Only the output directory is writable by the guest.
##
## Paths: the sources are mounted read-only at the same absolute path they
## have on the host, so the guest reads the same `niuv.workspace.toml`, the
## same lock and the same relative member paths. The output directory is
## `/out`, the instructions are `/ctl`, the Hex copy is `/hex`.
##
## niuv drives `kite` as a program (it is a foundation tool, not a library).
## It reaches the image's `GuestEntry`, which runs `/ctl/run.sh`. The entry is
## in the recipe (builder/builder-run); an image built before it lacks it and
## kite then refuses to start (checked 2026-10-17 on the K4-1 image).

import std/[algorithm, options, os, sequtils, strutils]
import ./[artifact, build, decl, errors, exec, gleambuild, hashing, lock, manifest, resolve, target, toolchain, workspace]

const
  GuestEntry* = "/usr/local/bin/builder-run"   ## in the image: runs /ctl/run.sh
  GuestOut* = "/out"
  GuestCtl* = "/ctl"
  GuestHex* = "/hex"
  MaxMounts* = 8                               ## kite's limit (docs/cli.md, Shared directories)
  DefaultCpu* = 2
  DefaultMemoryMb* = 2048
  MaxGuestOutput = 8192

type
  GuestMount* = object
    src*, dst*: string
    readOnly*: bool

  GuestSettings* = object
    image*: string         ## NAME@sha256:<64 hex>, from the target's lock
    signature*, kernel*, initrd*: string   ## "" leaves it to kite
    cpu*, memoryMb*: int

  BuilderOptions* = object
    ## The command line's say on how the guest is started (all optional).
    signature*, kernel*, initrd*, hexCache*: string
    cpu*, memoryMb*: int       ## 0: the default

  Verified* = object
    doc*: ManifestDoc
    outcome*: BuildOutcome

  Expectation* = object
    ## What the host knows about the build before it starts the guest.
    package*, version*, target*: string
    bins*: seq[string]             ## the Nim bins that must be listed, no more and no fewer
    pinnedOtp*: string             ## the OTP version the target's lock pins ("" if it pins none)

proc guestErr[T](msg: string): NResult[T] {.raises: [].} =
  err(niuvError(ekBuild, msg))

proc tail(s: string, n: int): string {.raises: [].} =
  if s.len <= n: s else: "..." & s[s.len - n .. ^1]

proc shQuote*(s: string): string {.raises: [].} =
  "'" & s.replace("'", "'\\''") & "'"

# ------------------------------------------------------------ what to mount

proc under(dir, root: string): bool {.raises: [].} =
  dir == root or dir.startsWith(if root.endsWith("/"): root else: root & "/")

proc commonAncestor(a, b: string): string {.raises: [].} =
  let pa = a.split('/')
  let pb = b.split('/')
  var common: seq[string]
  for i in 0 ..< min(pa.len, pb.len):
    if pa[i] != pb[i]: break
    common.add pa[i]
  let joined = common.join("/")
  if joined.len == 0: "/" else: joined

proc depth(dir: string): int {.raises: [].} =
  dir.split('/').countIt(it.len > 0)

proc dropNested(dirs: seq[string]): seq[string] {.raises: [].} =
  var uniq = dirs.deduplicate
  uniq.sort()
  for d in uniq:
    if result.allIt(not d.under(it)): result.add d

proc coverRoots*(dirs: openArray[string], limit: int): NResult[seq[string]] {.raises: [].} =
  ## The fewest directories (at most `limit`) that hold all of `dirs`: a
  ## directory inside another is dropped, and when there are still too many the
  ## two with the deepest common ancestor are replaced by that ancestor. It
  ## never reaches `/`: a mount of the whole disk is no mount.
  var cover = dropNested(@dirs)
  while cover.len > limit:
    var best = (i: -1, j: -1, d: 0)
    for i in 0 ..< cover.len:
      for j in i + 1 ..< cover.len:
        let d = depth(commonAncestor(cover[i], cover[j]))
        if d > best.d: best = (i: i, j: j, d: d)
    if best.i < 0:
      return guestErr[seq[string]]("the sources lie in " & $cover.len & " places with no shared directory below /; " &
                                   "kite mounts at most " & $MaxMounts & " directories")
    let merged = commonAncestor(cover[best.i], cover[best.j])
    cover = dropNested(cover.filterIt(it != cover[best.i] and it != cover[best.j]) & merged)
  ok(cover)

proc sourceDirs*(ws: Workspace, closures: openArray[Closure]): seq[string] {.raises: [].} =
  ## What the guest must read: the workspace directory, the root and the
  ## declaration directory of every member (the workspace file lists all of
  ## them and the guest loads all of them), and each external dependency the
  ## closures resolved. Not the whole external root: it holds more than the
  ## build asks for.
  result.add ws.dir
  for d in ws.packages:
    result.add d.root
    result.add d.declDir
  for c in closures:
    for e in c.externals:
      result.add e.dir

proc planMounts*(ws: Workspace, closures: openArray[Closure], outDir, ctlDir, hexCache: string): NResult[seq[GuestMount]] {.raises: [].} =
  ## The sources read-only at their own paths, `/ctl` read-only, `/hex`
  ## read-only when there is a Hex copy, `/out` read-write. Nothing else.
  let fixed = 2 + (if hexCache.len > 0: 1 else: 0)
  let roots = ?coverRoots(sourceDirs(ws, closures), MaxMounts - fixed)
  var mounts: seq[GuestMount]
  for r in roots:
    for reserved in [GuestOut, GuestCtl, GuestHex]:
      if r.under(reserved) or reserved.under(r):
        return guestErr[seq[GuestMount]]("the source directory " & r & " overlaps " & reserved &
                                         ", which the guest uses; kite refuses overlapping mounts")
    mounts.add GuestMount(src: r, dst: r, readOnly: true)
  mounts.add GuestMount(src: ctlDir, dst: GuestCtl, readOnly: true)
  if hexCache.len > 0:
    mounts.add GuestMount(src: hexCache, dst: GuestHex, readOnly: true)
  mounts.add GuestMount(src: outDir, dst: GuestOut, readOnly: false)
  ok(mounts)

# ------------------------------------------------------------ the kite call

proc kiteArgs*(s: GuestSettings, id: string, mounts: seq[GuestMount]): seq[string] {.raises: [].} =
  ## `kite run` with the image by digest, no network (there is no `--net`:
  ## kite's default is none, and niuv never asks for one: NIV-31), and the
  ## exit status of the guest's program.
  result = @["run", "--id:" & id, "--image:" & s.image]
  if s.signature.len > 0: result.add "--signature:" & s.signature
  if s.kernel.len > 0: result.add "--kernel:" & s.kernel
  if s.initrd.len > 0: result.add "--initrd:" & s.initrd
  result.add ["--cpu:" & $s.cpu, "--memory:" & $s.memoryMb, "--cmdline:init=" & GuestEntry, "--exit-status"]
  for m in mounts:
    result.add "--mount:" & m.src & ":" & m.dst & ":" & (if m.readOnly: "ro" else: "rw")

proc guestScript*(niuvArgs: seq[string], withHex: bool): string {.raises: [].} =
  ## /ctl/run.sh: the one command the guest runs. Gleam's Hex cache is
  ## copied from the read-only `/hex` (gleam writes in its cache), and niuv
  ## replaces the shell, so the guest's exit status is niuv's.
  result = "#!/bin/sh\nPATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin\nHOME=/tmp\nexport PATH HOME\n"
  if withHex:
    result.add "mkdir -p \"$HOME/.cache/gleam/hex/hexpm\" || exit 90\n"
    result.add "cp -R " & GuestHex & " \"$HOME/.cache/gleam/hex/hexpm/packages\" || exit 91\n"
  result.add "exec niuv " & niuvArgs.mapIt(shQuote(it)).join(" ") & "\n"

proc runGuest*(kiteExe: string, s: GuestSettings, ws: Workspace, closures: openArray[Closure],
               outDir, stageRoot, hexCache: string, niuvArgs: seq[string]): NResult[void] {.raises: [].} =
  ## Starts the guest and waits. A non-zero status of kite (which, with
  ## `--exit-status`, is the guest program's) is a refusal carrying the end of
  ## the guest's output.
  let id = "niuv-build-" & $getCurrentProcessId() & "-" & sha256Hex(outDir)[0 ..< 8]
  let ctlDir = stageRoot / "guest" / id / "ctl"
  try:
    removeDir(ctlDir.parentDir)
    createDir(ctlDir)
    createDir(outDir)
    writeFile(ctlDir / "run.sh", guestScript(niuvArgs, hexCache.len > 0))
    setFilePermissions(ctlDir / "run.sh", {fpUserRead, fpUserWrite, fpUserExec, fpGroupRead, fpGroupExec,
                                           fpOthersRead, fpOthersExec})
  except CatchableError as e:
    return err(niuvError(ekIo, ctlDir & ": " & e.msg))
  let mounts = ?planMounts(ws, closures, outDir, ctlDir, hexCache)
  let r = runProcess(kiteExe, kiteArgs(s, id, mounts))
  var cleanup = ""
  try:
    removeDir(ctlDir.parentDir)
  except CatchableError as e:
    cleanup = "; cleaning " & ctlDir.parentDir & " failed: " & e.msg
  if r.isErr: return err(r.error)
  if r.get.code != 0:
    return guestErr[void]("the builder guest ended with status " & $r.get.code & " (kite's own errors are 1 as well):\n" &
                          tail(r.get.output, MaxGuestOutput) & cleanup)
  if cleanup.len > 0: return err(niuvError(ekIo, cleanup[2 .. ^1]))
  ok()

# ------------------------------------------------------------ the host's check

proc safeName(name: string): bool {.raises: [].} =
  ## A name from the guest's manifest becomes a path under the output
  ## directory: no separator, no dot components, nothing unusual.
  name.len > 0 and name.len <= 255 and name notin [".", ".."] and
    name.allIt(it in {'a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.', '@', '+'})

proc isPlainFile(path: string): bool {.raises: [].} =
  try:
    getFileInfo(path, followSymlink = false).kind == pcFile
  except CatchableError:
    false

proc findBeam(outDir, name: string): NResult[string] {.raises: [].} =
  ## `beam/<app>/<name>.beam`, in exactly one application.
  var found: seq[string]
  let beamDir = outDir / "beam"
  try:
    if dirExists(beamDir):
      for kind, app in walkDir(beamDir, relative = true):
        if kind == pcDir and fileExists(beamDir / app / (name & ".beam")): found.add beamDir / app / (name & ".beam")
  except CatchableError as e:
    return err(niuvError(ekIo, beamDir & ": " & e.msg))
  if found.len != 1:
    return guestErr[string]("the manifest lists the beam '" & name & "' but " & $found.len &
                            " applications under " & beamDir & " have it (one is required)")
  ok(found[0])

proc verifyBuilderOutput*(outDir: string, want: Expectation): NResult[Verified] {.raises: [].} =
  ## NIV-27 (4): the manifest the guest wrote, read by the host, and every
  ## file hashed again by the host. Refused: a manifest that is not for this
  ## package, version and target; names that are not file names; a Nim bin
  ## that was not declared or is missing; an OTP that is not the pinned one;
  ## a file whose SHA-256 or size differs; a file the manifest does not list.
  let manifestPath = outDir / ManifestFile
  if not isPlainFile(manifestPath):
    return guestErr[Verified]("the guest left no " & manifestPath)
  var raw: string
  try:
    raw = readFile(manifestPath)
  except CatchableError as e:
    return err(niuvError(ekIo, manifestPath & ": " & e.msg))
  let doc = ?decodeManifest(raw)
  var outcome = BuildOutcome(manifestPath: manifestPath, sbomPath: outDir / SbomFile)
  for e in doc.entries:
    if not safeName(e.name):
      return guestErr[Verified]("the manifest lists '" & e.name & "', which is not a file name")
  if doc.formatVersion != 2:
    return guestErr[Verified]("the guest's manifest is format version " & $doc.formatVersion & ", not 2")
  if doc.package != want.package or doc.version != want.version:
    return guestErr[Verified]("the guest built " & doc.package & " " & doc.version & ", not " &
                                 want.package & " " & want.version)
  if doc.target != want.target:
    return guestErr[Verified]("the guest's manifest says target '" & doc.target & "', not '" & want.target & "'")
  let listedBins = doc.entries.filterIt(it.kind == akNimChild).mapIt(it.name).sorted
  if listedBins != want.bins.sorted:
    return guestErr[Verified]("the manifest lists the Nim bins [" & listedBins.join(", ") &
                                 "] but the package declares [" & want.bins.sorted.join(", ") & "]")
  if doc.otpVersion.len > 0 and doc.otpVersion != want.pinnedOtp:
    return guestErr[Verified]("the manifest says OTP " & doc.otpVersion & " but the target's lock pins " &
                                 (if want.pinnedOtp.len == 0: "none" else: want.pinnedOtp))
  var expected = @[ManifestFile, SbomFile]
  for e in doc.entries:
    var path: string
    case e.kind
    of akNimChild: path = outDir / e.name
    of akBeam: path = ?findBeam(outDir, e.name)
    of akWasm: return guestErr[Verified]("the manifest lists a wasm artifact; niuv builds none")
    if not isPlainFile(path):
      return guestErr[Verified]("the manifest lists " & $e.kind & " '" & e.name & "' but " & path &
                                   " is not a regular file")
    let h = ?sha256File(path)
    if h != e.sha256:
      return guestErr[Verified]($e.kind & " '" & e.name & "': the host hashed " & h & " but the manifest says " & e.sha256)
    var size: int64
    try:
      size = getFileSize(path)
    except CatchableError as ex:
      return err(niuvError(ekIo, path & ": " & ex.msg))
    if size != e.size:
      return guestErr[Verified]($e.kind & " '" & e.name & "' is " & $size & " bytes but the manifest says " & $e.size)
    expected.add path[outDir.len + 1 .. ^1]
    outcome.artifacts.add Artifact(name: e.name, kind: e.kind, path: path, sha256: h, size: size)
  if not isPlainFile(outDir / SbomFile):
    return guestErr[Verified]("the guest left no " & outDir / SbomFile)
  # Everything in the directory is accounted for.
  var present: seq[string]
  try:
    for p in walkDirRec(outDir, yieldFilter = {pcFile, pcLinkToFile, pcLinkToDir, pcDir}, relative = true):
      present.add p
  except CatchableError as e:
    return err(niuvError(ekIo, outDir & ": " & e.msg))
  for p in present:
    let full = outDir / p
    if dirExists(full) and not symlinkExists(full): continue
    if p notin expected:
      return guestErr[Verified]("the output holds " & p & ", which the manifest does not list")
  ok(Verified(doc: doc, outcome: outcome))

# ------------------------------------------------------------ the two commands

proc hostKite(ws: Workspace): NResult[ToolInfo] {.raises: [].} =
  ## NIV-27: kite is a tool of the host's own lock, version and SHA-256.
  let tools = ?probeTools(ws, ["kite"])
  let hostLock = ?readLock(ws)
  ?checkTools(hostLock, tools)
  ok(tools[0])

proc settingsFor(image: string, o: BuilderOptions): GuestSettings {.raises: [].} =
  GuestSettings(image: image, signature: o.signature, kernel: o.kernel, initrd: o.initrd,
                cpu: if o.cpu > 0: o.cpu else: DefaultCpu,
                memoryMb: if o.memoryMb > 0: o.memoryMb else: DefaultMemoryMb)

proc linuxTarget(named: string): NResult[Target] {.raises: [].} =
  let t = ?parseTarget(named)
  if not t.isLinux:
    return err(niuvError(ekUsage, "--in-builder is for a Linux target (the builder is a Linux guest); " &
                                   named & " is built natively, without it"))
  ok(t)

proc externalRootArgs(ws: Workspace): seq[string] {.raises: [].} =
  for r in ws.externalRoots: result.add ["--external-root", r]

proc hexFor(closures: openArray[Closure], o: BuilderOptions): NResult[string] {.raises: [].} =
  ## The Hex copy to hand over: "" when no package in the closures has Gleam.
  if not closures.anyIt(it.packages.anyIt(it.gleam.present)): return ok("")
  var dir = defaultHexCache()
  if o.hexCache.len > 0:
    try:
      dir = absolutePath(o.hexCache)
    except CatchableError as e:
      return err(niuvError(ekIo, "--hex-cache " & o.hexCache & ": " & e.msg))
  if not dirExists(dir):
    return guestErr[string]("a Gleam package needs the Hex packages and the guest has no network: " & dir &
                            " does not exist; give the directory of gleam's Hex copy with --hex-cache")
  ok(dir)

proc freshEmptyDir(dir: string): NResult[void] {.raises: [].} =
  ## The output directory of a guest run: new or empty, so that every file in it is the guest's.
  try:
    if dirExists(dir):
      for _ in walkDir(dir):
        return guestErr[void](dir & " is not empty; the guest's output must be the only thing in it")
    createDir(dir)
  except CatchableError as e:
    return err(niuvError(ekIo, dir & ": " & e.msg))
  ok()

proc buildInBuilder*(ws: Workspace, package, namedTarget, outDir, stageRoot: string, only: seq[string],
                     o: BuilderOptions): NResult[Verified] {.raises: [].} =
  ## NIV-27: `niuv build <package> --target T --in-builder`.
  discard ?linuxTarget(namedTarget)
  let closure = ?resolveClosure(ws, package)
  let targetLock = ?readLock(ws, namedTarget)
  ?checkLock(targetLock, ws, closure, namedTarget)
  if targetLock.builder.isNone:
    return err(niuvError(ekLock, lockFileName(namedTarget) & " has no [builder]; run `niuv lock --target " &
                                 namedTarget & " --builder NAME@sha256:<digest>`"))
  let kite = ?hostKite(ws)
  let root = ws.find(package).get
  for name in only:
    if root.nim.bins.allIt(it.name != name):
      return err(niuvError(ekUsage, "package '" & package & "' has no nim bin '" & name & "'"))
  let bins = root.nim.bins.filterIt(only.len == 0 or it.name in only).mapIt(it.name)
  let hex = ?hexFor([closure], o)
  ?freshEmptyDir(outDir)
  var args = @["build", package, "--target", namedTarget, "--workspace", ws.file, "--out", GuestOut, "--in-guest"]
  for b in only: args.add ["--bin", b]
  args.add externalRootArgs(ws)
  ?runGuest(kite.exe, settingsFor(targetLock.builder.get.image, o), ws, [closure], outDir, stageRoot, hex, args)
  let pinned = targetLock.tools.filterIt(it.name == "erlang")
  verifyBuilderOutput(outDir, Expectation(package: package, version: root.version, target: namedTarget,
                                          bins: bins, pinnedOtp: if pinned.len > 0: pinned[0].version else: ""))

proc lockInBuilder*(ws: Workspace, namedTarget, builderImage, stageRoot: string,
                    o: BuilderOptions): NResult[Lock] {.raises: [].} =
  ## `niuv lock --target T --in-builder`: the guest locks the Linux tools; the
  ## host recomputes every package and external hash itself and takes the
  ## builder image from its own side, so the guest decides neither.
  let linuxT = ?linuxTarget(namedTarget)
  var image = builderImage
  if image.len == 0:
    let existing = lockPath(ws, namedTarget)
    if fileExists(existing):
      let l = ?readLock(ws, namedTarget)
      if l.builder.isSome: image = l.builder.get.image
  if image.len == 0:
    return err(niuvError(ekUsage, "the builder image is not known: give --builder NAME@sha256:<digest>"))
  discard ?checkBuilderImage(image)
  var closures: seq[Closure]
  for d in ws.packages: closures.add ?resolveClosure(ws, d.name)
  let kite = ?hostKite(ws)
  let hex = ?hexFor(closures, o)
  let outDir = stageRoot / "guest-lock" / sha256Hex(ws.file)[0 ..< 12]
  try:
    removeDir(outDir)
  except CatchableError as e:
    return err(niuvError(ekIo, outDir & ": " & e.msg))
  ?freshEmptyDir(outDir)
  let guestFile = GuestOut / lockFileName(namedTarget)
  var args = @["lock", "--target", namedTarget, "--builder", image, "--workspace", ws.file, "--in-guest",
               "--lock-out", guestFile]
  args.add externalRootArgs(ws)
  ?runGuest(kite.exe, settingsFor(image, o), ws, closures, outDir, stageRoot, hex, args)
  let got = ?readLockFile(outDir / lockFileName(namedTarget))
  if got.builder.isNone or got.builder.get.image != image:
    return err(niuvError(ekLock, "the guest's lock names another builder image than " & image))
  for c in closures: ?checkLock(got, ws, c, namedTarget)
  let wanted = lockedToolNames(ws, linuxT).sorted
  if got.tools.mapIt(it.name).sorted != wanted:
    return err(niuvError(ekLock, "the guest's lock pins the tools [" & got.tools.mapIt(it.name).sorted.join(", ") &
                                 "], the workspace asks for [" & wanted.join(", ") & "]"))
  for t in got.tools:
    if t.version != ws.tool(t.name).get.version:
      return err(niuvError(ekLock, "the guest's lock pins " & t.name & " " & t.version & ", the workspace asks for " &
                                   ws.tool(t.name).get.version))
  ok(got)
