## imagetree: what an image holds, as lines that can be compared (derive.sh,
## ADR-NIUV-0002 "K5 の続き"). A tool of the host; it uses kite's own reader of
## layers, so what is compared is what a guest would get as its root.
##
##   imagetree list DIR           one line per entry below DIR
##   imagetree unpack DIGEST OUT  the root filesystem of the image whose manifest
##                                digest is DIGEST in the store of $HOME (kite's
##                                HOME), as kite's composeRootfs builds it from
##                                all its layers. OUT must not exist.
##
## A line is `kind mode size sha256 path`, sorted by path as bytes:
##   d 0755 - - /usr           a directory
##   f 0644 123 <hex> /etc/x   a regular file
##   l - - <target> /bin/sh    a symbolic link (its own mode means nothing)
## The path starts with `/` and is relative to DIR.
import std/[algorithm, os, posix, strutils]
import nim_outcome
import oci/[digest, manifest, storage]

proc die(msg: string) {.noreturn.} =
  stderr.writeLine "imagetree: " & msg
  quit(1)

proc modeText(mode: Mode): string =
  "0" & toOct(int(mode) and 0o7777, 3)

proc entry(full, rel: string): string =
  var st: Stat
  if lstat(full.cstring, st) != 0: die("cannot stat " & full)
  if S_ISDIR(st.st_mode):
    "d " & modeText(st.st_mode) & " - - " & rel
  elif S_ISLNK(st.st_mode):
    "l - - " & expandSymlink(full) & " " & rel
  elif S_ISREG(st.st_mode):
    let d = digestOfFile(full)
    if d.isFailure: die(d.error)
    "f " & modeText(st.st_mode) & " " & $st.st_size & " " & d.value[7 .. ^1] & " " & rel
  else:
    die(full & " is neither a file, a directory nor a link")

proc listTree(root: string) =
  if not dirExists(root): die(root & " is not a directory")
  var rels: seq[string]
  for p in walkDirRec(root, yieldFilter = {pcFile, pcDir, pcLinkToFile, pcLinkToDir}, relative = true):
    rels.add "/" & p
  rels.sort(system.cmp[string])
  for rel in rels: echo entry(root & rel, rel)

proc unpack(manifestDigest, outDir: string) =
  if dirExists(outDir) or fileExists(outDir) or symlinkExists(outDir): die(outDir & " exists")
  let path = blobPath(manifestDigest)
  if not fileExists(path): die("no manifest blob " & path & ": was the image imported?")
  let bytes = readFile(path)
  if digestOf(bytes) != manifestDigest: die("the blob " & path & " is not " & manifestDigest)
  let parsed = parseImageManifest(bytes)
  if parsed.isFailure: die(parsed.error)
  var layers: seq[Layer]
  for l in parsed.value.layers:
    layers.add Layer(digest: l.digest, path: blobPath(l.digest))
  let built = composeRootfs(layers, outDir)
  if built.isFailure: die(built.error)
  stderr.writeLine "unpacked " & $layers.len & " layers into " & outDir

when isMainModule:
  let args = commandLineParams()
  if args.len == 2 and args[0] == "list":
    listTree(args[1])
  elif args.len == 3 and args[0] == "unpack":
    unpack(args[1], args[2])
  else:
    die("usage: imagetree list DIR | unpack DIGEST OUT")
