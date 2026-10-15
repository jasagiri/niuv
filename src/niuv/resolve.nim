## Resolution: the closure of a package's dependencies (NIV-08, NIV-09).
##
## There is no version solving. The workspace holds one version of each of
## its packages, and an external dependency is pinned to one exact version,
## so resolving is walking names and refusing a name that arrives twice with
## different pins.

import std/[algorithm, options, os, sequtils, strutils, tables]
import ./[decl, errors, workspace]

type
  ResolvedExternal* = object
    name*, source*, version*, src*, license*: string
    dir*: string           ## the directory found in an external root (absolute)
    requiredBy*: string    ## the first package that asked for it

  Closure* = object
    root*: string
    packages*: seq[PackageDecl]         ## dependencies first, siblings in name order
    externals*: seq[ResolvedExternal]   ## by name

proc normalizedSource*(s: string): string {.raises: [].} =
  ## The identity of a source: no scheme, no trailing `.git` or `/`.
  var r = s.strip()
  for scheme in ["https://", "http://", "git://", "ssh://"]:
    if r.startsWith(scheme):
      r = r[scheme.len .. ^1]
      break
  r = r.strip(leading = false, chars = {'/'})
  if r.endsWith(".git"): r = r[0 ..< r.len - 4]
  r.toLowerAscii

proc alnumOnly(s: string): string {.raises: [].} =
  for c in s:
    if c in {'a'..'z', 'A'..'Z', '0'..'9'}: result.add c

proc cacheDirName*(source, version: string): string {.raises: [].} =
  ## The directory name nimble's package cache gives a download:
  ## `github.com/status-im/nim-bearssl` at 0.2.13 is
  ## `githubcom_statusimnimbearssl_0213`.
  var r = source.strip()
  for scheme in ["https://", "http://", "git://", "ssh://"]:
    if r.startsWith(scheme):
      r = r[scheme.len .. ^1]
      break
  let slash = r.find('/')
  let host = if slash < 0: r else: r[0 ..< slash]
  let rest = if slash < 0: "" else: r[slash + 1 .. ^1]
  alnumOnly(host) & "_" & alnumOnly(rest) & "_" & alnumOnly(version)

proc locateExternal(e: ExternalDep, roots: seq[string]): NResult[string] {.raises: [].} =
  ## The first root that holds the dependency, in either of nimble's shapes:
  ## `<name>-<version>-<hash>` (pkgs2) or the package cache's download name.
  let cacheName = cacheDirName(e.source, e.version)
  let prefix = e.name & "-" & e.version & "-"
  var tried: seq[string]
  for root in roots:
    var found: seq[string]
    try:
      if dirExists(root):
        for kind, path in walkDir(root, relative = true):
          if kind in {pcDir, pcLinkToDir} and (path == cacheName or path.startsWith(prefix)):
            found.add path
    except CatchableError as ex:
      return err(niuvError(ekIo, root & ": " & ex.msg))
    found.sort()
    if found.len == 1: return ok(root / found[0])
    if found.len > 1:
      return err(niuvError(ekResolve, "external '" & e.name & "' " & e.version &
        " is ambiguous in " & root & ": " & found.join(", ")))
    tried.add root
  err(niuvError(ekResolve, "external '" & e.name & "' " & e.version & " (" & e.source &
    ") is in none of the external roots [" & tried.join(", ") & "]; looked for '" &
    cacheName & "' or '" & prefix & "<hash>'"))

proc resolveClosure*(ws: Workspace, rootName: string): NResult[Closure] {.raises: [].} =
  var closure = Closure(root: rootName)
  var done: seq[string]
  var asked = initOrderedTable[string, ResolvedExternal]()

  proc visit(name, asker: string, stack: var seq[string]): NResult[void] {.raises: [].} =
    if name in stack:
      let at = stack.find(name)
      return err(niuvError(ekResolve, "dependency cycle: " & (stack[at .. ^1] & name).join(" -> ")))
    if name in done: return ok()
    let found = ws.find(name)
    if found.isNone:
      let who = if asker.len == 0: "the build root" else: "package '" & asker & "'"
      return err(niuvError(ekResolve, "'" & name & "' (asked for by " & who &
                           ") is not a package of the workspace " & ws.file))
    let d = found.get
    stack.add name
    for dep in d.workspaceDeps.sorted:
      ?visit(dep, name, stack)
    discard stack.pop()
    for e in d.externals:
      if asked.hasKey(e.name):
        let prev = asked.getOrDefault(e.name)
        if prev.version != e.version or normalizedSource(prev.source) != normalizedSource(e.source) or
           prev.src != e.src:
          return err(niuvError(ekConflict, "'" & e.name & "' is pinned twice in the closure of '" &
            rootName & "': " & prev.version & " (" & prev.source & ", src " & prev.src &
            ") required by '" & prev.requiredBy & "' and " & e.version & " (" & e.source &
            ", src " & e.src & ") required by '" & d.name & "'"))
      else:
        asked[e.name] = ResolvedExternal(name: e.name, source: e.source, version: e.version,
                                         src: e.src, license: e.license, requiredBy: d.name)
    done.add name
    closure.packages.add d
    ok()

  var stack: seq[string]
  ?visit(rootName, "", stack)
  var names = toSeq(asked.keys)
  names.sort()
  for n in names:
    var r = asked.getOrDefault(n)
    r.dir = ?locateExternal(ExternalDep(name: r.name, source: r.source, version: r.version, src: r.src, license: r.license),
                            ws.externalRoots)
    closure.externals.add r
  ok(closure)
