import std/unittest

## Test CLI Module

import std/[unittest, os, strutils, terminal, parseopt]
import ../src/cli

suite "CLI Module Tests":
  test "showError displays error messages":
    # Can't easily test terminal output, but ensure no crash
    showError("Test error message")
    check true  # If we get here, no exception was thrown
    
  test "showWarning displays warning messages":
    showWarning("Test warning message")
    check true
    
  test "showInfo displays info messages":
    showInfo("Test info message")
    check true
    
  test "showSuccess displays success messages":
    showSuccess("Test success message")
    check true
    
  test "newCliOptions creates default options":
    let options = newCliOptions()
    
    check options.nimVersion == ""
    check options.verbose == false
    check options.includeDev == false
    check options.parallelJobs == 0
    check options.force == false
    check options.autoLock == true
    check options.lockfile == "nimble.lock"
    check options.nimbleDir == ".niuv/deps"
    check options.useResolver == false
    check options.minimalVersions == false
    check options.conservativeVersions == false
    check options.forceResolve == false
    check options.license == "MIT"
    
  test "newCliOptions with custom values":
    let options = newCliOptions(
      nimVersion = "2.0.0",
      verbose = true,
      parallelJobs = 4,
      useResolver = true,
      author = "Test Author",
      description = "Test Project"
    )
    
    check options.nimVersion == "2.0.0"
    check options.verbose == true
    check options.parallelJobs == 4
    check options.useResolver == true
    check options.author == "Test Author"
    check options.description == "Test Project"
    
  test "parseOptions handles verbose flag":
    var options = newCliOptions()
    let args = @["--verbose"]
    
    parseOptions(args, options)
    check options.verbose == true
    
    # Test short form
    options = newCliOptions()
    parseOptions(@["-v"], options)
    check options.verbose == true
    
  test "parseOptions handles nim-version":
    var options = newCliOptions()
    let args = @["--nim-version", "2.0.0"]
    
    parseOptions(args, options)
    check options.nimVersion == "2.0.0"
    
    # Test short form
    options = newCliOptions()
    parseOptions(@["-n", "2.2.0"], options)
    check options.nimVersion == "2.2.0"
    
  test "parseOptions handles parallel jobs":
    var options = newCliOptions()
    let args = @["--parallel", "8"]
    
    parseOptions(args, options)
    check options.parallelJobs == 8
    
    # Test short form
    options = newCliOptions()
    parseOptions(@["-j", "4"], options)
    check options.parallelJobs == 4
    
  test "parseOptions handles dev flag":
    var options = newCliOptions()
    let args = @["--dev"]
    
    parseOptions(args, options)
    check options.includeDev == true
    
    # Test short form
    options = newCliOptions()
    parseOptions(@["-d"], options)
    check options.includeDev == true
    
  test "parseOptions handles force flag":
    var options = newCliOptions()
    let args = @["--force"]
    
    parseOptions(args, options)
    check options.force == true
    
    # Test short form
    options = newCliOptions()
    parseOptions(@["-f"], options)
    check options.force == true
    
  test "parseOptions handles resolver options":
    var options = newCliOptions()
    let args = @[
      "--use-resolver",
      "--minimal-versions",
      "--conservative-versions",
      "--force-resolve"
    ]
    
    parseOptions(args, options)
    check options.useResolver == true
    check options.minimalVersions == true
    check options.conservativeVersions == true
    check options.forceResolve == true
    
  test "parseOptions handles project generation options":
    var options = newCliOptions()
    let args = @[
      "--author", "John Doe",
      "--description", "Test Project",
      "--license", "Apache-2.0"
    ]
    
    parseOptions(args, options)
    check options.author == "John Doe"
    check options.description == "Test Project"
    check options.license == "Apache-2.0"
    
  test "parseOptions handles lockfile options":
    var options = newCliOptions()
    let args = @[
      "--lockfile", "custom.lock",
      "--no-lock"
    ]
    
    parseOptions(args, options)
    check options.lockfile == "custom.lock"
    check options.autoLock == false
    
  test "parseOptions handles nimble directory":
    var options = newCliOptions()
    let args = @["--nimble-dir", "/custom/path"]
    
    parseOptions(args, options)
    check options.nimbleDir == "/custom/path"
    
  test "parseOptions handles cache directory":
    var options = newCliOptions()
    let args = @["--cache-dir", "/tmp/cache"]
    
    parseOptions(args, options)
    check options.cacheDir == "/tmp/cache"
    
  test "parseOptions handles multiple options":
    var options = newCliOptions()
    let args = @[
      "--verbose",
      "--parallel", "4",
      "--nim-version", "2.0.0",
      "--dev",
      "--force",
      "--use-resolver"
    ]
    
    parseOptions(args, options)
    check options.verbose == true
    check options.parallelJobs == 4
    check options.nimVersion == "2.0.0"
    check options.includeDev == true
    check options.force == true
    check options.useResolver == true
    
  test "parseOptions handles empty args":
    var options = newCliOptions()
    parseOptions(@[], options)
    
    # Should maintain defaults
    check options.verbose == false
    check options.parallelJobs == 0
    check options.autoLock == true