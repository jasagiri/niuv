import std/unittest

import unittest
import ../src/resolver
import std/[tables, json, os]

suite "Version parsing and comparison":
  test "Parse simple version":
    let v = parseVersion("1.2.3")
    check v.major == 1
    check v.minor == 2
    check v.patch == 3
    check v.prerelease == ""
    check v.build == ""
  
  test "Parse version with prerelease":
    let v = parseVersion("1.2.3-alpha.1")
    check v.major == 1
    check v.minor == 2
    check v.patch == 3
    check v.prerelease == "alpha.1"
  
  test "Parse version with build metadata":
    let v = parseVersion("1.2.3-alpha.1+build.123")
    check v.major == 1
    check v.minor == 2
    check v.patch == 3
    check v.prerelease == "alpha.1"
    check v.build == "build.123"
  
  test "Version comparison":
    check parseVersion("1.0.0") < parseVersion("2.0.0")
    check parseVersion("1.0.0") < parseVersion("1.1.0")
    check parseVersion("1.0.0") < parseVersion("1.0.1")
    check parseVersion("1.0.0") == parseVersion("1.0.0")
    check parseVersion("2.0.0") > parseVersion("1.9.9")
  
  test "Prerelease version comparison":
    check parseVersion("1.0.0-alpha") < parseVersion("1.0.0")
    check parseVersion("1.0.0-alpha") < parseVersion("1.0.0-beta")

suite "Version constraints":
  test "Parse constraint with operator":
    let c1 = parseConstraint(">= 1.2.3")
    check c1.operator == ">="
    check c1.version == parseVersion("1.2.3")
    
    let c2 = parseConstraint("< 2.0.0")
    check c2.operator == "<"
    check c2.version == parseVersion("2.0.0")
    
    let c3 = parseConstraint("~> 1.2.3")
    check c3.operator == "~>"
    check c3.version == parseVersion("1.2.3")
  
  test "Parse constraint without operator":
    let c = parseConstraint("1.2.3")
    check c.operator == "="
    check c.version == parseVersion("1.2.3")
  
  test "Constraint satisfaction":
    let v = parseVersion("1.2.3")
    
    check v.satisfies(parseConstraint("= 1.2.3"))
    check v.satisfies(parseConstraint(">= 1.2.0"))
    check v.satisfies(parseConstraint("> 1.2.0"))
    check v.satisfies(parseConstraint("<= 1.3.0"))
    check v.satisfies(parseConstraint("< 2.0.0"))
    
    check not v.satisfies(parseConstraint("= 1.2.4"))
    check not v.satisfies(parseConstraint("> 1.2.3"))
    check not v.satisfies(parseConstraint("< 1.2.3"))
  
  test "Pessimistic constraint (~>)":
    let v1 = parseVersion("1.2.3")
    let v2 = parseVersion("1.2.9")
    let v3 = parseVersion("1.3.0")
    let constraint = parseConstraint("~> 1.2.3")
    
    check v1.satisfies(constraint)
    check v2.satisfies(constraint)
    check not v3.satisfies(constraint)
  
  test "Caret constraint (^)":
    let v1 = parseVersion("1.2.3")
    let v2 = parseVersion("1.9.9")
    let v3 = parseVersion("2.0.0")
    let constraint = parseConstraint("^ 1.2.3")
    
    check v1.satisfies(constraint)
    check v2.satisfies(constraint)
    check not v3.satisfies(constraint)

suite "Package cache":
  test "Add and retrieve packages":
    let cache = newPackageCache()
    
    let pkg1 = Package(
      name: "test",
      version: parseVersion("1.0.0"),
      dependencies: initTable[string, seq[VersionConstraint]]()
    )
    
    let pkg2 = Package(
      name: "test",
      version: parseVersion("2.0.0"),
      dependencies: initTable[string, seq[VersionConstraint]]()
    )
    
    cache.addPackage(pkg1)
    cache.addPackage(pkg2)
    
    let versions = cache.getPackageVersions("test")
    check versions.len == 2
    check versions[0].version == parseVersion("2.0.0")  # Latest first
    check versions[1].version == parseVersion("1.0.0")

suite "SAT solver":
  test "Simple satisfaction":
    let solver = newSATSolver()
    
    let v1 = SATVariable(package: "test", version: parseVersion("1.0.0"))
    let v2 = SATVariable(package: "test", version: parseVersion("2.0.0"))
    
    solver.addVariable("test", parseVersion("1.0.0"))
    solver.addVariable("test", parseVersion("2.0.0"))
    
    # Exactly one version must be selected
    solver.addExactlyOne(@[v1, v2])
    
    check solver.solve()
    check (v1 in solver.assignment and solver.assignment[v1]) or
          (v2 in solver.assignment and solver.assignment[v2])
    check not (solver.assignment.getOrDefault(v1, false) and 
               solver.assignment.getOrDefault(v2, false))
  
  test "Conflict detection":
    let solver = newSATSolver()
    
    let v1 = SATVariable(package: "a", version: parseVersion("1.0.0"))
    let v2 = SATVariable(package: "b", version: parseVersion("1.0.0"))
    
    solver.addVariable("a", parseVersion("1.0.0"))
    solver.addVariable("b", parseVersion("1.0.0"))
    
    # Both must be true
    solver.addClause(@[(variable: v1, positive: true)])
    solver.addClause(@[(variable: v2, positive: true)])
    
    # But they conflict
    solver.addConflict(v1, v2)
    
    check not solver.solve()

suite "Package resolver":
  test "Simple resolution":
    let resolver = newPackageResolver()
    
    # Add packages to cache
    var pkgA = Package(
      name: "a",
      version: parseVersion("1.0.0"),
      dependencies: initTable[string, seq[VersionConstraint]]()
    )
    pkgA.dependencies["b"] = @[parseConstraint(">= 1.0.0")]
    
    let pkgB = Package(
      name: "b",
      version: parseVersion("1.0.0"),
      dependencies: initTable[string, seq[VersionConstraint]]()
    )
    
    resolver.cache.addPackage(pkgA)
    resolver.cache.addPackage(pkgB)
    
    # Resolve
    let deps = @[PackageRef(name: "a", constraints: @[])]
    let result = resolver.resolvePackages(deps)
    
    check result.success
    check result.packages.len == 2
    
    var hasA, hasB = false
    for pkg in result.packages:
      if pkg.name == "a": hasA = true
      if pkg.name == "b": hasB = true
    check hasA and hasB
  
  test "Version conflict resolution":
    let resolver = newPackageResolver()
    
    # Package A requires B >= 2.0.0
    var pkgA = Package(
      name: "a",
      version: parseVersion("1.0.0"),
      dependencies: initTable[string, seq[VersionConstraint]]()
    )
    pkgA.dependencies["b"] = @[parseConstraint(">= 2.0.0")]
    
    # Package C requires B < 2.0.0
    var pkgC = Package(
      name: "c",
      version: parseVersion("1.0.0"),
      dependencies: initTable[string, seq[VersionConstraint]]()
    )
    pkgC.dependencies["b"] = @[parseConstraint("< 2.0.0")]
    
    let pkgB1 = Package(
      name: "b",
      version: parseVersion("1.0.0"),
      dependencies: initTable[string, seq[VersionConstraint]]()
    )
    
    let pkgB2 = Package(
      name: "b",
      version: parseVersion("2.0.0"),
      dependencies: initTable[string, seq[VersionConstraint]]()
    )
    
    resolver.cache.addPackage(pkgA)
    resolver.cache.addPackage(pkgC)
    resolver.cache.addPackage(pkgB1)
    resolver.cache.addPackage(pkgB2)
    
    # Try to resolve both A and C - should fail
    let deps = @[
      PackageRef(name: "a", constraints: @[]),
      PackageRef(name: "c", constraints: @[])
    ]
    let result = resolver.resolvePackages(deps)
    
    check not result.success

suite "Lockfile handling":
  test "Save and load lockfile":
    let packages = @[
      Package(
        name: "test",
        version: parseVersion("1.0.0"),
        url: "https://github.com/user/test",
        checksum: "abc123",
        dependencies: initTable[string, seq[VersionConstraint]]()
      )
    ]
    
    let tempFile = "test_lockfile.json"
    packages.saveLockfile(tempFile)
    
    check fileExists(tempFile)
    
    let content = readFile(tempFile)
    let json = parseJson(content)
    
    check json["version"].getStr() == "1.0.0"
    check json["packages"].len == 1
    check json["packages"][0]["name"].getStr() == "test"
    check json["packages"][0]["version"].getStr() == "1.0.0"
    
    # Clean up
    removeFile(tempFile)
  
  test "Resolve from lockfile":
    let lockfileContent = %* {
      "version": "1.0.0",
      "packages": [
        {
          "name": "test",
          "version": "1.2.3",
          "url": "https://github.com/user/test",
          "checksum": "xyz789",
          "dependencies": {
            "dep1": [">= 1.0.0"]
          }
        }
      ]
    }
    
    let resolver = newPackageResolver()
    let result = resolver.resolveFromLockfile(lockfileContent)
    
    check result.success
    check result.packages.len == 1
    check result.packages[0].name == "test"
    check result.packages[0].version == parseVersion("1.2.3")
    check result.packages[0].dependencies["dep1"][0].operator == ">="