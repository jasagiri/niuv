## Virtual Environment Management Example
## Demonstrates comprehensive virtual environment features
## All outputs go to build/ directory

import std/[os, strformat, json, tables, times, strutils]

type
  VirtualEnv = object
    name: string
    path: string
    nimVersion: string
    created: DateTime
    packages: seq[tuple[name: string, version: string]]
    active: bool

  EnvHealth = object
    status: string  # healthy, warning, error
    issues: seq[string]
    lastChecked: DateTime

proc createVirtualEnvironment(name: string, nimVersion: string = ""): VirtualEnv =
  ## Create a new virtual environment
  let envPath = "build/envs" / name
  createDir(envPath)
  createDir(envPath / "bin")
  createDir(envPath / "nimbledeps")
  createDir(envPath / "config")
  
  # Create activation script
  let activateScript = """
#!/bin/bash
export NIUV_ENV="$1"
export PATH="$1/bin:$PATH"
export NIMBLE_DIR="$1/nimbledeps"
echo "Activated niuv environment: $2"
""".replace("$1", envPath).replace("$2", name)
  
  writeFile(envPath / "bin" / "activate", activateScript)
  
  # Create environment config
  let config = %*{
    "name": name,
    "nimVersion": if nimVersion == "": "2.2.0" else: nimVersion,
    "created": $now(),
    "packages": []
  }
  
  writeFile(envPath / "config" / "env.json", config.pretty())
  
  result = VirtualEnv(
    name: name,
    path: envPath,
    nimVersion: if nimVersion == "": "2.2.0" else: nimVersion,
    created: now(),
    packages: @[],
    active: false
  )

proc installPackage(env: var VirtualEnv, packageName: string, version: string = "@latest") =
  ## Install a package into the virtual environment
  echo fmt"Installing {packageName}{version} into {env.name}..."
  
  # Simulate package installation
  env.packages.add((name: packageName, version: version))
  
  # Update environment config
  let config = %*{
    "name": env.name,
    "nimVersion": env.nimVersion,
    "created": $env.created,
    "packages": env.packages.mapIt(%*{"name": it.name, "version": it.version})
  }
  
  writeFile(env.path / "config" / "env.json", config.pretty())

proc checkEnvironmentHealth(env: VirtualEnv): EnvHealth =
  ## Check the health of a virtual environment
  result = EnvHealth(
    status: "healthy",
    issues: @[],
    lastChecked: now()
  )
  
  # Check if environment path exists
  if not dirExists(env.path):
    result.status = "error"
    result.issues.add("Environment directory not found")
    return
  
  # Check required directories
  for dir in ["bin", "nimbledeps", "config"]:
    if not dirExists(env.path / dir):
      result.status = "warning"
      result.issues.add(fmt"Missing {dir} directory")
  
  # Check for conflicting packages
  var packageVersions = initTable[string, seq[string]]()
  for pkg in env.packages:
    if pkg.name notin packageVersions:
      packageVersions[pkg.name] = @[]
    packageVersions[pkg.name].add(pkg.version)
  
  for name, versions in packageVersions:
    if versions.len > 1:
      result.status = "warning"
      result.issues.add(fmt"Multiple versions of {name}: {versions.join(', ')}")
  
  # Check Nim version compatibility
  if env.nimVersion < "2.0.0":
    result.status = "warning"
    result.issues.add(fmt"Nim version {env.nimVersion} is outdated")

proc generateEnvironmentReport(envs: seq[VirtualEnv]) =
  ## Generate a comprehensive report of all virtual environments
  var report = %*{
    "timestamp": $now(),
    "totalEnvironments": envs.len,
    "environments": []
  }
  
  for env in envs:
    let health = checkEnvironmentHealth(env)
    
    report["environments"].add(%*{
      "name": env.name,
      "path": env.path,
      "nimVersion": env.nimVersion,
      "created": $env.created,
      "active": env.active,
      "packageCount": env.packages.len,
      "packages": env.packages.mapIt(%*{"name": it.name, "version": it.version}),
      "health": {
        "status": health.status,
        "issues": health.issues,
        "lastChecked": $health.lastChecked
      }
    })
  
  createDir("build/reports")
  writeFile("build/reports/environments.json", report.pretty())

proc runVirtualEnvExample() =
  echo "=== Virtual Environment Management Example ==="
  echo "Creating and managing isolated Nim environments...\n"
  
  # Ensure base directories exist
  createDir("build/envs")
  createDir("build/reports")
  
  # Example 1: Create development environment
  echo "1. Creating development environment..."
  var devEnv = createVirtualEnvironment("dev", "2.2.0")
  echo fmt"   ✓ Created: {devEnv.path}"
  
  # Install development packages
  devEnv.installPackage("unittest2", "@1.0.0")
  devEnv.installPackage("chronicles", "@latest")
  devEnv.installPackage("results", "@latest")
  echo fmt"   ✓ Installed {devEnv.packages.len} packages"
  
  # Example 2: Create production environment
  echo "\n2. Creating production environment..."
  var prodEnv = createVirtualEnvironment("prod", "2.2.0")
  echo fmt"   ✓ Created: {prodEnv.path}"
  
  # Install only production packages
  prodEnv.installPackage("jester", "@latest")
  prodEnv.installPackage("norm", "@2.5.0")
  echo fmt"   ✓ Installed {prodEnv.packages.len} packages"
  
  # Example 3: Create test environment with specific versions
  echo "\n3. Creating test environment..."
  var testEnv = createVirtualEnvironment("test", "2.0.0")
  echo fmt"   ✓ Created: {testEnv.path}"
  
  # Install test packages with specific versions
  testEnv.installPackage("unittest2", "@0.9.0")
  testEnv.installPackage("mock", "@latest")
  testEnv.installPackage("coverage", "@latest")
  echo fmt"   ✓ Installed {testEnv.packages.len} packages"
  
  # Example 4: Environment isolation demonstration
  echo "\n4. Demonstrating environment isolation..."
  
  # Simulate switching environments
  devEnv.active = true
  echo fmt"   ✓ Activated: {devEnv.name}"
  echo fmt"   - Nim version: {devEnv.nimVersion}"
  echo "   - Available packages:"
  for pkg in devEnv.packages:
    echo fmt"     • {pkg.name} {pkg.version}"
  
  devEnv.active = false
  prodEnv.active = true
  echo fmt"\n   ✓ Switched to: {prodEnv.name}"
  echo fmt"   - Nim version: {prodEnv.nimVersion}"
  echo "   - Available packages:"
  for pkg in prodEnv.packages:
    echo fmt"     • {pkg.name} {pkg.version}"
  
  # Example 5: Environment health check
  echo "\n5. Checking environment health..."
  
  let environments = @[devEnv, prodEnv, testEnv]
  
  for env in environments:
    let health = checkEnvironmentHealth(env)
    echo fmt"\n   {env.name}: {health.status}"
    if health.issues.len > 0:
      echo "   Issues:"
      for issue in health.issues:
        echo fmt"   - {issue}"
  
  # Generate comprehensive report
  generateEnvironmentReport(environments)
  echo "\n📄 Environment report saved to: build/reports/environments.json"
  
  # Example 6: Workspace with multiple environments
  echo "\n6. Creating workspace configuration..."
  
  let workspaceConfig = %*{
    "name": "MyProject",
    "environments": {
      "development": {
        "path": devEnv.path,
        "default": true
      },
      "production": {
        "path": prodEnv.path,
        "default": false
      },
      "testing": {
        "path": testEnv.path,
        "default": false
      }
    },
    "scripts": {
      "dev": "niuv activate dev && nim c -r src/main.nim",
      "test": "niuv activate test && nim test",
      "build": "niuv activate prod && nim c -d:release -o:build/release/app src/main.nim"
    }
  }
  
  writeFile("build/reports/workspace.json", workspaceConfig.pretty())
  echo "📄 Workspace configuration saved to: build/reports/workspace.json"
  
  # Example 7: Package dependency resolution
  echo "\n7. Analyzing package dependencies..."
  
  var allPackages = initTable[string, seq[string]]()
  
  for env in environments:
    for pkg in env.packages:
      if pkg.name notin allPackages:
        allPackages[pkg.name] = @[]
      allPackages[pkg.name].add(fmt"{env.name}: {pkg.version}")
  
  echo "\n   Package usage across environments:"
  for name, usage in allPackages:
    echo fmt"   - {name}:"
    for use in usage:
      echo fmt"     • {use}"
  
  # Save dependency analysis
  let depAnalysis = %*{
    "timestamp": $now(),
    "uniquePackages": allPackages.len,
    "packages": allPackages
  }
  
  writeFile("build/reports/dependency_analysis.json", depAnalysis.pretty())
  echo "\n📄 Dependency analysis saved to: build/reports/dependency_analysis.json"

when isMainModule:
  runVirtualEnvExample()
  echo "\n✅ Virtual environment management example completed!"