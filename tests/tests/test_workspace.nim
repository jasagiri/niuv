import std/unittest

import unittest
import ../src/workspace
import ../src/resolver  # For VersionConstraint
import std/[os, tables, sequtils, strutils]
import std/tempfiles

suite "Workspace configuration":
  test "Parse workspace config":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let configContent = """
[workspace]
members = ["packages/*", "tools/*"]
exclude = ["packages/deprecated"]

[workspace.dependencies]
jester = ">= 0.5.0"
chronicles = "^0.10.0"

[workspace.devDependencies]
testament = "*"
"""
    
    let configPath = tempDir / "niuv.workspace.toml"
    writeFile(configPath, configContent)
    
    let config = parseWorkspaceConfig(configPath)
    
    check config.members.len == 2
    check "packages/*" in config.members
    check "tools/*" in config.members
    check config.exclude.len == 1
    check "packages/deprecated" in config.exclude
    check config.dependencies["jester"] == ">= 0.5.0"
    check config.dependencies["chronicles"] == "^0.10.0"
    check config.devDependencies["testament"] == "*"

  test "Find workspace root":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create workspace structure
    let workspaceFile = tempDir / "niuv.workspace.toml"
    writeFile(workspaceFile, "[workspace]\nmembers = []")
    
    let subDir = tempDir / "packages" / "pkg1"
    createDir(subDir)
    
    # Test finding from subdirectory
    let root = findWorkspaceRoot(subDir)
    check root == tempDir
    
    # Test not finding workspace
    let noWorkspace = createTempDir("niuv_test_no_ws_", "")
    defer: removeDir(noWorkspace)
    
    let notFound = findWorkspaceRoot(noWorkspace)
    check notFound == ""

suite "Workspace package discovery":
  test "Discover packages with glob patterns":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create workspace structure
    createDir(tempDir / "packages" / "pkg1")
    createDir(tempDir / "packages" / "pkg2")
    createDir(tempDir / "tools" / "tool1")
    createDir(tempDir / "packages" / "deprecated")
    
    # Create nimble files
    writeFile(tempDir / "packages" / "pkg1" / "pkg1.nimble", """
version = "0.1.0"
author = "Test"
description = "Package 1"
""")
    
    writeFile(tempDir / "packages" / "pkg2" / "pkg2.nimble", """
version = "0.2.0"
author = "Test"
description = "Package 2"
""")
    
    writeFile(tempDir / "tools" / "tool1" / "tool1.nimble", """
version = "0.3.0"
author = "Test"
description = "Tool 1"
""")
    
    writeFile(tempDir / "packages" / "deprecated" / "old.nimble", """
version = "0.0.1"
author = "Test"
description = "Deprecated"
""")
    
    # Create workspace config
    writeFile(tempDir / "niuv.workspace.toml", """
[workspace]
members = ["packages/*", "tools/*"]
exclude = ["packages/deprecated"]
""")
    
    let workspace = loadWorkspace(tempDir)
    let packages = workspace.packages
    
    check packages.len == 3
    check packages.anyIt(it.name == "pkg1" and it.version == "0.1.0")
    check packages.anyIt(it.name == "pkg2" and it.version == "0.2.0")
    check packages.anyIt(it.name == "tool1" and it.version == "0.3.0")
    check not packages.anyIt(it.name == "old")

suite "Dependency graph":
  test "Build dependency graph":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(
          name: "pkg1",
          path: "/test/pkg1",
          version: "1.0.0",
          dependencies: toTable({"pkg2": newSeq[VersionConstraint]()}),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        ),
        WorkspacePackage(
          name: "pkg2",
          path: "/test/pkg2",
          version: "1.0.0",
          dependencies: toTable({"pkg3": newSeq[VersionConstraint]()}),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        ),
        WorkspacePackage(
          name: "pkg3",
          path: "/test/pkg3",
          version: "1.0.0",
          dependencies: initTable[string, seq[VersionConstraint]](),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        )
      ]
    )
    
    workspace.buildDependencyGraph()
    
    check workspace.graph["pkg1"] == @["pkg2"]
    check workspace.graph["pkg2"] == @["pkg3"]
    check workspace.graph["pkg3"].len == 0

  test "Topological sort":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(name: "app", path: "/test/app"),
        WorkspacePackage(name: "lib1", path: "/test/lib1"),
        WorkspacePackage(name: "lib2", path: "/test/lib2"),
        WorkspacePackage(name: "base", path: "/test/base")
      ],
      graph: toTable({
        "app": @["lib1", "lib2"],
        "lib1": @["base"],
        "lib2": @["base"],
        "base": newSeq[string]()
      })
    )
    
    let order = workspace.topologicalSort()
    
    check order.len == 4
    # base should come before lib1 and lib2
    check order.find("base") < order.find("lib1")
    check order.find("base") < order.find("lib2")
    # lib1 and lib2 should come before app
    check order.find("lib1") < order.find("app")
    check order.find("lib2") < order.find("app")

  test "Circular dependency detection":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(name: "pkg1", path: "/test/pkg1"),
        WorkspacePackage(name: "pkg2", path: "/test/pkg2")
      ],
      graph: toTable({
        "pkg1": @["pkg2"],
        "pkg2": @["pkg1"]
      })
    )
    
    expect WorkspaceError:
      discard workspace.topologicalSort()

suite "Workspace operations":
  test "Create workspace config":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let success = createWorkspaceConfig(tempDir, @["packages/*", "apps/*"])
    check success
    
    let configPath = tempDir / "niuv.workspace.toml"
    check fileExists(configPath)
    
    let content = readFile(configPath)
    check content.contains("members = \"packages/*\", \"apps/*\"")
    check content.contains("[workspace.dependencies]")
    check content.contains("[workspace.devDependencies]")
    
    # Should not overwrite existing
    let again = createWorkspaceConfig(tempDir, @["other/*"])
    check not again