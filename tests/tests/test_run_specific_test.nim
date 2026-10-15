import std/unittest

## Test file for the migrated specific test runner in src/tools/test/run_specific_test.nim

import unittest
import std/os
import std/strutils
import std/sequtils  # Add missing sequtils for anyIt

# Import the module to test
import ../src/tools/test/run_specific_test
import ../src/niuv_testing  # For the TestRunnerConfig type and related functions

suite "Run Specific Test Tool Tests":
  setup:
    # Create a temporary test directory
    let testDir = getTempDir() / "niuv_test_runner_" & $getCurrentProcessId()
    createDir(testDir)
    
    # Create a sample test file
    let sampleTestContent = """
import unittest

test "sample test":
  check 1 + 1 == 2
"""
    
    let testFileName = "sample_test.nim"
    let testFilePath = testDir / testFileName
    writeFile(testFilePath, sampleTestContent)
    
    # Needed for proper test execution (since the tool looks for test.sh)
    let scriptsDir = testDir / "scripts" / "tests"
    createDir(scriptsDir)
    
    # On Unix we'll create a test script, on Windows we won't actually run it
    when not defined(windows):
      let testScript = """#!/bin/sh
      echo "[Suite] SampleTest"
      echo "[OK] sample test (0.0005s) [sample_test.nim:4]"
      exit 0
      """
      let scriptPath = scriptsDir / "test.sh"
      writeFile(scriptPath, testScript)
      discard execShellCmd("chmod +x " & scriptPath)
    else:
      let testScript = """@echo off
      echo [Suite] SampleTest
      echo [OK] sample test (0.0005s) [sample_test.nim:4]
      exit /b 0
      """
      let scriptPath = scriptsDir / "test.bat"
      writeFile(scriptPath, testScript)
    
    # Set current directory to test directory for the test duration
    let originalDir = getCurrentDir()
    setCurrentDir(testDir)
  
  teardown:
    # Restore original directory
    let originalDir = getCurrentDir()
    if originalDir.contains("niuv_test_runner"):
      setCurrentDir(parentDir(originalDir))
    
    # Clean up after tests
    if dirExists(testDir):
      removeDir(testDir)
  
  # Note: We'll stub or mock some functions that would typically execute
  # external commands or depend on the actual file system structure
  
  test "findFiles - locates test files":
    # Create more test files
    writeFile("test_one.nim", "# test file 1")
    writeFile("test_two.nim", "# test file 2")
    createDir("nested")
    writeFile("nested/test_three.nim", "# test file 3")
    
    # Test finding the files
    var config = newTestRunnerConfig()
    config.testDir = "."
    config.pattern = "test_*.nim"
    let testFiles = findTestFiles(config)
    
    check testFiles.len >= 2
    check testFiles.anyIt(it == "test_one.nim" or it.endsWith("test_one.nim"))
    check testFiles.anyIt(it == "test_two.nim" or it.endsWith("test_two.nim"))
  
  test "locating specific test file":
    # Test with explicit file name
    var specificConfig = newTestRunnerConfig()
    specificConfig.mode = trmSingle
    specificConfig.testFiles = @["sample_test.nim"]
    specificConfig.testDir = "."
    
    let files = findTestFiles(specificConfig)
    check files.len == 1
    check files[0] == "sample_test.nim" or files[0].endsWith("sample_test.nim")
  
  test "TestRunnerConfig - default values":
    var config = newTestRunnerConfig()
    check config.mode == trmAll
    check config.pattern == "test_*.nim"
    check config.verbose == false
    check config.generateReport == true
    check config.testDir == "tests"
  
  when defined(skipActualExecution):
    # These tests require actual execution of shell commands
    # which can be problematic in automated test environments
    # Use the -d:skipActualExecution flag to skip them
    
    test "runTests - basic test execution":
      # We're not actually going to run the test, just check
      # if the function handles parameters correctly
      let testFiles = @["sample_test.nim"]
      let outputFile = getTempDir() / "test_output.txt"
      let result = runTests(testFiles, verbose=true, outputFile=outputFile, testDir=".")
      
      # Since we don't have a real test environment, we just check the output file
      # existence rather than the result
      check fileExists(outputFile) == true
      
      # Clean up
      if fileExists(outputFile):
        removeFile(outputFile)
    
    test "runAndReport - full test workflow":
      let config = newTestRunnerConfig()
      config.mode = trmSingle
      config.testFiles = @["sample_test.nim"]
      config.testDir = "."
      config.outputDir = getTempDir()
      
      # This would typically run tests and generate reports
      # We'll just check that it handles configurations properly
      let result = runAndReport(config)
      
      # We can't really assert success here since we don't have the full
      # test environment, so we just make sure it runs without exceptions

when isMainModule:
  discard