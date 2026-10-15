import std/unittest

## Test Regex Patterns Module

import std/[unittest, re, strutils]
import ../src/regex_patterns

suite "Regex Patterns Module Tests":
  test "requirePattern matches basic requires":
    let pattern = re(requirePattern)
    
    # Test double quotes
    var matches: array[2, string]
    check "requires \"nim >= 1.6.0\"".find(pattern, matches) >= 0
    check matches[0] == "nim >= 1.6.0"
    check matches[1] == ""
    
    # Test single quotes
    check "requires 'nimble >= 0.13.0'".find(pattern, matches) >= 0
    check matches[0] == "nimble >= 0.13.0"
    check matches[1] == ""
    
    # Test with extra spaces
    check "requires   \"chronicles\"".find(pattern, matches) >= 0
    check matches[0] == "chronicles"
    
  test "requirePattern matches dev dependencies":
    let pattern = re(requirePattern)
    var matches: array[2, string]
    
    # Test with # dev comment
    check "requires \"testpkg\" # dev".find(pattern, matches) >= 0
    check matches[0] == "testpkg"
    check matches[1].strip() == "# dev"
    
    # Test with #dev (no space)
    check "requires 'devtool' #dev".find(pattern, matches) >= 0
    check matches[0] == "devtool"
    check matches[1].strip() == "#dev"
    
  test "requirePattern handles complex package names":
    let pattern = re(requirePattern)
    var matches: array[2, string]
    
    # Package with hyphens
    check "requires \"my-package\"".find(pattern, matches) >= 0
    check matches[0] == "my-package"
    
    # Package with underscores
    check "requires \"my_package\"".find(pattern, matches) >= 0
    check matches[0] == "my_package"
    
    # Package with dots
    check "requires \"org.example.package\"".find(pattern, matches) >= 0
    check matches[0] == "org.example.package"
    
  test "requireVersionPattern matches package names":
    let pattern = re(requireVersionPattern)
    var matches: array[2, string]
    
    # Simple package name
    check "nim".match(pattern, matches)
    check matches[0] == "nim"
    check matches[1] == ""
    
    # Package with hyphens
    check "my-package".match(pattern, matches)
    check matches[0] == "my-package"
    
    # Package with underscores
    check "my_package".match(pattern, matches)
    check matches[0] == "my_package"
    
    # Package with dots
    check "org.example.pkg".match(pattern, matches)
    check matches[0] == "org.example.pkg"
    
  test "requireVersionPattern matches version constraints":
    let pattern = re(requireVersionPattern)
    var matches: array[2, string]
    
    # >= constraint
    check "nim >= 1.6.0".match(pattern, matches)
    check matches[0] == "nim"
    check matches[1].strip() == ">= 1.6.0"
    
    # > constraint
    check "package > 2.0".match(pattern, matches)
    check matches[0] == "package"
    check matches[1].strip() == "> 2.0"
    
    # < constraint
    check "tool < 3.0.0".match(pattern, matches)
    check matches[0] == "tool"
    check matches[1].strip() == "< 3.0.0"
    
    # <= constraint
    check "lib <= 1.0".match(pattern, matches)
    check matches[0] == "lib"
    check matches[1].strip() == "<= 1.0"
    
    # = constraint
    check "exact = 1.2.3".match(pattern, matches)
    check matches[0] == "exact"
    check matches[1].strip() == "= 1.2.3"
    
    # @ constraint (specific version)
    check "pkg @ 0.1.0".match(pattern, matches)
    check matches[0] == "pkg"
    check matches[1].strip() == "@ 0.1.0"
    
  test "requireVersionPattern handles complex versions":
    let pattern = re(requireVersionPattern)
    var matches: array[2, string]
    
    # Version with pre-release
    check "nim >= 2.0.0-rc1".match(pattern, matches)
    check matches[0] == "nim"
    check matches[1].strip() == ">= 2.0.0-rc1"
    
    # Version with build metadata
    check "pkg >= 1.0.0+build123".match(pattern, matches)
    check matches[0] == "pkg"
    check matches[1].strip() == ">= 1.0.0+build123"
    
  test "taskPattern matches nimble tasks":
    let pattern = re(taskPattern)
    var matches: array[2, string]
    
    # Task with comma separator
    check "task test, \"Run tests\"".find(pattern, matches) >= 0
    check matches[0] == "test"
    check matches[1].strip() == "\"Run tests\""
    
    # Task with colon separator
    check "task build: \"Build project\"".find(pattern, matches) >= 0
    check matches[0] == "build"
    check matches[1].strip() == "\"Build project\""
    
    # Task without description
    check "task clean".find(pattern, matches) >= 0
    check matches[0] == "clean"
    check matches[1] == ""
    
  test "taskPattern handles complex task names":
    let pattern = re(taskPattern)
    var matches: array[2, string]
    
    # Task with underscores
    check "task run_tests, \"Run all tests\"".find(pattern, matches) >= 0
    check matches[0] == "run_tests"
    
    # Task with hyphens
    check "task build-release: \"Build release\"".find(pattern, matches) >= 0
    check matches[0] == "build-release"
    
    # Task with numbers
    check "task test2, \"Second test\"".find(pattern, matches) >= 0
    check matches[0] == "test2"
    
  test "patterns don't match invalid input":
    # Test requirePattern
    let reqPattern = re(requirePattern)
    var matches: array[2, string]
    
    # Missing quotes
    check "requires nim >= 1.6.0".find(reqPattern, matches) < 0
    
    # Not a requires statement
    check "import os".find(reqPattern, matches) < 0
    
    # Test requireVersionPattern
    let verPattern = re(requireVersionPattern)
    
    # Invalid characters
    check not "pkg!@#$".match(verPattern, matches)
    
    # Test taskPattern
    let tskPattern = re(taskPattern)
    
    # Not a task
    check "proc test()".find(tskPattern, matches) < 0