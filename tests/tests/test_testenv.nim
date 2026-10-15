import std/unittest

## Test TestEnv Module

import std/[unittest, os, json]
import ../src/testenv

suite "TestEnv Module Tests":
  setup:
    # Clean up any existing test environment
    let envDir = "tests/fixtures/testenv"
    if dirExists(envDir):
      removeDir(envDir)
  
  teardown:
    # Clean up after tests
    let envDir = "tests/fixtures/testenv"
    if dirExists(envDir):
      removeDir(envDir)
  
  test "initTestEnv creates test environment directory":
    let envDir = "tests/fixtures/testenv"
    
    check not dirExists(envDir)
    
    initTestEnv()
    
    check dirExists(envDir)
    
  test "initTestEnv creates config file":
    let configFile = "tests/fixtures/testenv/nim.cfg"
    
    initTestEnv()
    
    check fileExists(configFile)
    
    # Check content
    let content = readFile(configFile)
    check content.contains("Test environment configuration")
    check content.contains("--path:../src")
    check content.contains("--path:../test")
    check content.contains("--path:../testenv")
    
  test "initTestEnv creates JSON config":
    let configJson = "tests/fixtures/testenv/.niuv.json"
    
    initTestEnv()
    
    check fileExists(configJson)
    
    # Parse and validate JSON
    let jsonContent = readFile(configJson)
    let jsonData = parseJson(jsonContent)
    
    check jsonData["nimVersion"].getStr() == "2.2.4"
    check jsonData["projectName"].getStr() == "test_project"
    check jsonData["parallelJobs"].getInt() == 4
    check jsonData["verbose"].getBool() == true
    
  test "initTestEnv creates test marker":
    let testMarker = "tests/fixtures/testenv/test_marker"
    
    initTestEnv()
    
    check fileExists(testMarker)
    
    let content = readFile(testMarker)
    check content == "Test environment initialized successfully"
    
  test "initTestEnv is idempotent":
    # First initialization
    initTestEnv()
    
    let configFile = "tests/fixtures/testenv/nim.cfg"
    let originalContent = readFile(configFile)
    let originalModTime = getLastModificationTime(configFile)
    
    # Sleep to ensure time difference if file is modified
    sleep(100)
    
    # Second initialization
    initTestEnv()
    
    # Files should not be recreated
    let newContent = readFile(configFile)
    let newModTime = getLastModificationTime(configFile)
    
    check originalContent == newContent
    check originalModTime == newModTime
    
  test "initTestEnv handles partial environment":
    let envDir = "tests/fixtures/testenv"
    let configFile = "tests/fixtures/testenv/nim.cfg"
    
    # Create directory but not files
    createDir(envDir)
    
    check dirExists(envDir)
    check not fileExists(configFile)
    
    # Should create missing files
    initTestEnv()
    
    check fileExists(configFile)
    check fileExists("tests/fixtures/testenv/.niuv.json")
    check fileExists("tests/fixtures/testenv/test_marker")
    
  test "initTestEnv preserves existing files":
    let envDir = "tests/fixtures/testenv"
    let configFile = "tests/fixtures/testenv/nim.cfg"
    
    # Create directory and custom config
    createDir(envDir)
    writeFile(configFile, "# Custom config\n--custom:option")
    
    # Run init
    initTestEnv()
    
    # Original file should be preserved
    let content = readFile(configFile)
    check content == "# Custom config\n--custom:option"
    
  test "initTestEnv creates nested directories":
    # Ensure parent directories exist
    let fixturesDir = "tests/fixtures"
    if not dirExists(fixturesDir):
      createDir(fixturesDir)
    
    initTestEnv()
    
    check dirExists("tests/fixtures/testenv")