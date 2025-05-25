## Test file for the migrated filesystem utilities in src/utils/fs.nim

import unittest
import std/os
import std/strutils
import std/times
import std/sequtils
import std/sets

# Import the module to test with a qualified name to avoid conflicts
import ../src/utils/fs as fsutils

suite "File System Utilities Tests":
  setup:
    # Create a temporary test directory
    let testDir = getTempDir() / "niuv_test_fs_" & $getTime().toUnix()
    createDir(testDir)
  
  teardown:
    # Clean up after tests
    if dirExists(testDir):
      removeDir(testDir)
  
  test "ensureDirExists - existing directory":
    # Test that existing directory returns true
    check fsutils.ensureDirExists(testDir) == true
  
  test "ensureDirExists - new directory":
    # Test that new directory is created
    let newDir = testDir / "new_dir"
    check fsutils.ensureDirExists(newDir) == true
    check dirExists(newDir) == true
  
  test "ensureDirExists - empty path":
    # Test that empty path returns false
    check fsutils.ensureDirExists("") == false
  
  test "removeIfExists - existing file":
    # Create a test file
    let testFile = testDir / "test_file.txt"
    writeFile(testFile, "test content")
    check fileExists(testFile) == true
    
    # Test removal
    check fsutils.removeIfExists(testFile) == true
    check fileExists(testFile) == false
  
  test "removeIfExists - existing directory":
    # Create a test directory
    let nestedDir = testDir / "nested_dir"
    createDir(nestedDir)
    check dirExists(nestedDir) == true
    
    # Test removal
    check fsutils.removeIfExists(nestedDir) == true
    check dirExists(nestedDir) == false
  
  test "removeIfExists - non-existent path":
    # Test removal of non-existent path
    let nonExistentPath = testDir / "does_not_exist"
    check fsutils.removeIfExists(nonExistentPath) == true
  
  test "cleanDirectory - empty directory":
    # Create an empty dir
    let emptyDir = testDir / "empty_dir"
    createDir(emptyDir)
    
    # Test cleaning
    check fsutils.cleanDirectory(emptyDir) == true
    check dirExists(emptyDir) == true  # should still exist
  
  test "cleanDirectory - directory with contents":
    # Create a dir with content
    let contentDir = testDir / "content_dir"
    createDir(contentDir)
    writeFile(contentDir / "file1.txt", "content1")
    writeFile(contentDir / "file2.txt", "content2")
    createDir(contentDir / "subdir")
    
    # Test cleaning
    check fsutils.cleanDirectory(contentDir) == true
    check dirExists(contentDir) == true  # should still exist
    check fileExists(contentDir / "file1.txt") == false
    check fileExists(contentDir / "file2.txt") == false
    check dirExists(contentDir / "subdir") == false
  
  test "cleanDirectory - non-existent directory":
    # Test cleaning non-existent dir
    let nonExistentDir = testDir / "non_existent_dir"
    check fsutils.cleanDirectory(nonExistentDir) == true
  
  test "findFiles - simple pattern":
    # Create test files
    writeFile(testDir / "test1.txt", "content1")
    writeFile(testDir / "test2.txt", "content2")
    writeFile(testDir / "other.log", "log content")
    
    # Test finding files
    let txtFiles = fsutils.findFiles(testDir, "*.txt")
    check txtFiles.len == 2
    check txtFiles.anyIt(it.endsWith("test1.txt"))
    check txtFiles.anyIt(it.endsWith("test2.txt"))
    
    let logFiles = fsutils.findFiles(testDir, "*.log")
    check logFiles.len == 1
    check logFiles.anyIt(it.endsWith("other.log"))
  
  test "findFiles - recursive search":
    # Create nested directory structure
    let subDir = testDir / "subdir"
    createDir(subDir)
    writeFile(testDir / "root.txt", "root")
    writeFile(subDir / "sub.txt", "sub")
    
    # Test recursive search
    let allTxtFiles = fsutils.findFiles(testDir, "*.txt", recursive=true)
    check allTxtFiles.len == 2
    check allTxtFiles.anyIt(it.endsWith("root.txt"))
    check allTxtFiles.anyIt(it.endsWith("sub.txt"))
    
    # Test non-recursive search
    let rootTxtFiles = fsutils.findFiles(testDir, "*.txt", recursive=false)
    check rootTxtFiles.len == 1
    check rootTxtFiles.anyIt(it.endsWith("root.txt"))
  
  test "findDirs - simple pattern":
    # Create test directories
    createDir(testDir / "test_dir1")
    createDir(testDir / "test_dir2")
    createDir(testDir / "other_dir")
    
    # Test finding directories
    let testDirs = fsutils.findDirs(testDir, "test_*")
    check testDirs.len == 2
    check testDirs.anyIt(it.endsWith("test_dir1"))
    check testDirs.anyIt(it.endsWith("test_dir2"))
    
    let otherDirs = fsutils.findDirs(testDir, "other_*")
    check otherDirs.len == 1
    check otherDirs.anyIt(it.endsWith("other_dir"))
  
  test "copyDir - simple copy":
    # Create source directory with content
    let sourceDir = testDir / "source_dir"
    let targetDir = testDir / "target_dir"
    createDir(sourceDir)
    writeFile(sourceDir / "file1.txt", "content1")
    createDir(sourceDir / "subdir")
    writeFile(sourceDir / "subdir/file2.txt", "content2")
    
    # Test copying
    check fsutils.copyDir(sourceDir, targetDir) == true
    check dirExists(targetDir) == true
    check fileExists(targetDir / "file1.txt") == true
    check dirExists(targetDir / "subdir") == true
    check fileExists(targetDir / "subdir/file2.txt") == true
  
  test "getFileModificationTime - existing file":
    # Create a test file
    let testFile = testDir / "mod_time_test.txt"
    writeFile(testFile, "test content")
    
    # Test getting modification time
    let modTime = fsutils.getFileModificationTime(testFile)
    check modTime > 0  # Should be a positive timestamp
  
  test "getFileModificationTime - non-existent file":
    # Test non-existent file
    let nonExistentFile = testDir / "does_not_exist.txt"
    let modTime = fsutils.getFileModificationTime(nonExistentFile)
    check modTime == 0  # Should return 0 for non-existent file
  
  test "isFileMatch - exact match":
    var exactSet = initHashSet[string]()
    exactSet.incl("test.txt")
    check fsutils.isFileMatch("test.txt", exactSet) == true
    
    var otherSet = initHashSet[string]()
    otherSet.incl("other.txt")
    check fsutils.isFileMatch("test.txt", otherSet) == false
  
  test "isFileMatch - wildcard match":
    var txtSet = initHashSet[string]()
    txtSet.incl("*.txt")
    check fsutils.isFileMatch("test.txt", txtSet) == true
    check fsutils.isFileMatch("test.log", txtSet) == false
    
    var testSet = initHashSet[string]()
    testSet.incl("test.*")
    check fsutils.isFileMatch("test.txt", testSet) == true
    check fsutils.isFileMatch("other.txt", testSet) == false

  test "isFileMatch - pattern matching":
    var patternSet = initHashSet[string]()
    patternSet.incl("test*file.txt")
    
    check fsutils.isFileMatch("testfile.txt", patternSet) == true
    check fsutils.isFileMatch("test_my_file.txt", patternSet) == true
    check fsutils.isFileMatch("file.txt", patternSet) == false
    
  test "isSymlink - regular files and directories":
    # Create regular file and directory
    let regularFile = testDir / "regular.txt"
    let regularDir = testDir / "regular_dir"
    
    writeFile(regularFile, "content")
    createDir(regularDir)
    
    check fsutils.isSymlink(regularFile) == false
    check fsutils.isSymlink(regularDir) == false
    
    # Test non-existent path
    check fsutils.isSymlink(testDir / "nonexistent") == false
    
    # Test empty path
    check fsutils.isSymlink("") == false
    
  test "isSymlink - symbolic links":
    when not defined(windows):
      let targetFile = testDir / "target.txt"
      let linkFile = testDir / "link.txt"
      
      writeFile(targetFile, "content")
      discard execShellCmd("ln -s " & targetFile & " " & linkFile)
      
      check fsutils.isSymlink(linkFile) == true
    else:
      skip()  # Windows symlink handling is complex
      
  test "resolveSymlink - regular file":
    let regularFile = testDir / "regular.txt"
    writeFile(regularFile, "content")
    
    let resolved = fsutils.resolveSymlink(regularFile)
    check resolved == regularFile
    
  test "resolveSymlink - symbolic link":
    when not defined(windows):
      let targetFile = testDir / "target.txt"
      let linkFile = testDir / "link.txt"
      
      writeFile(targetFile, "content")
      discard execShellCmd("ln -s " & targetFile & " " & linkFile)
      
      let resolved = fsutils.resolveSymlink(linkFile)
      check resolved.endsWith("target.txt")
    else:
      skip()
      
  test "resolveSymlink - non-existent path":
    let nonExistent = testDir / "nonexistent"
    let resolved = fsutils.resolveSymlink(nonExistent)
    check resolved == nonExistent
    
  test "copyDir - non-existent source":
    let sourceDir = testDir / "nonexistent_source"
    let targetDir = testDir / "target"
    
    check fsutils.copyDir(sourceDir, targetDir) == false
    
  test "logWarning and logError":
    # Just ensure these don't crash
    fsutils.logWarning("Test warning message")
    fsutils.logError("Test error message")
    
    # These functions just log, so we just verify they execute
    check true
    
when isMainModule:
  discard