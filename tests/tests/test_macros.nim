import std/unittest

## Test Macros Module

import std/[unittest, os, times, strutils]
import ../src/macros
import ../src/utils

suite "Macros Module Tests":
  test "NiuvError exception type":
    # Test that NiuvError can be raised and caught
    try:
      raise newException(NiuvError, "Test error")
      check false  # Should not reach here
    except NiuvError as e:
      check e.msg == "Test error"
    
  test "withEnv macro basic usage":
    # Save original env
    let originalPath = getEnv("PATH")
    let originalHome = getEnv("HOME")
    
    # Test changing environment variables
    withEnv([("PATH", "/custom/path"), ("HOME", "/custom/home")]):
      check getEnv("PATH") == "/custom/path"
      check getEnv("HOME") == "/custom/home"
    
    # Check environment is restored
    check getEnv("PATH") == originalPath
    check getEnv("HOME") == originalHome
    
  test "withEnv macro with empty array":
    let originalPath = getEnv("PATH")
    
    # Should work with no environment changes
    withEnv([]):
      check getEnv("PATH") == originalPath
    
    check getEnv("PATH") == originalPath
    
  test "benchmark macro basic usage":
    var executed = false
    
    benchmark "Test operation":
      # Simulate some work
      sleep(10)  # Sleep for 10ms
      executed = true
    
    check executed == true
    
  test "benchmark macro with return value":
    let result = benchmark "Calculation":
      # Return a value from the benchmarked block
      var sum = 0
      for i in 1..100:
        sum += i
      sum
    
    check result == 5050
    
  test "safeExec macro with successful execution":
    var executed = false
    
    let success = safeExec:
      executed = true
      # No exception thrown
    
    check executed == true
    check success == true
    
  test "safeExec macro with exception and default handler":
    var beforeException = false
    
    let success = safeExec:
      beforeException = true
      raise newException(ValueError, "Test exception")
      # This should not execute
      check false
    
    check beforeException == true
    check success == false
    
  test "safeExec macro with custom handler":
    var handlerCalled = false
    var capturedMsg = ""
    
    let success = safeExec:
      raise newException(IOError, "Custom error")
    do (e: ref Exception):
      handlerCalled = true
      capturedMsg = e.msg
      false  # Return false to indicate failure
    
    check handlerCalled == true
    check capturedMsg == "Custom error"
    check success == false
    
  test "ensureDir macro single directory":
    let testDir = getTempDir() / "niuv_test_ensureDir"
    
    # Remove if exists
    if dirExists(testDir):
      removeDir(testDir)
    
    # Create directory
    ensureDir testDir
    
    check dirExists(testDir)
    
    # Cleanup
    removeDir(testDir)
    
  test "ensureDir macro multiple directories":
    let testDir1 = getTempDir() / "niuv_test_ensureDir1"
    let testDir2 = getTempDir() / "niuv_test_ensureDir2"
    let testDir3 = getTempDir() / "niuv_test_ensureDir3"
    
    # Remove if exist
    for dir in [testDir1, testDir2, testDir3]:
      if dirExists(dir):
        removeDir(dir)
    
    # Create directories
    ensureDir testDir1, testDir2, testDir3
    
    check dirExists(testDir1)
    check dirExists(testDir2)
    check dirExists(testDir3)
    
    # Cleanup
    for dir in [testDir1, testDir2, testDir3]:
      removeDir(dir)
    
  test "ensureDir macro with existing directory":
    let testDir = getTempDir() / "niuv_test_existing"
    
    # Create directory first
    createDir(testDir)
    
    # Should not fail when directory exists
    ensureDir testDir
    
    check dirExists(testDir)
    
    # Cleanup
    removeDir(testDir)
    
  test "withTempDir macro basic usage":
    var tempDirPath = ""
    var fileCreated = false
    
    withTempDir tmpDir:
      tempDirPath = tmpDir
      check dirExists(tmpDir)
      
      # Create a file in temp dir
      let testFile = tmpDir / "test.txt"
      writeFile(testFile, "Hello")
      fileCreated = fileExists(testFile)
    
    # Temp directory should be cleaned up
    check fileCreated == true
    check not dirExists(tempDirPath)
    
  test "withTempDir macro with exception":
    var tempDirPath = ""
    
    try:
      withTempDir tmpDir:
        tempDirPath = tmpDir
        check dirExists(tmpDir)
        raise newException(ValueError, "Test exception")
    except ValueError:
      discard
    
    # Temp directory should still be cleaned up even with exception
    check not dirExists(tempDirPath)
    
  test "withTempDir macro nested usage":
    var outerPath = ""
    var innerPath = ""
    
    withTempDir outerDir:
      outerPath = outerDir
      check dirExists(outerDir)
      
      withTempDir innerDir:
        innerPath = innerDir
        check dirExists(innerDir)
        check outerDir != innerDir
      
      # Inner temp dir should be gone
      check not dirExists(innerPath)
      # Outer should still exist
      check dirExists(outerDir)
    
    # Both should be gone now
    check not dirExists(outerPath)
    check not dirExists(innerPath)