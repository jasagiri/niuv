## Workspace Management Example
## Demonstrates niuv's advanced workspace features for monorepos

import std/[os, strutils, sequtils, tables, json, times, asyncdispatch]
import ../../../../frameworks/system-frameworks/gennethleia/src/gennethleia_actor
import ../../../../frameworks/system-frameworks/gennethleia/src/actor_state_machine

# Workspace types and configuration
type
  WorkspacePackage = object
    name: string
    path: string
    version: string
    dependencies: Table[string, string]
    devDependencies: Table[string, string]
    scripts: Table[string, string]
    isPrivate: bool

  Workspace = object
    name: string
    root: string
    packages: seq[WorkspacePackage]
    globalDeps: Table[string, string]
    config: WorkspaceConfig
    topology: DependencyGraph

  WorkspaceConfig = object
    packageGlobs: seq[string]
    hoistingRules: HoistingStrategy
    linkingStrategy: LinkingStrategy
    parallelism: int
    strictVersions: bool
    autoSync: bool

  HoistingStrategy = enum
    hsNone = "none"              # No hoisting
    hsConservative = "conservative"  # Hoist only if same version
    hsAggressive = "aggressive"      # Hoist all possible

  LinkingStrategy = enum
    lsSymlink = "symlink"        # Use symbolic links
    lsHardlink = "hardlink"      # Use hard links
    lsCopy = "copy"              # Copy files

  DependencyGraph = object
    nodes: Table[string, WorkspacePackage]
    edges: Table[string, seq[string]]
    cycles: seq[seq[string]]

  WorkspaceTask = object
    name: string
    packages: seq[string]  # Packages to run in
    command: string
    parallel: bool
    continueOnError: bool

# Example monorepo workspace
let exampleWorkspace = Workspace(
  name: "enterprise-platform",
  root: "./workspace",
  packages: @[
    WorkspacePackage(
      name: "@platform/core",
      path: "packages/core",
      version: "1.0.0",
      dependencies: {"nim": ">=2.0.0"}.toTable,
      devDependencies: {"unittest2": "latest"}.toTable,
      scripts: {
        "build": "nim c -d:release src/core.nim",
        "test": "nim c -r tests/test_core.nim"
      }.toTable,
      isPrivate: false
    ),
    WorkspacePackage(
      name: "@platform/auth",
      path: "packages/auth",
      version: "1.0.0",
      dependencies: {
        "@platform/core": "workspace:*",
        "jwt": "^0.2.0",
        "bcrypt": "^1.0.0"
      }.toTable,
      devDependencies: {"unittest2": "latest"}.toTable,
      scripts: {
        "build": "nim c -d:release src/auth.nim",
        "test": "nim c -r tests/test_auth.nim"
      }.toTable,
      isPrivate: false
    ),
    WorkspacePackage(
      name: "@platform/api",
      path: "services/api",
      version: "0.1.0",
      dependencies: {
        "@platform/core": "workspace:*",
        "@platform/auth": "workspace:*",
        "jester": "^0.5.0",
        "norm": "^2.5.0"
      }.toTable,
      devDependencies: {"unittest2": "latest"}.toTable,
      scripts: {
        "dev": "nim c -r -d:debug src/server.nim",
        "build": "nim c -d:release -d:ssl --threads:on src/server.nim",
        "test": "nim c -r tests/test_api.nim"
      }.toTable,
      isPrivate: true
    ),
    WorkspacePackage(
      name: "@platform/web",
      path: "apps/web",
      version: "0.1.0",
      dependencies: {
        "@platform/core": "workspace:*",
        "karax": "^1.2.0",
        "ajax": "^1.0.0"
      }.toTable,
      devDependencies: {"unittest2": "latest"}.toTable,
      scripts: {
        "dev": "nim js -d:debug src/app.nim",
        "build": "nim js -d:release -d:danger src/app.nim",
        "serve": "python -m http.server 8000"
      }.toTable,
      isPrivate: true
    ),
    WorkspacePackage(
      name: "@platform/cli",
      path: "tools/cli",
      version: "0.1.0",
      dependencies: {
        "@platform/core": "workspace:*",
        "@platform/auth": "workspace:*",
        "cligen": "^1.5.0"
      }.toTable,
      devDependencies: {"unittest2": "latest"}.toTable,
      scripts: {
        "build": "nim c -d:release src/cli.nim",
        "install": "cp cli /usr/local/bin/platform-cli"
      }.toTable,
      isPrivate: false
    )
  ],
  globalDeps: {
    "nim": ">=2.0.0",
    "nimble": "latest"
  }.toTable,
  config: WorkspaceConfig(
    packageGlobs: @["packages/*", "services/*", "apps/*", "tools/*"],
    hoistingStrategy: hsConservative,
    linkingStrategy: lsSymlink,
    parallelism: 4,
    strictVersions: true,
    autoSync: true
  )
)

# Workspace management functions
proc initializeWorkspace*(name: string, root: string): Workspace =
  ## Initializes a new workspace
  echo &"\nInitializing workspace: {name}"
  echo &"Root directory: {root}"
  echo "=".repeat((60)
  
  result = Workspace(
    name: name,
    root: root,
    packages: @[],
    globalDeps: initTable[string, string](),
    config: WorkspaceConfig(
      packageGlobs: @["packages/*", "apps/*"],
      hoistingStrategy: hsConservative,
      linkingStrategy: lsSymlink,
      parallelism: 4,
      strictVersions: true,
      autoSync: true
    )
  )
  
  # Create directory structure
  echo "\nCreating workspace structure:"
  for dir in ["packages", "apps", "tools", "scripts", "docs"]:
    let path = root / dir
    echo &"  Creating {path}"
    createDir(path)
  
  # Create workspace configuration file
  let config = %* {
    "name": name,
    "version": "1.0.0",
    "private": true,
    "workspaces": result.config.packageGlobs,
    "config": {
      "hoisting": $result.config.hoistingStrategy,
      "linking": $result.config.linkingStrategy,
      "parallelism": result.config.parallelism,
      "strict_versions": result.config.strictVersions,
      "auto_sync": result.config.autoSync
    }
  }
  
  writeFile(root / "niuv.workspace.toml", config.pretty)
  echo "\n✓ Workspace initialized successfully"

proc discoverPackages*(workspace: var Workspace) =
  ## Discovers packages in the workspace
  echo "\nDiscovering packages in workspace..."
  
  workspace.packages = @[]
  
  for glob in workspace.config.packageGlobs:
    let pattern = workspace.root / glob
    echo &"  Scanning: {pattern}"
    
    # In real implementation, would scan filesystem
    # For demo, using predefined packages
  
  workspace.packages = exampleWorkspace.packages
  echo &"\n✓ Discovered {workspace.packages.len} packages"
  
  for pkg in workspace.packages:
    echo &"  - {pkg.name} ({pkg.path})"

proc analyzeDependencyGraph*(workspace: Workspace): DependencyGraph =
  ## Analyzes workspace dependency relationships
  echo "\nAnalyzing dependency graph..."
  
  # Build nodes
  for pkg in workspace.packages:
    result.nodes[pkg.name] = pkg
  
  # Build edges
  for pkg in workspace.packages:
    result.edges[pkg.name] = @[]
    
    for dep, _ in pkg.dependencies:
      if dep.startsWith("@platform/"):
        result.edges[pkg.name].add(dep)
  
  # Detect cycles
  proc hasCycle(node: string, visited: var HashSet[string], 
                stack: var seq[string]): bool =
    visited.incl(node)
    stack.add(node)
    
    if node in result.edges:
      for neighbor in result.edges[node]:
        if neighbor notin visited:
          if hasCycle(neighbor, visited, stack):
            return true
        elif neighbor in stack:
          # Found cycle
          let cycleStart = stack.find(neighbor)
          result.cycles.add(stack[cycleStart..^1])
          return true
    
    discard stack.pop()
    return false
  
  var visited = initHashSet[string]()
  var stack: seq[string] = @[]
  
  for node in result.nodes.keys:
    if node notin visited:
      discard hasCycle(node, visited, stack)
  
  echo &"  Packages: {result.nodes.len}"
  echo &"  Dependencies: {result.edges.values.toSeq.mapIt(it.len).foldl(a + b, 0)}"
  echo &"  Cycles detected: {result.cycles.len}"

proc handle_installWorkspaceDeps*(actor: Actor, message: installWorkspaceDeps*Message): ActorResponse =
  ## Installs all workspace dependencies with hoisting
  echo "\nInstalling workspace dependencies..."
  echo &"Hoisting strategy: {workspace.config.hoistingStrategy}"
  
  # Collect all dependencies
  var allDeps = initTable[string, seq[(string, string)]]()  # dep -> [(pkg, version)]
  
  for pkg in workspace.packages:
    for dep, ver in pkg.dependencies:
      if not dep.startsWith("@platform/"):  # External dependency
        if dep notin allDeps:
          allDeps[dep] = @[]
        allDeps[dep].add((pkg.name, ver))
  
    for dep, ver in pkg.devDependencies:
      if dep notin allDeps:
        allDeps[dep] = @[]
      allDeps[dep].add((pkg.name & " (dev)", ver))
  
  # Determine what to hoist
  var toHoist = initTable[string, string]()  # dep -> version
  var toInstallLocal = initTable[string, seq[(string, string)]]()  # pkg -> [(dep, ver)]
  
  for dep, versions in allDeps:
    let uniqueVersions = versions.mapIt(it[1]).deduplicate()
    
    case workspace.config.hoistingStrategy:
      of hsNone:
        # Install everything locally
        for (pkg, ver) in versions:
          if pkg notin toInstallLocal:
            toInstallLocal[pkg] = @[]
          toInstallLocal[pkg].add((dep, ver))
      
      of hsConservative:
        # Hoist only if all packages use same version
        if uniqueVersions.len == 1:
          toHoist[dep] = uniqueVersions[0]
          echo &"  Hoisting {dep}@{uniqueVersions[0]} (used by {versions.len} packages)"
        else:
          echo &"  Not hoisting {dep} (version conflict: {uniqueVersions})"
          for (pkg, ver) in versions:
            if pkg notin toInstallLocal:
              toInstallLocal[pkg] = @[]
            toInstallLocal[pkg].add((dep, ver))
      
      of hsAggressive:
        # Hoist most common version
        var versionCounts = initCountTable[string]()
        for (_, ver) in versions:
          versionCounts.inc(ver)
        let mostCommon = versionCounts.largest
        toHoist[dep] = mostCommon.key
        echo &"  Hoisting {dep}@{mostCommon.key} (most common version)"
  
  # Install hoisted dependencies
  if toHoist.len > 0:
    echo &"\nInstalling {toHoist.len} hoisted dependencies..."
    # Simulate parallel installation
    sendMessage(sleepAsync(1000)
    echo "✓ Hoisted dependencies installed"
  
  # Install local dependencies
  if toInstallLocal.len > 0:
    echo &"\nInstalling local dependencies for {toInstallLocal.len} packages..."
    for pkg, deps in toInstallLocal:
      echo &"  {pkg}: {deps.len} dependencies"
    sendMessage(sleepAsync(500)
    echo "✓ Local dependencies installed"
  
  # Link workspace packages
  echo "\nLinking workspace packages..."
  for pkg in workspace.packages:
    for dep, ver in pkg.dependencies:
      if dep.startsWith("@platform/"):
        echo &"  Linking {dep} -> {pkg.name}"
  echo "✓ Workspace packages linked"

proc handle_runWorkspaceTask*(actor: Actor, message: runWorkspaceTask*Message): ActorResponse =
  ## Runs a task across workspace packages
  echo &"\nRunning task: {task.name}"
  echo &"Packages: {task.packages.join(\", \")}"
  echo &"Command: {task.command}"
  echo &"Parallel: {task.parallel}"
  echo "=".repeat((50)
  
  let targetPackages = if task.packages.len == 0:
    workspace.packages
  else:
    workspace.packages.filterIt(it.name in task.packages)
  
  if task.parallel and targetPackages.len > 1:
    echo &"\nRunning in parallel ({workspace.config.parallelism} workers)..."
    
    var futures: seq[Future[void]]
    for pkg in targetPackages:
      let f = async do:
        echo &"  [{pkg.name}] Starting: {task.command}"
        sendMessage(sleepAsync(rand(500..1500))  # Simulate command execution
        echo &"  [{pkg.name}] ✓ Completed"
      futures.add(f)
    
    sendMessage(all(futures)
  else:
    echo "\nRunning sequentially..."
    for pkg in targetPackages:
      echo &"  [{pkg.name}] Running: {task.command}"
      sendMessage(sleepAsync(500)  # Simulate command execution
      echo &"  [{pkg.name}] ✓ Completed"
  
  echo "\n✓ Task completed successfully"

proc syncWorkspaceVersions*(workspace: var Workspace) =
  ## Synchronizes versions across workspace packages
  echo "\nSynchronizing workspace package versions..."
  
  # Find workspace dependencies that need syncing
  var versionMap = initTable[string, string]()
  
  for pkg in workspace.packages:
    versionMap[pkg.name] = pkg.version
  
  var updates = 0
  for pkg in workspace.packages.mitems:
    for dep, ver in pkg.dependencies.mpairs:
      if dep in versionMap and ver == "workspace:*":
        let actualVersion = &"^{versionMap[dep]}"
        echo &"  Updating {pkg.name}: {dep} -> {actualVersion}"
        pkg.dependencies[dep] = actualVersion
        updates += 1
  
  echo &"\n✓ Synchronized {updates} dependency references"

proc handle_publishWorkspacePackages*(actor: Actor, message: publishWorkspacePackages*Message): ActorResponse =
  ## Publishes workspace packages in dependency order
  echo "\nPublishing workspace packages..."
  
  let graph = analyzeDependencyGraph(workspace)
  
  # Topological sort for publish order
  var publishOrder: seq[string] = @[]
  var visited = initHashSet[string]()
  
  proc visit(pkg: string) =
    if pkg in visited:
      return
    visited.incl(pkg)
    
    if pkg in graph.edges:
      for dep in graph.edges[pkg]:
        visit(dep)
    
    publishOrder.add(pkg)
  
  let targetPackages = if packages.len == 0:
    workspace.packages.filterIt(not it.isPrivate).mapIt(it.name)
  else:
    packages
  
  for pkg in targetPackages:
    visit(pkg)
  
  publishOrder = publishOrder.reversed()
  
  echo "\nPublish order:"
  for i, pkg in publishOrder:
    echo &"  {i + 1}. {pkg}"
  
  echo "\nPublishing packages..."
  for pkg in publishOrder:
    let package = workspace.packages.filterIt(it.name == pkg)[0]
    echo &"  Publishing {pkg}@{package.version}..."
    sendMessage(sleepAsync(1000)  # Simulate publish
    echo &"  ✓ Published {pkg}"
  
  echo "\n✓ All packages published successfully"

# Advanced workspace features
proc generateWorkspaceReport*(workspace: Workspace): JsonNode =
  ## Generates comprehensive workspace analysis report
  let graph = analyzeDependencyGraph(workspace)
  
  result = %* {
    "workspace": workspace.name,
    "generated": now().format("yyyy-MM-dd HH:mm:ss"),
    "statistics": {
      "total_packages": workspace.packages.len,
      "private_packages": workspace.packages.filterIt(it.isPrivate).len,
      "public_packages": workspace.packages.filterIt(not it.isPrivate).len,
      "total_dependencies": 0,
      "workspace_dependencies": 0,
      "external_dependencies": 0
    },
    "packages": [],
    "dependency_graph": {
      "nodes": graph.nodes.len,
      "edges": graph.edges.values.toSeq.mapIt(it.len).foldl(a + b, 0),
      "cycles": graph.cycles
    },
    "insights": [],
    "recommendations": []
  }
  
  # Count dependencies
  for pkg in workspace.packages:
    let workspaceDeps = pkg.dependencies.keys.toSeq.filterIt(it.startsWith("@platform/")).len
    let externalDeps = pkg.dependencies.len - workspaceDeps
    
    result["statistics"]["total_dependencies"] = 
      result["statistics"]["total_dependencies"].getInt + pkg.dependencies.len
    result["statistics"]["workspace_dependencies"] = 
      result["statistics"]["workspace_dependencies"].getInt + workspaceDeps
    result["statistics"]["external_dependencies"] = 
      result["statistics"]["external_dependencies"].getInt + externalDeps
    
    result["packages"].add(%* {
      "name": pkg.name,
      "version": pkg.version,
      "path": pkg.path,
      "private": pkg.isPrivate,
      "dependencies": pkg.dependencies.len,
      "workspace_deps": workspaceDeps,
      "external_deps": externalDeps,
      "scripts": pkg.scripts.keys.toSeq
    })
  
  # Generate insights
  if graph.cycles.len > 0:
    result["insights"].add(%"Circular dependencies detected")
    result["recommendations"].add(%"Refactor to remove circular dependencies")
  
  let avgDeps = result["statistics"]["total_dependencies"].getInt / workspace.packages.len
  if avgDeps > 10:
    result["insights"].add(%&"High average dependencies per package: {avgDeps:.1f}")
    result["recommendations"].add(%"Consider reducing package coupling")

# Example workflow demonstration
proc demonstrateWorkspaceManagement*() {.async.} =
  echo "Workspace Management Demonstration"
  echo "================================="
  
  # Use example workspace
  var workspace = exampleWorkspace
  
  # Discover packages
  discoverPackages(workspace)
  
  # Analyze dependencies
  let graph = analyzeDependencyGraph(workspace)
  
  # Install dependencies
  sendMessage(installWorkspaceDeps(workspace)
  
  # Run workspace tasks
  echo "\n" & "=".repeat((60)
  let buildTask = WorkspaceTask(
    name: "build",
    packages: @[],  # All packages
    command: "nimble build",
    parallel: true,
    continueOnError: false
  )
  sendMessage(runWorkspaceTask(workspace, buildTask)
  
  echo "\n" & "=".repeat((60)
  let testTask = WorkspaceTask(
    name: "test",
    packages: @["@platform/core", "@platform/auth"],
    command: "nimble test",
    parallel: true,
    continueOnError: true
  )
  sendMessage(runWorkspaceTask(workspace, testTask)
  
  # Sync versions
  syncWorkspaceVersions(workspace)
  
  # Simulate publishing
  echo "\n" & "=".repeat((60)
  sendMessage(publishWorkspacePackages(workspace, @["@platform/core", "@platform/auth"])
  
  # Generate report
  let outputDir = "build/workspace-reports"
  createDir(outputDir)
  
  let report = generateWorkspaceReport(workspace)
  writeFile(outputDir / "workspace-report.json", report.pretty)
  
  echo &"\n\nWorkspace report saved to: {outputDir}/workspace-report.json"
  
  echo "\nKey Insights:"
  for insight in report["insights"]:
    echo &"  • {insight.getStr}"
  
  echo "\nRecommendations:"
  for rec in report["recommendations"]:
    echo &"  • {rec.getStr}"

when isMainModule:
  waitFor demonstrateWorkspaceManagement()
# Actor framework integration
type
  FileActor = ref object of Actor
    state: ActorState

proc newFileActor(): FileActor =
  result = FileActor()
  result.state = newActorState()

proc processMessage(actor: FileActor, message: Message): ActorResponse =
  # Process messages through gennethleia framework
  actor.state.processMessage(message)
