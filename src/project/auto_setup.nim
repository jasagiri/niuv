## Auto-setup module for niuv projects
## Automatically configures niuv.toml for projects

import std/[os, strutils, strformat, terminal, parsecfg, sequtils]
import ../cli, ../utils

type
  ProjectType* = enum
    Library,
    Application, 
    Framework,
    Service,
    Tool,
    Unknown

  ProjectTemplate* = object
    projectType*: ProjectType
    mainFile*: string
    srcDir*: string
    testDirs*: seq[string]
    buildTasks*: seq[string]
    dependencies*: seq[string]

const
  DEFAULT_TEMPLATES* = [
    ProjectTemplate(
      projectType: Library,
      mainFile: "lib.nim",
      srcDir: "src",
      testDirs: @["tests"],
      buildTasks: @["test", "docs"],
      dependencies: @[]
    ),
    ProjectTemplate(
      projectType: Application,
      mainFile: "main.nim", 
      srcDir: "src",
      testDirs: @["tests"],
      buildTasks: @["build", "test", "run"],
      dependencies: @[]
    ),
    ProjectTemplate(
      projectType: Framework,
      mainFile: "framework.nim",
      srcDir: "src", 
      testDirs: @["tests", "spec"],
      buildTasks: @["test", "docs", "examples"],
      dependencies: @[]
    )
  ]

proc detectProjectType(projectPath: string): ProjectType =
  ## Auto-detect project type based on structure and files
  
  # Check for specific framework indicators
  if fileExists(projectPath / "framework.nim") or 
     dirExists(projectPath / "src" / "framework"):
    return Framework
  
  # Check for service indicators  
  if fileExists(projectPath / "service.nim") or
     fileExists(projectPath / "server.nim") or
     dirExists(projectPath / "api"):
    return Service
    
  # Check for tool indicators
  if fileExists(projectPath / "cli.nim") or
     fileExists(projectPath / "cmd.nim") or
     fileExists(projectPath / "tool.nim"):
    return Tool
  
  # Check for main executable
  if fileExists(projectPath / "main.nim") or
     fileExists(projectPath / "src" / "main.nim") or
     fileExists(projectPath / "app.nim"):
    return Application
  
  # Default to library
  return Library

proc findMainFile(projectPath: string, projectType: ProjectType): string =
  ## Find the main source file for the project
  let projectName = projectPath.lastPathPart()
  let projectNameUnderscore = projectName.replace("-", "_")
  
  # Common main file patterns
  var candidates = @[
    # Project-specific names
    projectName & ".nim",
    projectNameUnderscore & ".nim",
    "src" / projectName & ".nim", 
    "src" / projectNameUnderscore & ".nim"
  ]
  
  # Add type-specific names
  let typeSpecific = case projectType:
    of Application: @["main.nim", "src/main.nim", "app.nim"]
    of Library: @["lib.nim", "src/lib.nim"]
    of Framework: @["framework.nim", "src/framework.nim"]
    of Service: @["service.nim", "src/service.nim", "server.nim"]
    of Tool: @["cli.nim", "src/cli.nim", "tool.nim"]
    of Unknown: @["main.nim"]
  
  candidates.add(typeSpecific)
  
  # Find first existing file
  for candidate in candidates:
    if fileExists(projectPath / candidate):
      return candidate
  
  # Return default based on project type
  case projectType:
  of Application: "src/main.nim"
  of Library: "src/" & projectNameUnderscore & ".nim"
  of Framework: "src/framework.nim"
  of Service: "src/service.nim" 
  of Tool: "src/cli.nim"
  of Unknown: "src/main.nim"

proc detectTestDirectories(projectPath: string): seq[string] =
  ## Detect existing test directories
  result = @[]
  
  let candidates = @["tests", "test", "spec", "testing"]
  for candidate in candidates:
    if dirExists(projectPath / candidate):
      result.add(candidate)
  
  # Default to tests if none found
  if result.len == 0:
    result.add("tests")

proc generateNiuvToml(projectPath: string, tmpl: ProjectTemplate): string =
  ## Generate niuv.toml content based on template
  let projectName = projectPath.lastPathPart()
  let mainFile = findMainFile(projectPath, tmpl.projectType)
  let testDirs = detectTestDirectories(projectPath)
  
  result = &"""[package]
name = "{projectName}"
version = "0.1.0"

[build]
src_dir = "{tmpl.srcDir}"
main_file = "{mainFile}"
output_dir = ".build"

[test]
test_dirs = {testDirs}
test_pattern = "test_*.nim"

[tasks]
# Core build and test
build = "nim c -o:.build/{projectName} {tmpl.srcDir}/{mainFile}"
test = "cd tests && nim c -r test_all.nim"

# Quality assurance
clean = "find . -name 'nimcache' -type d -exec rm -rf {{}} + 2>/dev/null || true && find . -name '*.exe' -type f -delete 2>/dev/null || true"
docs = "cd {tmpl.srcDir} && nim doc {mainFile.lastPathPart()} && mv *.html ../docs/api/ 2>/dev/null || true"

# Development
check = "nim check {tmpl.srcDir}/{mainFile}"
format = "nimpretty {tmpl.srcDir}/**/*.nim"
"""

  # Add project-type specific tasks
  case tmpl.projectType:
  of Application:
    result &= """
# Application specific
run = "./.build/{projectName}"
debug = "nim c -d:debug {tmpl.srcDir}/{mainFile}"
release = "nim c -d:release --opt:speed {tmpl.srcDir}/{mainFile}"
"""
  of Library:
    result &= """
# Library specific
examples = "cd examples && find . -name '*.nim' -exec nim c -r {} \\;"
package = "nimble build"
"""
  of Framework:
    result &= """
# Framework specific
examples = "cd examples && find . -name '*.nim' -exec nim c -r {} \\;"
benchmark = "cd benchmarks && nim c -d:release -r benchmark.nim"
"""
  of Service:
    result &= """
# Service specific
start = "./.build/{projectName} --daemon"
stop = "pkill -f {projectName}"
status = "pgrep -f {projectName}"
"""
  of Tool:
    result &= """
# Tool specific  
install = "cp .build/{projectName} ~/.local/bin/"
uninstall = "rm -f ~/.local/bin/{projectName}"
"""
  of Unknown:
    discard

proc autoSetupProject*(projectPath: string = ".", force: bool = false): bool =
  ## Auto-setup niuv.toml for current project
  let niuvTomlPath = projectPath / "niuv.toml"
  
  # Check if already exists
  if fileExists(niuvTomlPath) and not force:
    styledEcho(fgYellow, "niuv.toml already exists. Use --force to overwrite.")
    return false
  
  styledEcho(fgCyan, "🔧 Auto-setting up niuv project...")
  echo ""
  
  # Detect project type
  let projectType = detectProjectType(projectPath)
  styledEcho(fgWhite, "Detected project type: ", fgCyan, $projectType)
  
  # Find template
  let tmpl = DEFAULT_TEMPLATES.filterIt(it.projectType == projectType)[0]
  
  # Generate niuv.toml
  let content = generateNiuvToml(projectPath, tmpl)
  
  try:
    writeFile(niuvTomlPath, content)
    styledEcho(fgGreen, "✓ Created niuv.toml")
    
    # Show what was detected/created
    echo ""
    echo "Configuration:"
    echo &"  Project: {projectPath.lastPathPart()}"
    echo &"  Type: {projectType}"
    echo &"  Main file: {findMainFile(projectPath, projectType)}"
    echo &"  Test dirs: {detectTestDirectories(projectPath)}"
    echo ""
    
    styledEcho(fgGreen, "✓ Project setup complete!")
    echo ""
    echo "You can now use:"
    echo "  niuv build    # Build the project"
    echo "  niuv test     # Run tests"
    echo "  niuv clean    # Clean artifacts"
    echo ""
    
    return true
  except:
    styledEcho(fgRed, "✗ Failed to create niuv.toml")
    return false

proc autoSetupCommand*(args: seq[string]): int =
  ## Handle 'niuv auto-setup' command
  if "--help" in args or "-h" in args:
    echo """
niuv auto-setup - Automatically configure niuv.toml for current project

Usage:
  niuv auto-setup [options] [path]

Options:
  --force        Overwrite existing niuv.toml
  --help, -h     Show this help

This command:
1. Detects project type (library/application/framework/service/tool)
2. Finds main source file automatically  
3. Detects test directories
4. Generates appropriate niuv.toml with relevant tasks
5. Provides cargo-like development experience

Examples:
  niuv auto-setup           # Setup current directory
  niuv auto-setup --force   # Overwrite existing configuration
  niuv auto-setup ../myapp  # Setup different directory
"""
    return 0
  
  var projectPath = "."
  var force = false
  
  # Parse arguments
  for arg in args:
    case arg:
    of "--force":
      force = true
    else:
      if not arg.startsWith("-"):
        projectPath = arg
  
  # Ensure path exists
  if not dirExists(projectPath):
    styledEcho(fgRed, "Error: Directory does not exist: ", projectPath)
    return 1
  
  # Run auto-setup
  if autoSetupProject(projectPath, force):
    return 0
  else:
    return 1