import unittest
import std/[os, strutils, times, tables, sequtils, strtabs, json]
import ../src/utils
import ./testutils

suite "Logging Functions":
  test "should setup logging with verbose mode":
    setupLogging(true)
    # Just ensure it doesn't crash
    logDebug("Debug message")
    logInfo("Info message")
    logWarning("Warning message")
    
  test "should setup logging without verbose mode":
    setupLogging(false)
    # Just ensure it doesn't crash
    logDebug("Debug message")
    logInfo("Info message")
    logWarning("Warning message")
    
  test "should handle error logging":
    # Test error logging without crashing
    logError("Error message")

suite "Process Execution":
  setup:
    initTestEnvironment()
    
  teardown:
    cleanupTestEnvironment()
    
  test "should execute process with environment":
    var env = newStringTable()
    env["TEST_VAR"] = "test_value"
    let exitCode = execProcessEnv("echo $TEST_VAR", getCurrentDir(), env)
    when defined(windows):
      skip()  # Windows handles environment variables differently
    else:
      check exitCode == 0
    
  test "should handle process failure":
    let env = newStringTable()
    let exitCode = execProcessEnv("false", getCurrentDir(), env)
    check exitCode != 0

suite "Project Utilities":
  setup:
    initTestEnvironment()
    createDir("test_project")
    setCurrentDir("test_project")
    
  teardown:
    setCurrentDir("..")
    removeDir("test_project")
    cleanupTestEnvironment()
    
  test "should find nimble file":
    writeFile("myproject.nimble", """
version = "0.1.0"
author = "Test Author"
""")
    
    let nimbleFile = findNimbleFile()
    check nimbleFile == "myproject.nimble"
    
  test "should return empty when no nimble file":
    let nimbleFile = findNimbleFile()
    check nimbleFile == ""
    
  test "should get project name from nimble file":
    writeFile("awesome_project.nimble", """
version = "0.1.0"
author = "Test Author"
""")
    
    let projectName = getProjectName()
    check projectName == "awesome_project"
    
  test "should return empty project name when no nimble file":
    let projectName = getProjectName()
    check projectName == ""

suite "Cache Management":
  setup:
    initTestEnvironment()
    # Remove existing cache dir to test creation
    let cacheDir = getHomeDir() / ".niuv" / "cache"
    if dirExists(cacheDir):
      removeDir(cacheDir)
    
  teardown:
    cleanupTestEnvironment()
    
  test "should create cache directory":
    check createCacheDir()
    let expectedCacheDir = getHomeDir() / ".niuv" / "cache"
    check dirExists(expectedCacheDir)
    
  test "should get cached package path":
    # Create cache directory first
    discard createCacheDir()
    
    # For non-existing packages, the function returns empty string
    # Let's create a cached package first
    let cachePath = getHomeDir() / ".niuv" / "cache"
    createDir(cachePath / "testpkg-1.0.0")
    
    let path = getCachedPackagePath("testpkg", "1.0.0")
    check path.contains(".niuv/cache")
    check path.contains("testpkg-1.0.0")
    
    # Test without version - should find the versioned one
    let pathNoVersion = getCachedPackagePath("testpkg", "")
    check pathNoVersion.contains("testpkg")
    check pathNoVersion.len > 0
    
  test "should save package to cache":
    createDir("test_package")
    writeFile("test_package/file.nim", "test content")
    
    check savePackageToCache("testpkg", "1.0.0", "test_package")
    
    let cachedPath = getCachedPackagePath("testpkg", "1.0.0")
    check dirExists(cachedPath)
    check fileExists(cachedPath / "file.nim")
    
    removeDir("test_package")

suite "String Utilities":
  test "should truncate long strings":
    let longString = "a".repeat(100)
    
    let truncated = truncateString(longString, 10)
    check truncated == "a".repeat(7) & "..."
    check truncated.len == 10  # Total length including "..."
    
  test "should not truncate short strings":
    let shortString = "hello"
    let truncated = truncateString(shortString, 10)
    check truncated == shortString
    
  test "should format duration":
    check formatDuration(0.0005) == "500.00 μs"
    check formatDuration(0.5) == "500.00 ms"
    check formatDuration(1.234) == "1.23 s"
    check formatDuration(60.0) == "1 min 0. s"
    check formatDuration(125.5) == "2 min 6. s"
    check formatDuration(3665.0) == "1 h 1 min 5. s"

suite "File System Utilities":
  setup:
    initTestEnvironment()
    createDir("test_fs")
    setCurrentDir("test_fs")
    
  teardown:
    setCurrentDir("..")
    removeDir("test_fs")
    cleanupTestEnvironment()
    
  test "should ensure directory exists":
    check ensureDirExists("new_dir")
    check dirExists("new_dir")
    
    # Should return true for existing directory
    check ensureDirExists("new_dir")
    
  test "should clean build artifacts":
    # Create artifacts that cleanBuildArtifacts actually removes
    createDir("nimcache")
    writeFile("nimcache/test.c", "test")
    createDir("build")
    writeFile("build/test", "test")
    
    discard cleanBuildArtifacts(false)
    
    check not dirExists("nimcache")
    # build directory gets recreated as build/bin, so just check the old file is gone
    check not fileExists("build/test")
    check dirExists("build/bin")
    
  test "should clean all including nimbledeps":
    # Create artifacts and nimbledeps
    createDir("nimcache")
    createDir("nimbledeps")
    writeFile("nimbledeps/test.nim", "test")
    
    discard cleanAll(false)
    
    check not dirExists("nimcache")
    # nimbledeps gets recreated as nimbledeps/pkgs, so check the old file is gone
    check not fileExists("nimbledeps/test.nim")
    check dirExists("nimbledeps/pkgs")
    
  test "should safely copy directory":
    createDir("source")
    writeFile("source/file1.nim", "content1")
    createDir("source/subdir")
    writeFile("source/subdir/file2.nim", "content2")
    
    check safeCopyDir("source", "dest")
    
    check dirExists("dest")
    check fileExists("dest/file1.nim")
    check dirExists("dest/subdir")
    check fileExists("dest/subdir/file2.nim")
    
  test "should handle copy errors gracefully":
    # Try to copy non-existent directory
    check not safeCopyDir("nonexistent", "dest")

suite "Symlink Utilities":
  setup:
    initTestEnvironment()
    createDir("test_symlink")
    setCurrentDir("test_symlink")
    
  teardown:
    setCurrentDir("..")
    removeDir("test_symlink")
    cleanupTestEnvironment()
    
  test "should detect symlinks":
    when not defined(windows):
      # Create a regular file and directory
      writeFile("regular.txt", "content")
      createDir("regular_dir")
      
      check not isSymlink("regular.txt")
      check not isSymlink("regular_dir")
      
      # Create symlinks
      discard execShellCmd("ln -s regular.txt link.txt")
      discard execShellCmd("ln -s regular_dir link_dir")
      
      check isSymlink("link.txt")
      check isSymlink("link_dir")
    else:
      skip()  # Symlink detection on Windows is complex
      
  test "should resolve symlinks":
    when not defined(windows):
      writeFile("target.txt", "content")
      discard execShellCmd("ln -s target.txt link.txt")
      
      let resolved = resolveSymlink("link.txt")
      check resolved.endsWith("target.txt")
      
      # Non-symlink should return original path
      let regularResolved = resolveSymlink("target.txt")
      check regularResolved.endsWith("target.txt")
    else:
      skip()

suite "System Information":
  test "should get system info":
    let info = getSystemInfo()
    
    check info.hasKey("os")
    check info.hasKey("cpu")
    check info.hasKey("nim")
    check info.hasKey("user")
    
    # Check values are not empty
    check info["os"]["name"].getStr().len > 0
    check info["cpu"]["count"].getInt() > 0
    check info["nim"]["version"].getStr().len > 0
    check info["user"]["name"].getStr().len > 0