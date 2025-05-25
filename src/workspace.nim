## Workspace support for monorepo management
## Allows managing multiple related packages in a single repository

import std/[os, tables, sequtils, strutils, sets, re, terminal, osproc]
import parsetoml
import ./deps, ./resolver, ./install, ./cli

type
  WorkspacePackage* = object
    name*: string
    path*: string
    version*: string
    dependencies*: Table[string, seq[VersionConstraint]]
    devDependencies*: Table[string, seq[VersionConstraint]]
    isPrivate*: bool

  WorkspaceConfig* = object
    members*: seq[string]  # Glob patterns for member packages
    dependencies*: Table[string, string]  # Shared dependencies
    devDependencies*: Table[string, string]  # Shared dev dependencies
    exclude*: seq[string]  # Patterns to exclude

  Workspace* = ref object
    root*: string
    config*: WorkspaceConfig
    packages*: seq[WorkspacePackage]
    graph*: Table[string, seq[string]]  # Dependency graph

  WorkspaceError* = object of CatchableError

proc parseWorkspaceConfig*(path: string): WorkspaceConfig =
  ## Parse workspace configuration from niuv.workspace.toml
  if not fileExists(path):
    raise newException(WorkspaceError, "Workspace file not found: " & path)
  
  let toml = parsetoml.parseFile(path)
  
  # Parse workspace members
  if toml.hasKey("workspace") and toml["workspace"].hasKey("members"):
    let members = toml["workspace"]["members"]
    if members.kind == TomlValueKind.Array:
      for i in 0..<members.len:
        result.members.add(members[i].getStr())
  
  # Parse exclude patterns
  if toml.hasKey("workspace") and toml["workspace"].hasKey("exclude"):
    let exclude = toml["workspace"]["exclude"]
    if exclude.kind == TomlValueKind.Array:
      for i in 0..<exclude.len:
        result.exclude.add(exclude[i].getStr())
  
  # Parse shared dependencies - handle both nested and dot notation
  # First try nested format
  if toml.hasKey("workspace"):
    let workspace = toml["workspace"]
    if workspace.hasKey("dependencies"):
      let deps = workspace["dependencies"]
      if deps.kind == TomlValueKind.Table:
        for key, value in deps.getTable():
          if value.kind == TomlValueKind.String:
            result.dependencies[key] = value.getStr()
    
    if workspace.hasKey("devDependencies"):
      let devDeps = workspace["devDependencies"]
      if devDeps.kind == TomlValueKind.Table:
        for key, value in devDeps.getTable():
          if value.kind == TomlValueKind.String:
            result.devDependencies[key] = value.getStr()
  
  # Also check for dot notation (TOML standard)
  for key, value in toml.getTable():
    if key == "workspace.dependencies" and value.kind == TomlValueKind.Table:
      for depKey, depValue in value.getTable():
        if depValue.kind == TomlValueKind.String:
          result.dependencies[depKey] = depValue.getStr()
    elif key == "workspace.devDependencies" and value.kind == TomlValueKind.Table:
      for depKey, depValue in value.getTable():
        if depValue.kind == TomlValueKind.String:
          result.devDependencies[depKey] = depValue.getStr()

proc findWorkspaceRoot*(startDir: string = getCurrentDir()): string =
  ## Find the workspace root by looking for niuv.workspace.toml
  var dir = startDir.absolutePath()
  
  while true:
    let workspaceFile = dir / "niuv.workspace.toml"
    if fileExists(workspaceFile):
      return dir
    
    let parent = dir.parentDir()
    if parent == dir:
      # Reached filesystem root
      return ""
    dir = parent

proc expandGlobPatterns*(patterns: seq[string], root: string, exclude: seq[string] = @[]): seq[string] =
  ## Expand glob patterns to actual paths
  result = @[]
  
  for pattern in patterns:
    if pattern.contains("*"):
      # Handle glob patterns
      let parts = pattern.split('/')
      var searchPaths = @[root]
      
      for i, part in parts:
        var newPaths: seq[string] = @[]
        
        for searchPath in searchPaths:
          if part == "*":
            # Match any directory
            for kind, path in walkDir(searchPath):
              if kind == pcDir:
                newPaths.add(path)
          elif part == "**":
            # Match any depth
            for path in walkDirRec(searchPath):
              if dirExists(path):
                newPaths.add(path)
          elif part.contains("*"):
            # Pattern matching
            for kind, path in walkDir(searchPath):
              if kind == pcDir:
                let name = path.lastPathPart()
                if name.match(re(part.replace("*", ".*"))):
                  newPaths.add(path)
          else:
            # Literal path component
            let newPath = searchPath / part
            if dirExists(newPath):
              newPaths.add(newPath)
        
        searchPaths = newPaths
      
      # Check if paths should be excluded
      for path in searchPaths:
        var excluded = false
        for excludePattern in exclude:
          if path.contains(excludePattern) or path.lastPathPart().match(re(excludePattern.replace("*", ".*"))):
            excluded = true
            break
        if not excluded:
          result.add(path)
    else:
      # Literal path
      let fullPath = root / pattern
      if dirExists(fullPath):
        result.add(fullPath)
  
  # Remove duplicates
  result = result.toHashSet().toSeq()

proc loadWorkspacePackage*(dir: string): WorkspacePackage =
  ## Load a package from a directory
  var nimbleFiles: seq[string] = @[]
  for kind, path in walkDir(dir):
    if kind == pcFile and path.endsWith(".nimble"):
      nimbleFiles.add(path)
  
  if nimbleFiles.len == 0:
    raise newException(WorkspaceError, "No .nimble file found in: " & dir)
  
  let nimbleFile = nimbleFiles[0]
  discard parseNimbleFile(nimbleFile)  # For potential future use
  
  # Extract package name from filename if no packages found
  let baseName = nimbleFile.splitFile.name
  
  # Parse basic metadata from nimble file
  let content = readFile(nimbleFile)
  var version = "0.1.0"  # Default version
  
  for line in content.splitLines():
    let trimmed = line.strip()
    if trimmed.startsWith("version") and "=" in trimmed:
      let parts = trimmed.split("=", 1)
      if parts.len == 2:
        version = parts[1].strip().strip(chars = {'"'})
        break
  
  result.name = baseName
  result.path = dir
  result.version = version
  result.isPrivate = false  # TODO: Parse from package metadata
  
  # Convert NimblePackage dependencies to our format
  result.dependencies = initTable[string, seq[VersionConstraint]]()
  result.devDependencies = initTable[string, seq[VersionConstraint]]()
  
  # TODO: Parse actual dependencies from .nimble file

proc discoverPackages*(workspace: Workspace): seq[WorkspacePackage] =
  ## Discover all packages in the workspace
  let memberPaths = expandGlobPatterns(
    workspace.config.members,
    workspace.root,
    workspace.config.exclude
  )
  
  result = @[]
  for path in memberPaths:
    try:
      let pkg = loadWorkspacePackage(path)
      result.add(pkg)
    except WorkspaceError:
      # Skip directories without .nimble files
      continue

proc buildDependencyGraph*(workspace: Workspace) =
  ## Build internal dependency graph between workspace packages
  workspace.graph = initTable[string, seq[string]]()
  
  let packageNames = workspace.packages.mapIt(it.name).toHashSet()
  
  for pkg in workspace.packages:
    workspace.graph[pkg.name] = @[]
    
    # Check dependencies
    for depName, _ in pkg.dependencies:
      if depName in packageNames:
        workspace.graph[pkg.name].add(depName)

proc topologicalSort*(workspace: Workspace): seq[string] =
  ## Sort packages in topological order (dependencies first)
  var visited = initHashSet[string]()
  var temp = initHashSet[string]()
  var order: seq[string] = @[]
  
  proc visit(name: string) =
    if name in temp:
      raise newException(WorkspaceError, "Circular dependency detected involving: " & name)
    
    if name notin visited:
      temp.incl(name)
      
      if name in workspace.graph:
        for dep in workspace.graph[name]:
          visit(dep)
      
      temp.excl(name)
      visited.incl(name)
      order.add(name)
  
  for pkg in workspace.packages:
    if pkg.name notin visited:
      visit(pkg.name)
  
  # Return as-is - dependencies are already first
  return order

proc loadWorkspace*(root: string = ""): Workspace =
  ## Load workspace from root directory
  let workspaceRoot = if root != "": root else: findWorkspaceRoot()
  
  if workspaceRoot == "":
    raise newException(WorkspaceError, "No workspace found (missing niuv.workspace.toml)")
  
  result = Workspace(root: workspaceRoot)
  result.config = parseWorkspaceConfig(workspaceRoot / "niuv.workspace.toml")
  result.packages = result.discoverPackages()
  result.buildDependencyGraph()

proc resolveWorkspaceDependencies*(workspace: Workspace): ResolutionResult =
  ## Resolve all dependencies for the entire workspace
  let resolver = newPackageResolver()
  
  # Collect all dependencies from all packages
  var allDeps: seq[PackageRef] = @[]
  var internalPackages = initTable[string, WorkspacePackage]()
  
  for pkg in workspace.packages:
    internalPackages[pkg.name] = pkg
  
  # Add workspace-level dependencies
  for name, version in workspace.config.dependencies:
    allDeps.add(PackageRef(
      name: name,
      constraints: @[parseConstraint(version)]
    ))
  
  # Add package-level dependencies (excluding internal ones)
  for pkg in workspace.packages:
    for depName, constraints in pkg.dependencies:
      if depName notin internalPackages:
        allDeps.add(PackageRef(name: depName, constraints: constraints))
  
  # Resolve external dependencies
  return resolver.resolvePackages(allDeps)

proc installWorkspace*(workspace: Workspace, options: CliOptions): bool =
  ## Install all dependencies for the workspace
  styledEcho(styleBright, "Installing workspace dependencies...")
  
  # Resolve dependencies
  let resolution = workspace.resolveWorkspaceDependencies()
  
  if not resolution.success:
    styledEcho(fgRed, "Failed to resolve workspace dependencies: ", resolution.error)
    return false
  
  # Create a shared nimbledeps directory at workspace root
  let sharedDepsDir = workspace.root / "nimbledeps"
  if not dirExists(sharedDepsDir):
    createDir(sharedDepsDir)
  
  # Install resolved packages
  styledEcho(styleBright, "Installing ", $resolution.packages.len, " packages...")
  
  for pkg in resolution.packages:
    if not installPackage(pkg.name, $pkg.version, options.verbose):
      styledEcho(fgRed, "Failed to install package: ", pkg.name)
      return false
  
  # Create symlinks in each package directory to shared deps
  for pkg in workspace.packages:
    let pkgDepsDir = pkg.path / "nimbledeps"
    
    if symlinkExists(pkgDepsDir):
      removeFile(pkgDepsDir)
    elif dirExists(pkgDepsDir):
      styledEcho(fgYellow, "Warning: ", pkgDepsDir, " exists and is not a symlink")
      continue
    
    # Create relative symlink
    let relPath = relativePath(sharedDepsDir, pkg.path)
    createSymlink(relPath, pkgDepsDir)
    
    if options.verbose:
      styledEcho(fgGreen, "Created symlink: ", pkgDepsDir, " -> ", relPath)
  
  styledEcho(fgGreen, "Workspace installation complete")
  return true

proc buildWorkspace*(workspace: Workspace, options: CliOptions): bool =
  ## Build all packages in the workspace in dependency order
  styledEcho(styleBright, "Building workspace packages...")
  
  let buildOrder = workspace.topologicalSort()
  
  for pkgName in buildOrder:
    let pkg = workspace.packages.filterIt(it.name == pkgName)[0]
    
    styledEcho(styleBright, "Building ", pkg.name, " (", pkg.path, ")...")
    
    let cmd = "nim c -d:release " & pkg.path / "src" / pkg.name & ".nim"
    let (output, exitCode) = execCmdEx(cmd)
    
    if exitCode != 0:
      styledEcho(fgRed, "Failed to build ", pkg.name)
      if options.verbose:
        echo output
      return false
    
    if options.verbose:
      echo output
  
  styledEcho(fgGreen, "Workspace build complete")
  return true

proc testWorkspace*(workspace: Workspace, options: CliOptions): bool =
  ## Run tests for all packages in the workspace
  styledEcho(styleBright, "Testing workspace packages...")
  
  var allPassed = true
  
  for pkg in workspace.packages:
    styledEcho(styleBright, "Testing ", pkg.name, "...")
    
    let testDir = pkg.path / "tests"
    if not dirExists(testDir):
      if options.verbose:
        styledEcho(fgYellow, "No tests directory found for ", pkg.name)
      continue
    
    # Run tests
    let cmd = "testament pattern '" & testDir / "*.nim'"
    let (output, exitCode) = execCmdEx(cmd)
    
    if exitCode != 0:
      styledEcho(fgRed, "Tests failed for ", pkg.name)
      allPassed = false
    else:
      styledEcho(fgGreen, "Tests passed for ", pkg.name)
    
    if options.verbose:
      echo output
  
  return allPassed

proc publishWorkspacePackages*(workspace: Workspace, options: CliOptions): bool =
  ## Publish all non-private packages from the workspace
  styledEcho(styleBright, "Publishing workspace packages...")
  
  let buildOrder = workspace.topologicalSort()
  
  for pkgName in buildOrder:
    let pkg = workspace.packages.filterIt(it.name == pkgName)[0]
    
    if pkg.isPrivate:
      if options.verbose:
        styledEcho(fgYellow, "Skipping private package: ", pkg.name)
      continue
    
    styledEcho(styleBright, "Publishing ", pkg.name, " v", pkg.version, "...")
    
    # TODO: Implement actual publishing logic
    # For now, just simulate
    if options.verbose:
      echo "Would publish: ", pkg.name, " from ", pkg.path
  
  styledEcho(fgGreen, "Workspace publishing complete")
  return true

proc createWorkspaceConfig*(root: string, members: seq[string]): bool =
  ## Create a new workspace configuration file
  let configPath = root / "niuv.workspace.toml"
  
  if fileExists(configPath):
    styledEcho(fgYellow, "Workspace configuration already exists")
    return false
  
  let config = """[workspace]
# Workspace members - can use glob patterns
members = $1

# Patterns to exclude
exclude = []

# Shared dependencies for all workspace packages
[workspace.dependencies]

# Shared dev dependencies
[workspace.devDependencies]
""" % [members.mapIt("\"" & it & "\"").join(", ")]
  
  writeFile(configPath, config)
  styledEcho(fgGreen, "Created workspace configuration: ", configPath)
  return true