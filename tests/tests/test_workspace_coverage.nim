import std/unittest

import unittest
import ../src/workspace
import ../src/resolver
import ../src/cli
import std/[os, tables, sequtils, strutils, tempfiles]

# Mock functions for testing
var mockInstallCalled = false
var mockInstallPackageName = ""
var mockInstallPackageVersion = ""

proc mockInstallPackage(name: string, version: string, verbose: bool): bool =
  mockInstallCalled = true
  mockInstallPackageName = name
  mockInstallPackageVersion = version
  return true

suite "Workspace Configuration Parsing":
  test "Parse empty workspace config":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let configContent = """
[workspace]
"""
    
    let configPath = tempDir / "niuv.workspace.toml"
    writeFile(configPath, configContent)
    
    let config = parseWorkspaceConfig(configPath)
    
    check config.members.len == 0
    check config.exclude.len == 0
    check config.dependencies.len == 0
    check config.devDependencies.len == 0

  test "Parse workspace config with all sections":
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

  test "Parse workspace config - file not found":
    expect WorkspaceError:
      discard parseWorkspaceConfig("/nonexistent/file.toml")

  test "Parse workspace config with non-array members":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let configContent = """
[workspace]
members = "invalid"
"""
    
    let configPath = tempDir / "niuv.workspace.toml"
    writeFile(configPath, configContent)
    
    let config = parseWorkspaceConfig(configPath)
    check config.members.len == 0

  test "Parse workspace config with non-table dependencies":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let configContent = """
[workspace.dependencies]
invalid = ["array"]
"""
    
    let configPath = tempDir / "niuv.workspace.toml"
    writeFile(configPath, configContent)
    
    # This should not crash, just skip invalid entries
    let config = parseWorkspaceConfig(configPath)
    check config.dependencies.len == 0

suite "Workspace Root Finding":
  test "Find workspace root from nested directory":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create nested structure
    let workspaceFile = tempDir / "niuv.workspace.toml"
    writeFile(workspaceFile, "[workspace]\nmembers = []")
    
    let deepDir = tempDir / "a" / "b" / "c" / "d"
    createDir(deepDir)
    
    # Test finding from deep directory
    let root = findWorkspaceRoot(deepDir)
    check root == tempDir

  test "Find workspace root - not found returns empty":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let root = findWorkspaceRoot(tempDir)
    check root == ""

  test "Find workspace root at filesystem root":
    # Test edge case where we reach filesystem root
    let root = findWorkspaceRoot("/")
    check root == ""

suite "Workspace Package Discovery (Integration)":
  test "Discover packages with glob patterns":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create workspace structure
    createDir(tempDir / "packages" / "pkg1")
    createDir(tempDir / "packages" / "pkg2") 
    createDir(tempDir / "packages" / "excluded")
    createDir(tempDir / "tools" / "tool1")
    
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
    
    writeFile(tempDir / "packages" / "excluded" / "excluded.nimble", """
version = "0.0.1"
author = "Test"
description = "Excluded"
""")
    
    writeFile(tempDir / "tools" / "tool1" / "tool1.nimble", """
version = "0.3.0"
author = "Test"
description = "Tool 1"
""")
    
    # Create workspace config
    writeFile(tempDir / "niuv.workspace.toml", """
[workspace]
members = ["packages/*", "tools/*"]
exclude = ["packages/excluded"]
""")
    
    let workspace = loadWorkspace(tempDir)
    let packages = workspace.packages
    
    check packages.len == 3
    check packages.anyIt(it.name == "pkg1" and it.version == "0.1.0")
    check packages.anyIt(it.name == "pkg2" and it.version == "0.2.0")
    check packages.anyIt(it.name == "tool1" and it.version == "0.3.0")
    check not packages.anyIt(it.name == "excluded")

suite "Workspace Package Loading":
  test "Load package from directory":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let pkgDir = tempDir / "testpkg"
    createDir(pkgDir)
    
    writeFile(pkgDir / "testpkg.nimble", """
version = "1.2.3"
author = "Test Author"
description = "Test Package"
requires "nim >= 2.0.0"
""")
    
    let pkg = loadWorkspacePackage(pkgDir)
    
    check pkg.name == "testpkg"
    check pkg.path == pkgDir
    check pkg.version == "1.2.3"

  test "Load package - no nimble file":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    expect WorkspaceError:
      discard loadWorkspacePackage(tempDir)

  test "Load package - empty nimble file":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    writeFile(tempDir / "empty.nimble", "")
    
    # Empty nimble file should still work, using defaults
    let pkg = loadWorkspacePackage(tempDir)
    check pkg.name == "empty"
    check pkg.version == "0.1.0"  # Default version

suite "Workspace Discovery":
  test "Discover packages in workspace":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create workspace structure
    createDir(tempDir / "packages" / "pkg1")
    createDir(tempDir / "packages" / "pkg2")
    createDir(tempDir / "tools" / "tool1")
    createDir(tempDir / "packages" / "no-nimble")  # Should be skipped
    
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
    
    let workspace = Workspace(
      root: tempDir,
      config: WorkspaceConfig(
        members: @["packages/*", "tools/*"],
        exclude: @[],
        dependencies: initTable[string, string](),
        devDependencies: initTable[string, string]()
      )
    )
    
    let packages = workspace.discoverPackages()
    
    check packages.len == 3
    check packages.anyIt(it.name == "pkg1" and it.version == "0.1.0")
    check packages.anyIt(it.name == "pkg2" and it.version == "0.2.0")
    check packages.anyIt(it.name == "tool1" and it.version == "0.3.0")

suite "Dependency Graph Building":
  test "Build simple dependency graph":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(
          name: "app",
          path: "/test/app",
          version: "1.0.0",
          dependencies: toTable({
            "lib1": newSeq[VersionConstraint](),
            "external": newSeq[VersionConstraint]()
          }),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        ),
        WorkspacePackage(
          name: "lib1",
          path: "/test/lib1",
          version: "1.0.0",
          dependencies: initTable[string, seq[VersionConstraint]](),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        )
      ]
    )
    
    workspace.buildDependencyGraph()
    
    check workspace.graph["app"] == @["lib1"]
    check workspace.graph["lib1"].len == 0

suite "Topological Sorting":
  test "Sort empty graph":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[],
      graph: initTable[string, seq[string]]()
    )
    
    let order = workspace.topologicalSort()
    check order.len == 0

  test "Sort single package":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(name: "pkg", path: "/test/pkg")
      ],
      graph: toTable({
        "pkg": newSeq[string]()
      })
    )
    
    let order = workspace.topologicalSort()
    check order == @["pkg"]

  test "Sort complex dependency graph":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(name: "a", path: "/test/a"),
        WorkspacePackage(name: "b", path: "/test/b"),
        WorkspacePackage(name: "c", path: "/test/c"),
        WorkspacePackage(name: "d", path: "/test/d"),
        WorkspacePackage(name: "e", path: "/test/e")
      ],
      graph: toTable({
        "a": @["b", "c"],
        "b": @["d"],
        "c": @["d", "e"],
        "d": newSeq[string](),
        "e": newSeq[string]()
      })
    )
    
    let order = workspace.topologicalSort()
    
    check order.len == 5
    # Check dependencies come before dependents
    check order.find("d") < order.find("b")
    check order.find("d") < order.find("c")
    check order.find("b") < order.find("a")
    check order.find("c") < order.find("a")
    check order.find("e") < order.find("c")

  test "Detect circular dependency":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(name: "a", path: "/test/a"),
        WorkspacePackage(name: "b", path: "/test/b"),
        WorkspacePackage(name: "c", path: "/test/c")
      ],
      graph: toTable({
        "a": @["b"],
        "b": @["c"],
        "c": @["a"]
      })
    )
    
    expect WorkspaceError:
      discard workspace.topologicalSort()

suite "Workspace Loading":
  test "Load workspace from directory":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create workspace config
    writeFile(tempDir / "niuv.workspace.toml", """
[workspace]
members = ["pkg"]
""")
    
    # Create package
    createDir(tempDir / "pkg")
    writeFile(tempDir / "pkg" / "pkg.nimble", """
version = "1.0.0"
author = "Test"
description = "Test"
""")
    
    let ws = loadWorkspace(tempDir)
    
    check ws.root == tempDir
    check ws.config.members == @["pkg"]
    check ws.packages.len == 1
    check ws.packages[0].name == "pkg"

  test "Load workspace - not found":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    expect WorkspaceError:
      discard loadWorkspace(tempDir)

  test "Load workspace - auto find root":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create workspace
    writeFile(tempDir / "niuv.workspace.toml", """
[workspace]
members = []
""")
    
    # Create subdirectory
    let subDir = tempDir / "sub"
    createDir(subDir)
    
    # Change to subdirectory
    let oldDir = getCurrentDir()
    setCurrentDir(subDir)
    defer: setCurrentDir(oldDir)
    
    let ws = loadWorkspace()
    check ws.root == tempDir

suite "Workspace Dependency Resolution":
  test "Resolve workspace dependencies":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(
        dependencies: toTable({
          "jester": ">= 0.5.0",
          "chronicles": "^0.10.0"
        }),
        devDependencies: initTable[string, string]()
      ),
      packages: @[
        WorkspacePackage(
          name: "pkg1",
          path: "/test/pkg1",
          version: "1.0.0",
          dependencies: toTable({
            "pkg2": newSeq[VersionConstraint](),
            "external": @[parseConstraint(">= 1.0.0")]
          }),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        ),
        WorkspacePackage(
          name: "pkg2",
          path: "/test/pkg2",
          version: "1.0.0",
          dependencies: initTable[string, seq[VersionConstraint]](),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        )
      ]
    )
    
    # This will fail because no packages are in the resolver cache
    # but it tests the dependency collection logic
    let result = workspace.resolveWorkspaceDependencies()
    check not result.success  # Expected to fail without package metadata

suite "Workspace Operations":
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

  test "Create workspace config - already exists":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create existing config
    writeFile(tempDir / "niuv.workspace.toml", "existing")
    
    let success = createWorkspaceConfig(tempDir, @["test"])
    check not success

  test "Install workspace dependencies":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let workspace = Workspace(
      root: tempDir,
      config: WorkspaceConfig(
        dependencies: toTable({"nonexistent": ">=99.0.0"})
      ),
      packages: @[]
    )
    
    let options = newCliOptions()
    
    # This will fail due to unresolvable dependency
    let success = workspace.installWorkspace(options)
    check not success  # Expected to fail with impossible version constraint

  test "Build workspace":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let workspace = Workspace(
      root: tempDir,
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(
          name: "test",
          path: tempDir / "test",
          version: "1.0.0",
          dependencies: initTable[string, seq[VersionConstraint]](),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        )
      ],
      graph: toTable({
        "test": newSeq[string]()
      })
    )
    
    # Create package directory
    createDir(tempDir / "test" / "src")
    writeFile(tempDir / "test" / "src" / "test.nim", "echo \"test\"")
    
    let options = newCliOptions()
    
    # This might fail but tests the build flow
    discard workspace.buildWorkspace(options)

  test "Test workspace":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let workspace = Workspace(
      root: tempDir,
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(
          name: "test",
          path: tempDir / "test",
          version: "1.0.0",
          dependencies: initTable[string, seq[VersionConstraint]](),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        )
      ]
    )
    
    let options = newCliOptions()
    
    # No tests directory, should handle gracefully
    let success = workspace.testWorkspace(options)
    check success  # Should pass when no tests found

  test "Test workspace with tests":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let workspace = Workspace(
      root: tempDir,
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(
          name: "test",
          path: tempDir / "test",
          version: "1.0.0",
          dependencies: initTable[string, seq[VersionConstraint]](),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        )
      ]
    )
    
    # Create tests directory
    createDir(tempDir / "test" / "tests")
    writeFile(tempDir / "test" / "tests" / "test1.nim", "")
    
    var options = newCliOptions()
    options.verbose = true
    
    # This will try to run testament
    discard workspace.testWorkspace(options)

  test "Publish workspace packages":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    let workspace = Workspace(
      root: tempDir,
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(
          name: "public",
          path: tempDir / "public",
          version: "1.0.0",
          isPrivate: false,
          dependencies: initTable[string, seq[VersionConstraint]](),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        ),
        WorkspacePackage(
          name: "private",
          path: tempDir / "private",
          version: "1.0.0",
          isPrivate: true,
          dependencies: initTable[string, seq[VersionConstraint]](),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        )
      ],
      graph: toTable({
        "public": newSeq[string](),
        "private": newSeq[string]()
      })
    )
    
    var options = newCliOptions()
    options.verbose = true
    
    # Currently just simulates publishing
    let success = workspace.publishWorkspacePackages(options)
    check success

suite "Edge Cases and Error Handling":
  test "Empty workspace operations":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[],
      graph: initTable[string, seq[string]]()
    )
    
    let options = newCliOptions()
    
    # All operations should handle empty workspace gracefully
    check workspace.topologicalSort().len == 0
    check workspace.resolveWorkspaceDependencies().success
    check workspace.testWorkspace(options)
    check workspace.publishWorkspacePackages(options)

  test "Complex workspace structure":
    let tempDir = createTempDir("niuv_test_", "")
    defer: removeDir(tempDir)
    
    # Create complex structure
    createDir(tempDir / "src" / "packages" / "core")
    createDir(tempDir / "src" / "packages" / "utils")
    
    writeFile(tempDir / "src" / "packages" / "core" / "core.nimble", """
version = "1.0.0"
author = "Test"
description = "Core"
""")
    
    writeFile(tempDir / "src" / "packages" / "utils" / "utils.nimble", """
version = "1.0.0" 
author = "Test"
description = "Utils"
""")
    
    writeFile(tempDir / "niuv.workspace.toml", """
[workspace]
members = ["src/packages/*"]
""")
    
    let workspace = loadWorkspace(tempDir)
    check workspace.packages.len == 2

  test "Workspace with only private packages":
    let workspace = Workspace(
      root: "/test",
      config: WorkspaceConfig(),
      packages: @[
        WorkspacePackage(
          name: "private1",
          path: "/test/private1",
          version: "1.0.0",
          isPrivate: true,
          dependencies: initTable[string, seq[VersionConstraint]](),
          devDependencies: initTable[string, seq[VersionConstraint]]()
        )
      ],
      graph: toTable({
        "private1": newSeq[string]()
      })
    )
    
    let options = newCliOptions()
    let success = workspace.publishWorkspacePackages(options)
    check success  # Should succeed even with no packages to publish