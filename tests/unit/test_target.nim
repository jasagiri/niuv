## E tests for targets: NIV-24 (the pure part; the command line is in test_cli.nim).

import std/[strutils, unittest]
import ../../src/niuv/[errors, target]

const testFile* = "tests/unit/test_target.nim"

suite "NIV-24 targets":
  test "Given the two known target strings, When parsed, Then cpu os and libc are the three parts":
    let t = parseTarget("aarch64-linux-musl")
    check t.isOk
    check t.get.cpu == "aarch64" and t.get.os == "linux" and t.get.libc == "musl"
    check $t.get == "aarch64-linux-musl"
    check t.get.isLinux
    let m = parseTarget("aarch64-macos-none")
    check m.isOk
    check not m.get.isLinux

  test "Given a string that is not <cpu>-<os>-<libc>, When parsed, Then it is refused as a malformed target":
    for s in ["", "linux", "aarch64-linux", "aarch64-linux-musl-x", "aarch64--musl"]:
      let r = parseTarget(s)
      check r.isErr
      check r.error.kind == ekUsage
      check "<cpu>-<os>-<libc>" in r.error.msg

  test "Given x86_64 or glibc, When parsed, Then it is refused by name as a target niuv does not build":
    for s in ["x86_64-linux-musl", "aarch64-linux-gnu", "x86_64-linux-glibc", "aarch64-windows-none"]:
      let r = parseTarget(s)
      check r.isErr
      check s in r.error.msg
      check "aarch64-linux-musl" in r.error.msg

  test "Given arm64 and macosx, When detected, Then the target is aarch64-macos-none":
    check $detectTarget("arm64", "macosx", false).get == "aarch64-macos-none"
    check $detectTarget("arm64", "macosx", true).get == "aarch64-macos-none"

  test "Given arm64 and linux with the musl loader, When detected, Then the target is aarch64-linux-musl":
    check $detectTarget("arm64", "linux", true).get == "aarch64-linux-musl"

  test "Given linux without the musl loader, When detected, Then it is refused (glibc is not a target)":
    let r = detectTarget("arm64", "linux", false)
    check r.isErr
    check "musl" in r.error.msg

  test "Given a CPU or OS that is not known, When detected, Then it is refused":
    check detectTarget("amd64", "macosx", false).isErr
    check detectTarget("arm64", "windows", false).isErr
    check detectTarget("amd64", "linux", true).isErr

  test "Given this machine, When its target is asked, Then it is decided at run time and is a known target":
    let t = hostTarget()
    check t.isOk
    check $t.get in KnownTargets
