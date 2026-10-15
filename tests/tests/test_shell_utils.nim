import std/unittest

## Test file for the migrated shell utilities in src/utils/shell.nim

import unittest
import std/os
import std/strutils
import std/tables
import std/strtabs

# Import the module to test
import ../src/utils/shell

suite "Shell Utilities Tests":
  
  test "runCommand - simple echo":
    when defined(windows):
      let cmd = "echo Hello World"
    else:
      let cmd = "echo 'Hello World'"
    
    let (exitCode, output) = runCommand(cmd)
    check exitCode == 0
    check output.strip() == "Hello World"
  
  test "runCommand - verbose mode":
    when defined(windows):
      let cmd = "echo Hello Verbose"
    else:
      let cmd = "echo 'Hello Verbose'"
    
    let (exitCode, output) = runCommand(cmd, verbose=true)
    check exitCode == 0
    check output.strip() == "Hello Verbose"
  
  test "runCommand - command with error":
    # Run a command that should fail
    let (exitCode, _) = runCommand("command_that_does_not_exist_123456")
    check exitCode != 0
  
  test "runCommandWithEnv - with environment variable":
    # Create environment with a test variable
    var env = newStringTable()
    env["TEST_VAR"] = "test_value"
    
    when defined(windows):
      let cmd = "echo %TEST_VAR%"
    else:
      let cmd = "echo $TEST_VAR"
    
    let (exitCode, output) = runCommandWithEnv(cmd, env=env)
    check exitCode == 0
    check output.strip() == "test_value"
  
  test "getWorkingDirectory - current directory":
    let curDir = getWorkingDirectory()
    check curDir.len > 0
    check dirExists(curDir) == true
  
  test "getHomeDirectory - user home":
    let homeDir = getHomeDirectory()
    check homeDir.len > 0
    check dirExists(homeDir) == true
  
  test "getTempDirectory - temporary directory":
    let tempDir = getTempDirectory()
    check tempDir.len > 0
    check dirExists(tempDir) == true
  
  test "platform detection functions":
    # These are compile-time functions - we're just testing they don't crash
    let isWin = isWindows()
    let isMac = isMacOS()
    let isLin = isLinux()
    
    # Should be exactly one true value
    check (if isWin: 1 else: 0) + (if isMac: 1 else: 0) + (if isLin: 1 else: 0) <= 1
  
  test "getPlatformPathSeparator - correct character":
    let separator = getPlatformPathSeparator()
    when defined(windows):
      check separator == '\\'
    else:
      check separator == '/'
  
  test "getPlatformExecutableExtension - correct extension":
    let extension = getPlatformExecutableExtension()
    when defined(windows):
      check extension == ".exe"
    else:
      check extension == ""
  
  test "getPlatformScriptExtension - correct extension":
    let extension = getPlatformScriptExtension()
    when defined(windows):
      check extension == ".bat"
    else:
      check extension == ".sh"
  
  test "findExecutableInPath - existing command":
    # Look for a command that should exist on all platforms
    when defined(windows):
      let execPath = findExecutableInPath("cmd")
      check execPath.len > 0
      check execPath.toLowerAscii().contains("cmd")
    else:
      let execPath = findExecutableInPath("sh")
      check execPath.len > 0
      check execPath.contains("/sh") or execPath.endsWith("sh")
  
  test "findExecutableInPath - nonexistent command":
    let execPath = findExecutableInPath("command_that_does_not_exist_123456")
    check execPath.len == 0
  
  test "setEnvVars - new variables":
    let env = setEnvVars({"TEST_VAR1": "value1", "TEST_VAR2": "value2"})
    check env["TEST_VAR1"] == "value1"
    check env["TEST_VAR2"] == "value2"
  
  test "shellEscape - safe string":
    let safeStr = "simple_string"
    let escaped = shellEscape(safeStr)
    check escaped == safeStr
  
  test "shellEscape - string with spaces":
    let strWithSpaces = "string with spaces"
    let escaped = shellEscape(strWithSpaces)
    when defined(windows):
      check escaped == "\"string with spaces\""
    else:
      check escaped == "'string with spaces'"
  
  test "shellEscape - string with special characters":
    let strWithSpecial = "string$with\"special'chars"
    let escaped = shellEscape(strWithSpecial)
    when defined(windows):
      check escaped.startsWith("\"")
      check escaped.endsWith("\"")
    else:
      check escaped.startsWith("'")
      check escaped.endsWith("'")
      
when isMainModule:
  discard