## workspace/reporting.nim
## =======================
##
## Workspace-specific test reporting functionality for niuv
## Provides multi-project workspace test result aggregation and reporting

import std/[strformat, strutils, os, tables, times, sequtils]
import "../../../nim-testkit/src/reporting"

# Re-export nim-testkit types
export reporting.ReportFormatter
export reporting.EnhancedTestStatistics
export reporting.TestResult
export reporting.TestStatus
export reporting.TestCategory

# Workspace-specific types
type
  ProjectInfo* = object
    name*: string
    path*: string
    nimbleFile*: string
    dependencies*: seq[string]
    testResults*: seq[TestResult]
    stats*: EnhancedTestStatistics

  WorkspaceContext* = object
    rootPath*: string
    configFile*: string  # niuv.workspace.toml
    projects*: seq[ProjectInfo]
    totalProjects*: int
    parallelExecution*: bool

  WorkspaceReportFormatter* = ref object of ReportFormatter
    context*: WorkspaceContext
    showProjectBreakdown*: bool
    showDependencyMatrix*: bool
    showCrossProjectStats*: bool
    aggregateResults*: bool

# Workspace reporting procedures
proc newWorkspaceReportFormatter*(context: WorkspaceContext,
                                  showBreakdown = true,
                                  showMatrix = false,
                                  showCrossStats = true,
                                  aggregate = true): WorkspaceReportFormatter =
  result = WorkspaceReportFormatter(
    context: context,
    showProjectBreakdown: showBreakdown,
    showDependencyMatrix: showMatrix,
    showCrossProjectStats: showCrossStats,
    aggregateResults: aggregate,
    colored: true,
    showStackTrace: false,
    verbosityLevel: 1
  )

method beginTesting*(formatter: WorkspaceReportFormatter) =
  ## Workspace-specific test initialization
  echo "\n" & "=".repeat(70)
  echo "Niuv Workspace Test Report"
  echo "=".repeat(70)
  
  echo fmt"Workspace: {formatter.context.rootPath}"
  if formatter.context.configFile.len > 0 and fileExists(formatter.context.configFile):
    echo fmt"Config: {formatter.context.configFile}"
  echo fmt"Projects: {formatter.context.totalProjects}"
  
  if formatter.context.parallelExecution:
    echo "Execution: Parallel"
  else:
    echo "Execution: Sequential"
  
  if formatter.showProjectBreakdown and formatter.context.projects.len > 0:
    echo "\nProjects in workspace:"
    for i, project in formatter.context.projects:
      echo fmt"  {i+1}. {project.name} ({project.path})"
      if project.dependencies.len > 0:
        echo fmt"     Dependencies: {project.dependencies.join(", ")}"
  
  echo "\nStarting workspace tests..."
  echo "-".repeat(70)

method endTesting*(formatter: WorkspaceReportFormatter, stats: EnhancedTestStatistics) =
  ## Workspace-specific test completion with cross-project analysis
  echo "-".repeat(70)
  echo "Workspace Test Execution Complete"
  
  # Overall statistics
  echo fmt"\nOverall Results: {stats.total} tests across {formatter.context.totalProjects} projects"
  echo fmt"Passed: {stats.passed}, Failed: {stats.failed}, Skipped: {stats.skipped}, Errors: {stats.errors}"
  echo fmt"Total Duration: {stats.duration:.3f} seconds"
  
  if formatter.showProjectBreakdown:
    echo "\nProject Breakdown:"
    for project in formatter.context.projects:
      let projectPassed = project.stats.passed
      let projectTotal = project.stats.total
      let projectRate = if projectTotal > 0: float(projectPassed) / float(projectTotal) * 100.0 else: 0.0
      
      var status = "✓"
      var statusColor = fgGreen
      if project.stats.failed > 0 or project.stats.errors > 0:
        status = "✗"
        statusColor = fgRed
      elif project.stats.skipped > 0:
        status = "~"
        statusColor = fgYellow
      
      if formatter.colored:
        styledEcho(fmt"  {status} ", statusColor, fmt"{project.name}", resetStyle, fmt" ({projectRate:.1f}% - {projectPassed}/{projectTotal})")
      else:
        echo fmt"  {status} {project.name} ({projectRate:.1f}% - {projectPassed}/{projectTotal})"
      
      if project.stats.duration > 0:
        echo fmt"    Duration: {project.stats.duration:.3f}s"
  
  if formatter.showCrossProjectStats:
    echo "\nCross-Project Analysis:"
    
    # Find slowest projects
    let sortedByDuration = formatter.context.projects.sortedByIt(-it.stats.duration)
    if sortedByDuration.len > 0:
      echo "  Slowest projects:"
      for i in 0..<min(3, sortedByDuration.len):
        let project = sortedByDuration[i]
        echo fmt"    {i+1}. {project.name}: {project.stats.duration:.3f}s"
    
    # Find projects with failures
    let failedProjects = formatter.context.projects.filterIt(it.stats.failed > 0 or it.stats.errors > 0)
    if failedProjects.len > 0:
      echo "  Projects with failures:"
      for project in failedProjects:
        echo fmt"    - {project.name}: {project.stats.failed} failures, {project.stats.errors} errors"
    
    # Dependency analysis
    if formatter.showDependencyMatrix:
      echo "  Dependency matrix:"
      var allDeps = initTable[string, int]()
      for project in formatter.context.projects:
        for dep in project.dependencies:
          allDeps[dep] = allDeps.getOrDefault(dep, 0) + 1
      
      for dep, count in allDeps:
        echo fmt"    {dep}: used by {count} project(s)"
  
  # Workspace health assessment
  let overallSuccessRate = if stats.total > 0: float(stats.passed) / float(stats.total) * 100.0 else: 0.0
  let healthyProjects = formatter.context.projects.countIt(it.stats.failed == 0 and it.stats.errors == 0)
  let workspaceHealth = float(healthyProjects) / float(formatter.context.totalProjects) * 100.0
  
  echo "\nWorkspace Health Assessment:"
  echo fmt"  Test Success Rate: {overallSuccessRate:.1f}%"
  echo fmt"  Healthy Projects: {healthyProjects}/{formatter.context.totalProjects} ({workspaceHealth:.1f}%)"
  
  if workspaceHealth >= 95.0:
    if formatter.colored:
      styledEcho(styleBright + fgGreen, "  Status: EXCELLENT")
    else:
      echo "  Status: EXCELLENT"
  elif workspaceHealth >= 80.0:
    if formatter.colored:
      styledEcho(styleBright + fgYellow, "  Status: GOOD")
    else:
      echo "  Status: GOOD"
  else:
    if formatter.colored:
      styledEcho(styleBright + fgRed, "  Status: NEEDS ATTENTION")
    else:
      echo "  Status: NEEDS ATTENTION"
  
  echo "=".repeat(70)

# Workspace context gathering
proc gatherWorkspaceContext*(rootPath = getCurrentDir()): WorkspaceContext =
  ## Gather workspace context by scanning for projects
  result = WorkspaceContext(
    rootPath: rootPath,
    projects: @[],
    totalProjects: 0,
    parallelExecution: false
  )
  
  # Look for workspace config
  let workspaceConfig = rootPath / "niuv.workspace.toml"
  if fileExists(workspaceConfig):
    result.configFile = workspaceConfig
    # TODO: Parse workspace config for project definitions
  
  # Scan for projects (directories with .nimble files)
  try:
    for kind, path in walkDir(rootPath):
      if kind == pcDir:
        let nimbleFiles = @[path / (path.extractFilename() & ".nimble")]
        for nimbleFile in nimbleFiles:
          if fileExists(nimbleFile):
            let projectName = path.extractFilename()
            let projectInfo = ProjectInfo(
              name: projectName,
              path: path,
              nimbleFile: nimbleFile,
              dependencies: @[], # TODO: Parse from nimble file
              testResults: @[],
              stats: EnhancedTestStatistics()
            )
            result.projects.add(projectInfo)
            result.totalProjects.inc
  except:
    discard # Handle directory access errors gracefully

proc addProjectResults*(formatter: WorkspaceReportFormatter, 
                       projectName: string, 
                       results: seq[TestResult],
                       stats: EnhancedTestStatistics) =
  ## Add test results for a specific project
  for i in 0..<formatter.context.projects.len:
    if formatter.context.projects[i].name == projectName:
      formatter.context.projects[i].testResults = results
      formatter.context.projects[i].stats = stats
      break

proc createWorkspaceTestSuite*(rootPath = getCurrentDir()): WorkspaceReportFormatter =
  ## Create a workspace test suite with auto-detected context
  let context = gatherWorkspaceContext(rootPath)
  result = newWorkspaceReportFormatter(context)

# Integration with niuv workspace functionality
proc generateWorkspaceSummaryReport*(formatter: WorkspaceReportFormatter, outputFile: string) =
  ## Generate a comprehensive workspace summary report
  var report = "# Niuv Workspace Test Summary\n\n"
  
  report.add(fmt"**Workspace:** {formatter.context.rootPath}\n")
  report.add(fmt"**Total Projects:** {formatter.context.totalProjects}\n")
  report.add(fmt"**Execution Mode:** {if formatter.context.parallelExecution: "Parallel" else: "Sequential"}\n\n")
  
  report.add("## Project Results\n\n")
  
  for project in formatter.context.projects:
    let successRate = if project.stats.total > 0: 
                        float(project.stats.passed) / float(project.stats.total) * 100.0 
                      else: 0.0
    
    report.add(fmt"### {project.name}\n")
    report.add(fmt"- **Path:** `{project.path}`\n")
    report.add(fmt"- **Tests:** {project.stats.total} (Passed: {project.stats.passed}, Failed: {project.stats.failed})\n")
    report.add(fmt"- **Success Rate:** {successRate:.1f}%\n")
    report.add(fmt"- **Duration:** {project.stats.duration:.3f}s\n")
    
    if project.dependencies.len > 0:
      report.add(fmt"- **Dependencies:** {project.dependencies.join(", ")}\n")
    
    report.add("\n")
  
  writeFile(outputFile, report)
