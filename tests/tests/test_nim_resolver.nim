import std/unittest

## Tests for nim_resolver module

import std/[unittest, os, strutils]
import ../src/nim_resolver
import ../src/config
import ../src/nim_detector

suite "Nim Resolver Tests":
  test "Default configuration allows system Nim":
    let config = newConfig()
    check config.allowSystemNim == true
    check config.nimDetection == "auto"
    check config.nimPath == ""

  test "Get Nim for build with system fallback":
    var config = newConfig()
    config.allowSystemNim = true
    
    # This should find some Nim compiler
    try:
      let nimPath = getNimForBuild(config)
      check nimPath != ""
      check fileExists(nimPath) or nimPath == "nim"  # Could be just "nim" if in PATH
    except NimResolverError:
      skip()  # Skip if no Nim found on system

  test "Get Nim version":
    let config = newConfig()
    let version = getNimVersion(config)
    check version != "not found"  # Should find something

  test "List available Nims":
    let nims = listAvailableNims()
    # Should find at least one Nim (the one running this test)
    check nims.len > 0

  test "Cache key generation":
    var config1 = newConfig()
    config1.nimPath = "/usr/bin/nim"
    config1.nimVersion = "2.0.0"
    
    var config2 = newConfig()
    config2.nimPath = "/usr/local/bin/nim"
    config2.nimVersion = "2.0.0"
    
    # Different paths should generate different cache keys
    let key1 = getCacheKey(config1)
    let key2 = getCacheKey(config2)
    check key1 != key2

  test "Explicit path takes precedence":
    var config = newConfig()
    config.nimPath = "/nonexistent/nim"
    config.allowSystemNim = false
    
    # Should fail with explicit invalid path
    expect NimResolverError:
      discard getNimForBuild(config)

  test "Project-only detection mode":
    var config = newConfig()
    config.nimDetection = "project-only"
    config.allowSystemNim = true  # Should be ignored
    
    # Should fail when no project-local Nim
    expect NimResolverError:
      discard getNimForBuild(config)

  test "Environment variable override":
    # Save current env
    let oldEnv = getEnv("NIUV_NIM_PATH")
    
    # Set test path
    putEnv("NIUV_NIM_PATH", "/test/nim/path")
    
    let config = newConfig()
    try:
      discard getNimForBuild(config)
      # Would succeed if path was valid
    except NimResolverError:
      # Expected for invalid path
      discard
    
    # Restore env
    if oldEnv == "":
      delEnv("NIUV_NIM_PATH")
    else:
      putEnv("NIUV_NIM_PATH", oldEnv)