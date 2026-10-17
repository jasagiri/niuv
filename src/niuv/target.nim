## Targets (NIV-24): the machine a build is for, as `<cpu>-<os>-<libc>`.
##
## niuv builds for the machine it runs on and for nothing else (no cross
## compiling: the ADR's "採らなかった案"). A Linux target is therefore reached by
## running niuv inside the builder guest (NIV-27), not by building for it here.
## Only the two targets with a user are known; x86_64 and glibc come when a
## user does (Future).

import std/[os, sequtils, strutils]
import ./errors

const
  LinuxMusl* = "aarch64-linux-musl"
  MacosArm64* = "aarch64-macos-none"  ## the third part is "none": macOS has no libc to choose
  KnownTargets* = [LinuxMusl, MacosArm64]

type
  Target* = object
    cpu*, os*, libc*: string

proc `$`*(t: Target): string {.raises: [].} =
  t.cpu & "-" & t.os & "-" & t.libc

proc isLinux*(t: Target): bool {.raises: [].} =
  t.os == "linux"

proc targetErr[T](msg: string): NResult[T] {.raises: [].} =
  err(niuvError(ekUsage, msg))

proc parseTarget*(s: string): NResult[Target] {.raises: [].} =
  ## A target string niuv knows. A string that has the shape but is not one of
  ## `KnownTargets` is refused by name, so that "x86_64-linux-glibc" is told
  ## apart from a typo.
  let parts = s.split('-')
  if parts.len != 3 or parts.anyIt(it.len == 0):
    return targetErr[Target]("'" & s & "' is not a target: write <cpu>-<os>-<libc>, for example " & LinuxMusl)
  if s notin KnownTargets:
    return targetErr[Target]("target '" & s & "' is not one niuv builds; the targets are " &
                             KnownTargets.join(", "))
  ok(Target(cpu: parts[0], os: parts[1], libc: parts[2]))

proc detectTarget*(cpu, os: string, muslLoader: bool): NResult[Target] {.raises: [].} =
  ## The target of a machine from Nim's names for its CPU and OS, and from
  ## whether `/lib/ld-musl-<cpu>.so.1` exists (a Linux without it is not musl).
  let cpuName =
    case cpu
    of "arm64": "aarch64"
    else: cpu
  case os
  of "macosx": parseTarget(cpuName & "-macos-none")
  of "linux":
    if not muslLoader:
      return targetErr[Target]("this Linux has no /lib/ld-musl-" & cpuName & ".so.1: niuv knows the musl target only")
    parseTarget(cpuName & "-linux-musl")
  else:
    targetErr[Target]("no niuv target for " & cpu & " " & os)

proc hostTarget*(): NResult[Target] {.raises: [].} =
  ## The machine niuv runs on, decided when it runs (hostCPU and hostOS name
  ## what this niuv was compiled on, which is what it runs on).
  let cpuName = if hostCPU == "arm64": "aarch64" else: hostCPU
  detectTarget(hostCPU, hostOS, fileExists("/lib/ld-musl-" & cpuName & ".so.1"))

proc ownTarget*(named: string): NResult[Target] {.raises: [].} =
  ## The target of a build that runs here (NIV-24): the machine's own. A
  ## `--target` that names another is refused, because niuv does not cross
  ## compile; a Linux target is reached with `--in-builder` from a host.
  let own = ?hostTarget()
  if named.len == 0: return ok(own)
  let asked = ?parseTarget(named)
  if $asked != $own:
    return targetErr[Target]("this niuv runs on " & $own & " and builds that target only; --target " & named &
                             " is reached with --in-builder (the build runs in the builder image)")
  ok(own)
