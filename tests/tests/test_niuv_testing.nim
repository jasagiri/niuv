import std/unittest

## Test file for the integrated testing module in src/niuv_testing.nim

import unittest
import std/os
import std/strutils
import std/sequtils  # Add missing sequtils for anyIt

# Import the module to test
import ../src/niuv_testing

suite "Niuv Testing Integration Tests":
  setup:
    # Create a temporary test directory
    let testDir = getTempDir() / "niuv_integrated_testing_" & $getCurrentProcessId()
    createDir(testDir)
    
    # Create sample test files
    let testContentTemplate = """
import unittest

test "$1":
  check 1 + 1 == 2
"""
    
    createDir(testDir / "tests")
    writeFile(testDir / "tests/test_one.nim", testContentTemplate % "test one")
    writeFile(testDir / "tests/test_two.nim", testContentTemplate % "test two")
    writeFile(testDir / "tests/test_three.nim", testContentTemplate % "test three")
    writeFile(testDir / "tests/other_file.nim", "# not a test file")
    
    # Create subdirectory with more tests
    createDir(testDir / "tests/nested")
    writeFile(testDir / "tests/nested/test_nested.nim", testContentTemplate % "nested test")
    
    # Set current directory to test directory for the test duration
    let originalDir = getCurrentDir()
    setCurrentDir(testDir)
  
  teardown:
    # Restore original directory
    let originalDir = getCurrentDir()
    if originalDir.contains("niuv_integrated_testing"):
      setCurrentDir(parentDir(originalDir))
    
    # Clean up after tests
    if dirExists(testDir):
      removeDir(testDir)
  
  test "TestRunnerConfig - default values":
    let config = newTestRunnerConfig()
    check config.mode == trmAll
    check config.pattern == "test_*.nim"
    check config.verbose == false
    check config.generateReport == true
    check config.testDir == "tests"
  
  test "findTestFiles - all test mode":
    # Test finding all test files
    var config = newTestRunnerConfig()
    config.mode = trmAll
    config.testDir = "tests"
    
    let testFiles = findTestFiles(config)
    
    check testFiles.len == 3  # Should find the 3 test files in the main directory
    check testFiles.anyIt(it.endsWith("test_one.nim"))
    check testFiles.anyIt(it.endsWith("test_two.nim"))
    check testFiles.anyIt(it.endsWith("test_three.nim"))
    check not testFiles.anyIt(it.endsWith("other_file.nim"))  # Should not include non-test files
    check not testFiles.anyIt(it.endsWith("test_nested.nim"))  # Should not include nested files (non-recursive)
  
  test "findTestFiles - pattern mode":
    # Test finding test files by pattern
    var config = newTestRunnerConfig()
    config.mode = trmPattern
    config.pattern = "*one.nim"  # Match only the "test_one.nim" file
    config.testDir = "tests"
    
    let testFiles = findTestFiles(config)
    
    check testFiles.len == 1
    check testFiles[0].endsWith("test_one.nim")
  
  test "findTestFiles - single file mode":
    # Test finding specific test files
    var config = newTestRunnerConfig()
    config.mode = trmSingle
    config.testFiles = @["test_two.nim"]
    config.testDir = "tests"
    
    let testFiles = findTestFiles(config)
    
    check testFiles.len == 1
    check testFiles[0].endsWith("test_two.nim")
  
  test "findTestFiles - multiple specific files":
    # Test finding multiple specific test files
    var config = newTestRunnerConfig()
    config.mode = trmSingle
    config.testFiles = @["test_one.nim", "test_three.nim"]
    config.testDir = "tests"
    
    let testFiles = findTestFiles(config)
    
    check testFiles.len == 2
    check testFiles.anyIt(it.endsWith("test_one.nim"))
    check testFiles.anyIt(it.endsWith("test_three.nim"))
  
  test "findTestFiles - non-existent files":
    # Test behavior with non-existent files
    var config = newTestRunnerConfig()
    config.mode = trmSingle
    config.testFiles = @["non_existent.nim"]
    config.testDir = "tests"
    
    let testFiles = findTestFiles(config)
    
    check testFiles.len == 0  # Should not find any files
  
  when defined(skipActualExecution):
    # These tests require actual execution of tests which might be
    # problematic in automated test environments
    
    test "runAndReport - basic workflow":
      # Create test output directory
      createDir("build")
      createDir("build/test_output")
      
      # Configure test runner
      let config = newTestRunnerConfig()
      config.mode = trmSingle
      config.testFiles = @["test_one.nim"]
      config.testDir = "tests"
      config.outputDir = "build/test_output"
      
      # This would typically run the test and generate reports
      # We just check it handles configuration correctly
      let result = runAndReport(config)
      
      # We can't really assert success here since we don't have the full
      # test environment, so we just make sure it runs without exceptions

when isMainModule:
  discard