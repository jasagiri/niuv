## Package resolver module for niuv
## Implements a SAT solver-based dependency resolution engine

import std/[tables, sets, sequtils, strutils, options, json, hashes, algorithm]

type
  Version* = object
    major*, minor*, patch*: int
    prerelease*: string
    build*: string

  VersionConstraint* = object
    operator*: string  # "=", ">=", ">", "<=", "<", "~>", "^"
    version*: Version

  Package* = object
    name*: string
    version*: Version
    dependencies*: Table[string, seq[VersionConstraint]]
    checksum*: string
    url*: string

  PackageRef* = object
    name*: string
    constraints*: seq[VersionConstraint]

  ResolutionStrategy* = enum
    rsLatest = "latest"      # Prefer latest versions
    rsMinimal = "minimal"    # Prefer minimal versions
    rsConservative = "conservative"  # Prefer currently installed versions

  PackageCache* = ref object
    packages*: Table[string, seq[Package]]  # name -> available versions
    resolved*: Table[string, Package]       # name -> resolved package

  SATVariable* = object
    package*: string
    version*: Version

  SATClause* = seq[tuple[variable: SATVariable, positive: bool]]

  SATSolver* = ref object
    variables*: seq[SATVariable]
    clauses*: seq[SATClause]
    assignment*: Table[SATVariable, bool]

  ResolutionResult* = object
    case success*: bool
    of true:
      packages*: seq[Package]
    of false:
      error*: string
      conflicts*: seq[tuple[pkg: string, reason: string]]

  PackageResolver* = ref object
    strategy*: ResolutionStrategy
    cache*: PackageCache
    solver*: SATSolver

proc hash*(v: Version): Hash =
  result = hash(v.major) !& hash(v.minor) !& hash(v.patch) !& hash(v.prerelease)
  result = !$result

proc `==`*(a, b: Version): bool =
  a.major == b.major and
  a.minor == b.minor and
  a.patch == b.patch and
  a.prerelease == b.prerelease

proc hash*(v: SATVariable): Hash =
  result = hash(v.package) !& hash(v.version)
  result = !$result

proc `==`*(a, b: SATVariable): bool =
  a.package == b.package and a.version == b.version

proc parseVersion*(s: string): Version =
  ## Parse a semantic version string
  result = Version()
  let parts = s.split('-', 1)
  let versionPart = parts[0]
  
  if parts.len > 1:
    let buildParts = parts[1].split('+', 1)
    result.prerelease = buildParts[0]
    if buildParts.len > 1:
      result.build = buildParts[1]
  
  let numbers = versionPart.split('.')
  if numbers.len >= 1: result.major = parseInt(numbers[0])
  if numbers.len >= 2: result.minor = parseInt(numbers[1])
  if numbers.len >= 3: result.patch = parseInt(numbers[2])

proc `$`*(v: Version): string =
  result = $v.major & "." & $v.minor & "." & $v.patch
  if v.prerelease != "":
    result &= "-" & v.prerelease
  if v.build != "":
    result &= "+" & v.build

proc `<`*(a, b: Version): bool =
  if a.major != b.major: return a.major < b.major
  if a.minor != b.minor: return a.minor < b.minor
  if a.patch != b.patch: return a.patch < b.patch
  
  # Handle prerelease versions
  if a.prerelease == "" and b.prerelease != "": return false
  if a.prerelease != "" and b.prerelease == "": return true
  if a.prerelease != "" and b.prerelease != "":
    return a.prerelease < b.prerelease
  
  return false

proc `<=`*(a, b: Version): bool = a == b or a < b
proc `>`*(a, b: Version): bool = not (a <= b)
proc `>=`*(a, b: Version): bool = not (a < b)

proc satisfies*(v: Version, constraint: VersionConstraint): bool =
  ## Check if a version satisfies a constraint
  case constraint.operator
  of "=", "==":
    result = v == constraint.version
  of ">=":
    result = v >= constraint.version
  of ">":
    result = v > constraint.version
  of "<=":
    result = v <= constraint.version
  of "<":
    result = v < constraint.version
  of "~>":
    # Pessimistic constraint: ~> 1.2.3 means >= 1.2.3 and < 1.3.0
    result = v >= constraint.version and 
             v.major == constraint.version.major and
             v.minor == constraint.version.minor
  of "^":
    # Caret constraint: ^1.2.3 means >= 1.2.3 and < 2.0.0
    result = v >= constraint.version and v.major == constraint.version.major
  else:
    result = false

proc parseConstraint*(s: string): VersionConstraint =
  ## Parse a version constraint string
  let s = s.strip()
  
  # Extract operator
  var opLen = 0
  if s.startsWith(">=") or s.startsWith("<=") or s.startsWith("~>"):
    opLen = 2
    result.operator = s[0..1]
  elif s.startsWith(">") or s.startsWith("<") or s.startsWith("^"):
    opLen = 1
    result.operator = s[0..0]
  elif s.startsWith("="):
    opLen = 1
    result.operator = "="
  else:
    # No operator means exact match
    result.operator = "="
  
  # Parse version
  let versionStr = s[opLen..^1].strip()
  result.version = parseVersion(versionStr)

proc newPackageCache*(): PackageCache =
  result = PackageCache(
    packages: initTable[string, seq[Package]](),
    resolved: initTable[string, Package]()
  )

proc addPackage*(cache: PackageCache, pkg: Package) =
  ## Add a package to the cache
  if pkg.name notin cache.packages:
    cache.packages[pkg.name] = @[]
  cache.packages[pkg.name].add(pkg)
  
  # Sort by version (latest first)
  cache.packages[pkg.name].sort(proc (a, b: Package): int =
    if a.version > b.version: -1
    elif a.version < b.version: 1
    else: 0
  )

proc getPackageVersions*(cache: PackageCache, name: string): seq[Package] =
  ## Get all available versions of a package
  if name in cache.packages:
    result = cache.packages[name]
  else:
    result = @[]

proc newSATSolver*(): SATSolver =
  result = SATSolver(
    variables: @[],
    clauses: @[],
    assignment: initTable[SATVariable, bool]()
  )

proc addVariable*(solver: SATSolver, pkg: string, version: Version) =
  ## Add a variable to the SAT solver
  let variable = SATVariable(package: pkg, version: version)
  if variable notin solver.variables:
    solver.variables.add(variable)

proc addClause*(solver: SATSolver, clause: SATClause) =
  ## Add a clause to the SAT solver
  solver.clauses.add(clause)

proc addImplication*(solver: SATSolver, 
                    antecedent: SATVariable, 
                    consequent: SATVariable, 
                    positive: bool = true) =
  ## Add an implication: if antecedent then consequent
  ## Translates to: NOT antecedent OR consequent
  solver.addClause(@[
    (variable: antecedent, positive: false),
    (variable: consequent, positive: positive)
  ])

proc addConflict*(solver: SATSolver, var1, var2: SATVariable) =
  ## Add a conflict: var1 and var2 cannot both be true
  ## Translates to: NOT var1 OR NOT var2
  solver.addClause(@[
    (variable: var1, positive: false),
    (variable: var2, positive: false)
  ])

proc addAtMostOne*(solver: SATSolver, variables: seq[SATVariable]) =
  ## Ensure at most one of the variables is true
  for i in 0..<variables.len:
    for j in i+1..<variables.len:
      solver.addConflict(variables[i], variables[j])

proc addExactlyOne*(solver: SATSolver, variables: seq[SATVariable]) =
  ## Ensure exactly one of the variables is true
  # At least one must be true
  var clause: SATClause = @[]
  for v in variables:
    clause.add((variable: v, positive: true))
  solver.addClause(clause)
  
  # At most one must be true
  solver.addAtMostOne(variables)

proc solve*(solver: SATSolver): bool =
  ## Simple DPLL SAT solver implementation
  ## Returns true if a satisfying assignment exists
  
  # Unit propagation
  proc unitPropagate(): bool =
    var changed = true
    while changed:
      changed = false
      for clause in solver.clauses:
        var unassigned: seq[tuple[variable: SATVariable, positive: bool]] = @[]
        var satisfied = false
        
        for lit in clause:
          if lit.variable in solver.assignment:
            if solver.assignment[lit.variable] == lit.positive:
              satisfied = true
              break
          else:
            unassigned.add(lit)
        
        if satisfied:
          continue
        
        if unassigned.len == 0:
          # Conflict: clause cannot be satisfied
          return false
        elif unassigned.len == 1:
          # Unit clause: must assign this literal
          solver.assignment[unassigned[0].variable] = unassigned[0].positive
          changed = true
    
    return true
  
  # Check if all clauses are satisfied
  proc allSatisfied(): bool =
    for clause in solver.clauses:
      var satisfied = false
      for lit in clause:
        if lit.variable in solver.assignment and
           solver.assignment[lit.variable] == lit.positive:
          satisfied = true
          break
      if not satisfied:
        return false
    return true
  
  # DPLL algorithm
  proc dpll(): bool =
    if not unitPropagate():
      return false
    
    if allSatisfied():
      return true
    
    # Find an unassigned variable
    for v in solver.variables:
      if v notin solver.assignment:
        # Try true
        solver.assignment[v] = true
        if dpll():
          return true
        
        # Backtrack and try false
        solver.assignment.del(v)
        solver.assignment[v] = false
        if dpll():
          return true
        
        # Backtrack
        solver.assignment.del(v)
        return false
    
    return false
  
  return dpll()

proc newPackageResolver*(strategy: ResolutionStrategy = rsLatest): PackageResolver =
  result = PackageResolver(
    strategy: strategy,
    cache: newPackageCache(),
    solver: newSATSolver()
  )

proc buildDependencyGraph*(resolver: PackageResolver, 
                          rootDeps: seq[PackageRef]): ResolutionResult =
  ## Build the dependency graph and prepare the SAT problem
  
  # Initialize with success case
  result = ResolutionResult(success: true, packages: @[])
  
  # First, collect all packages and their versions
  var packageVersions: Table[string, seq[SATVariable]]
  packageVersions = initTable[string, seq[SATVariable]]()
  
  # Track errors
  var errorMsg = ""
  var hasError = false
  var conflicts: seq[tuple[pkg: string, reason: string]] = @[]
  
  # Queue of packages to process
  var toProcess = rootDeps
  var processed: HashSet[string] = initHashSet[string]()
  
  # Process packages iteratively
  while toProcess.len > 0 and not hasError:
    let pkgRef = toProcess[0]
    toProcess.delete(0)
    
    if pkgRef.name in processed:
      continue
    processed.incl(pkgRef.name)
    
    let versions = resolver.cache.getPackageVersions(pkgRef.name)
    if versions.len == 0:
      hasError = true
      errorMsg = "Package not found: " & pkgRef.name
      break
    
    packageVersions[pkgRef.name] = @[]
    
    for pkg in versions:
      var satisfiesAny = false
      for constraint in pkgRef.constraints:
        if pkg.version.satisfies(constraint):
          satisfiesAny = true
          break
      
      if satisfiesAny or pkgRef.constraints.len == 0:
        let variable = SATVariable(package: pkg.name, version: pkg.version)
        resolver.solver.addVariable(pkg.name, pkg.version)
        packageVersions[pkgRef.name].add(variable)
        
        # Add this package's dependencies to the queue
        for depName, constraints in pkg.dependencies:
          if depName notin processed:
            toProcess.add(PackageRef(name: depName, constraints: constraints))
  
  if hasError:
    result = ResolutionResult(success: false, error: errorMsg, conflicts: conflicts)
    return result
  
  # Add constraints for each package
  for pkgName, variables in packageVersions:
    if variables.len > 0:
      # Exactly one version of each package must be selected
      resolver.solver.addExactlyOne(variables)
  
  # Add dependency constraints
  for pkgName, variables in packageVersions:
    for variable in variables:
      # Find the actual package
      let versions = resolver.cache.getPackageVersions(pkgName)
      for pkg in versions:
        if pkg.version == variable.version:
          # Add constraints for this package's dependencies
          for depName, constraints in pkg.dependencies:
            if depName in packageVersions:
              var satisfyingVars: seq[SATVariable] = @[]
              for depVar in packageVersions[depName]:
                var satisfies = true
                for constraint in constraints:
                  if not depVar.version.satisfies(constraint):
                    satisfies = false
                    break
                
                if satisfies:
                  satisfyingVars.add(depVar)
              
              if satisfyingVars.len == 0:
                conflicts.add((pkg: pkgName, 
                  reason: "requires " & depName & " " & constraints.mapIt($it.operator & $it.version).join(", ")))
                hasError = true
                errorMsg = "No version of " & depName & " satisfies constraints from " & pkgName
              else:
                # If this package is selected, one of the satisfying versions must be selected
                for satisfyingVar in satisfyingVars:
                  resolver.solver.addImplication(variable, satisfyingVar)
  
  if hasError:
    result = ResolutionResult(success: false, error: errorMsg, conflicts: conflicts)
    return result

proc resolvePackages*(resolver: PackageResolver, 
                     deps: seq[PackageRef]): ResolutionResult =
  ## Resolve package dependencies using SAT solver
  
  # Build dependency graph
  result = resolver.buildDependencyGraph(deps)
  if not result.success:
    return result
  
  # Solve the SAT problem
  if not resolver.solver.solve():
    # Create a new result with conflicts from the dependency graph building
    var conflicts: seq[tuple[pkg: string, reason: string]] = @[]
    if not result.success:
      conflicts = result.conflicts
    
    result = ResolutionResult(
      success: false, 
      error: "Could not find a satisfying package assignment",
      conflicts: conflicts
    )
    return result
  
  # Extract the solution
  var packages: seq[Package] = @[]
  
  for variable, assigned in resolver.solver.assignment:
    if assigned:
      # Find the actual package
      let versions = resolver.cache.getPackageVersions(variable.package)
      for pkg in versions:
        if pkg.version == variable.version:
          packages.add(pkg)
          resolver.cache.resolved[pkg.name] = pkg
          break
  
  result = ResolutionResult(success: true, packages: packages)
  return result

proc resolveFromLockfile*(resolver: PackageResolver, 
                         lockfile: JsonNode): ResolutionResult =
  ## Resolve packages from a lockfile
  var packages: seq[Package] = @[]
  
  if lockfile.hasKey("packages"):
    for pkgNode in lockfile["packages"]:
      var pkg = Package(
        name: pkgNode["name"].getStr(),
        version: parseVersion(pkgNode["version"].getStr()),
        url: pkgNode.getOrDefault("url").getStr(""),
        checksum: pkgNode.getOrDefault("checksum").getStr("")
      )
      
      if pkgNode.hasKey("dependencies"):
        pkg.dependencies = initTable[string, seq[VersionConstraint]]()
        for depName, constraints in pkgNode["dependencies"]:
          pkg.dependencies[depName] = @[]
          for constraintStr in constraints:
            pkg.dependencies[depName].add(parseConstraint(constraintStr.getStr()))
      
      packages.add(pkg)
      resolver.cache.resolved[pkg.name] = pkg
  
  result = ResolutionResult(success: true, packages: packages)
  return result

proc saveLockfile*(packages: seq[Package], filename: string) =
  ## Save resolved packages to a lockfile
  var lockfile = %* {
    "version": "1.0.0",
    "packages": []
  }
  
  for pkg in packages:
    var pkgNode = %* {
      "name": pkg.name,
      "version": $pkg.version,
      "url": pkg.url,
      "checksum": pkg.checksum
    }
    
    if pkg.dependencies.len > 0:
      pkgNode["dependencies"] = newJObject()
      for depName, constraints in pkg.dependencies:
        pkgNode["dependencies"][depName] = newJArray()
        for constraint in constraints:
          pkgNode["dependencies"][depName].add(%($constraint.operator & $constraint.version))
    
    lockfile["packages"].add(pkgNode)
  
  writeFile(filename, lockfile.pretty())