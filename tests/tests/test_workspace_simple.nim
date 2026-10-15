import std/unittest

import unittest
import ../src/workspace
import ../src/resolver
import std/[os, tables, tempfiles]

suite "Workspace Core Functions":
  test "Parse workspace config - all fields":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let configContent = """
[workspace]
members = ["packages/*", "tools/*"]
exclude = ["packages/deprecated"]

[workspace.dependencies]
jester = ">= 0.5.0"

[workspace.devDependencies]
testament = "*"
"""
    
    let configPath = tempDir / "niuv.workspace.toml"
    writeFile(configPath, configContent)
    
    let config = parseWorkspaceConfig(configPath)
    
    check config.members == @["packages/*", "tools/*"]
    check config.exclude == @["packages/deprecated"]
    check config.dependencies["jester"] == ">= 0.5.0"
    check config.devDependencies["testament"] == "*"

  test "Find workspace root":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    writeFile(tempDir / "niuv.workspace.toml", "[workspace]")
    let subDir = tempDir / "sub"
    createDir(subDir)
    
    check findWorkspaceRoot(subDir) == tempDir
    check findWorkspaceRoot(tempDir) == tempDir
    check findWorkspaceRoot("/nonexistent") == ""

  test "Load workspace package":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    writeFile(tempDir / "test.nimble", """
# Package
version = "1.0.0"
author = "Test"
description = "Test"

# Dependencies
requires "nim >= 1.6.0"
""")
    
    let pkg = loadWorkspacePackage(tempDir)
    check pkg.name == "test"
    check pkg.version == "1.0.0"
    check pkg.path == tempDir

  test "Build dependency graph":
    let ws = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(
          name: "a",
          dependencies: toTable({"b": newSeq[VersionConstraint]()})
        ),
        WorkspacePackage(
          name: "b",
          dependencies: initTable[string, seq[VersionConstraint]]()
        )
      ]
    )
    
    ws.buildDependencyGraph()
    
    check ws.graph["a"] == @["b"]
    check ws.graph["b"].len == 0

  test "Topological sort":
    let ws = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(name: "a"),
        WorkspacePackage(name: "b")
      ],
      graph: toTable({
        "a": @["b"],
        "b": newSeq[string]()
      })
    )
    
    let order = ws.topologicalSort()
    # Since "a" depends on "b", "b" should come first
    check "b" in order
    check "a" in order
    check order.find("b") < order.find("a")  # b comes before a

  test "Create workspace config":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    check createWorkspaceConfig(tempDir, @["packages/*"])
    check fileExists(tempDir / "niuv.workspace.toml")
    
    # Should not overwrite
    check not createWorkspaceConfig(tempDir, @["other/*"])

suite "Workspace Integration":
  test "Full workspace workflow":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create workspace config
    writeFile(tempDir / "niuv.workspace.toml", """
[workspace]
members = ["packages/*"]
""")
    
    # Create package
    createDir(tempDir / "packages" / "test")
    writeFile(tempDir / "packages" / "test" / "test.nimble", """
# Package
version = "1.0.0"
author = "Test"
description = "Test"

# Dependencies
requires "nim >= 1.6.0"
""")
    
    # Load workspace
    let ws = loadWorkspace(tempDir)
    
    check ws.root == tempDir
    check ws.packages.len == 1
    check ws.packages[0].name == "test"
    
    # Build graph
    ws.buildDependencyGraph()
    check ws.graph.hasKey("test")
    
    # Sort (trivial case)
    let order = ws.topologicalSort()
    check order == @["test"]

suite "Error Handling":
  test "Parse missing config":
    expect WorkspaceError:
      discard parseWorkspaceConfig("/nonexistent.toml")
  
  test "Load package without nimble":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    expect WorkspaceError:
      discard loadWorkspacePackage(tempDir)
  
  test "Circular dependency":
    let ws = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(name: "a"),
        WorkspacePackage(name: "b")
      ],
      graph: toTable({
        "a": @["b"],
        "b": @["a"]
      })
    )
    
    expect WorkspaceError:
      discard ws.topologicalSort()
  
  test "Load workspace without config":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    expect WorkspaceError:
      discard loadWorkspace(tempDir)