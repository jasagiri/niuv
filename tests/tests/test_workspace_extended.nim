import std/unittest

import std/[unittest, os, tables, sequtils, tempfiles]
import ../src/workspace
import ../src/resolver

suite "Extended Workspace Tests":
  
  test "Expand glob patterns - single level wildcards":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create directory structure
    createDir(tempDir / "pkg1")
    createDir(tempDir / "pkg2")
    createDir(tempDir / "other")
    
    # Test * pattern
    let paths = expandGlobPatterns(@["pkg*"], tempDir, @[])
    check paths.len == 2
    check (tempDir / "pkg1") in paths
    check (tempDir / "pkg2") in paths
    check (tempDir / "other") notin paths
  
  test "Expand glob patterns - empty and invalid":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Empty patterns
    let empty = expandGlobPatterns(@[], tempDir, @[])
    check empty.len == 0
    
    # Pattern that matches nothing
    let noMatch = expandGlobPatterns(@["nonexistent/*"], tempDir, @[])
    check noMatch.len == 0
  
  test "Expand glob patterns - mixed literal and glob":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    createDir(tempDir / "literal")
    createDir(tempDir / "packages" / "pkg1")
    createDir(tempDir / "packages" / "pkg2")
    
    let paths = expandGlobPatterns(@["literal", "packages/*"], tempDir, @[])
    check paths.len == 3
    check (tempDir / "literal") in paths
    check (tempDir / "packages" / "pkg1") in paths
  
  test "Parse workspace config - dot notation":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let configContent = """
[workspace]
members = ["packages/*"]

["workspace.dependencies"]
jester = ">=0.5.0"
chronicles = "0.10.0"

["workspace.devDependencies"]
testament = ">=0.1.0"
"""
    
    let configPath = tempDir / "niuv.workspace.toml"
    writeFile(configPath, configContent)
    
    let config = parseWorkspaceConfig(configPath)
    check config.members == @["packages/*"]
    check config.dependencies["jester"] == ">=0.5.0"
    check config.dependencies["chronicles"] == "0.10.0"
    check config.devDependencies["testament"] == ">=0.1.0"
  
  test "Load workspace package - multiple nimble files":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create multiple nimble files (order not guaranteed)
    writeFile(tempDir / "first.nimble", """
version = "1.0.0"
author = "Test"
description = "First"
""")
    
    writeFile(tempDir / "second.nimble", """
version = "2.0.0"
author = "Test"
description = "Second"
""")
    
    let pkg = loadWorkspacePackage(tempDir)
    # Should use one of the files
    check pkg.name in ["first", "second"]
    check pkg.version in ["1.0.0", "2.0.0"]
  
  test "Load workspace package - malformed version":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    writeFile(tempDir / "test.nimble", """
version = "not.a.version!"
author = "Test"
description = "Test"
""")
    
    let pkg = loadWorkspacePackage(tempDir)
    check pkg.name == "test"
    check pkg.version == "not.a.version!"  # Should preserve as-is
  
  test "Workspace with simple exclusions":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create structure
    createDir(tempDir / "packages" / "public")
    createDir(tempDir / "packages" / "private")
    createDir(tempDir / "tools" / "build")
    
    # Create nimble files
    for dir in ["public", "private"]:
      writeFile(tempDir / "packages" / dir / (dir & ".nimble"), """
version = "1.0.0"
author = "Test"
description = "Test"
""")
    
    writeFile(tempDir / "tools" / "build" / "build.nimble", """
version = "1.0.0"
author = "Test"
description = "Build tool"
""")
    
    # Workspace config with literal exclusions (glob exclusions not yet implemented)
    writeFile(tempDir / "niuv.workspace.toml", """
[workspace]
members = ["packages/*", "tools/*"]
exclude = ["packages/private"]
""")
    
    let ws = loadWorkspace(tempDir)
    check ws.packages.len == 2  # Only public and build
    check ws.packages.anyIt(it.name == "public")
    check ws.packages.anyIt(it.name == "build")
    check not ws.packages.anyIt(it.name == "private")
  
  test "Dependency graph with workspace dependencies":
    let ws = Workspace(
      root: "/test",
      config: WorkspaceConfig(
        dependencies: toTable({"shared": ">=1.0.0"})
      ),
      packages: @[
        WorkspacePackage(
          name: "a",
          dependencies: toTable({"b": @[VersionConstraint(operator: ">=", version: Version(major: 1))]})
        ),
        WorkspacePackage(
          name: "b",
          dependencies: toTable({"shared": @[VersionConstraint(operator: ">=", version: Version(major: 1))]})
        )
      ]
    )
    
    ws.buildDependencyGraph()
    check ws.graph["a"] == @["b"]
    check ws.graph["b"].len == 0  # shared is external
  
  test "Find workspace root - permission denied":
    # This test is tricky to implement portably
    # We'll test the case where we reach the root
    let root = findWorkspaceRoot("/")
    check root == ""  # No workspace file at filesystem root
  
  test "Glob pattern with special regex chars":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create directory with special chars (if filesystem allows)
    let specialDir = tempDir / "test[1]"
    createDir(specialDir)
    
    # Pattern with brackets should be escaped
    let paths = expandGlobPatterns(@["test[1]"], tempDir, @[])
    check paths.len == 1
    check paths[0] == specialDir
  
  test "Empty workspace root discovery":
    # Test when current directory is used
    let origDir = getCurrentDir()
    let tempDir = createTempDir("niuv_test_", "")
    defer: 
      setCurrentDir(origDir)
      removeDir(tempDir)
    
    setCurrentDir(tempDir)
    writeFile("niuv.workspace.toml", "[workspace]\nmembers = []")
    
    let ws = loadWorkspace()  # No root specified
    check ws.root == tempDir
  
  test "Version parsing edge cases":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Test various version formats
    writeFile(tempDir / "test.nimble", """
version = "1.2.3"
author = "Test"
""")
    
    let pkg = loadWorkspacePackage(tempDir)
    check pkg.version == "1.2.3"
  
  test "Workspace with no graph entries":
    let ws = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(name: "orphan")
      ]
    )
    
    ws.buildDependencyGraph()
    let sorted = ws.topologicalSort()
    check sorted == @["orphan"]