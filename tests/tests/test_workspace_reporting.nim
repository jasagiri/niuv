import std/unittest

## Test Workspace Reporting Module

import std/[unittest, times, tables, sets, json, os, strutils]
import ../src/workspace/reporting

suite "Workspace Reporting Tests":
  test "ProjectInfo creation":
    let projectInfo = ProjectInfo(
      name: "test-project",
      path: "/path/to/project",
      nimbleFile: "test-project.nimble",
      dependencies: @["nim-std", "parsetoml"],
      testResults: @[],
      stats: EnhancedTestStatistics()
    )
    
    check projectInfo.name == "test-project"
    check projectInfo.path == "/path/to/project"
    check projectInfo.dependencies.len == 2
    
  test "WorkspaceContext creation":
    let context = WorkspaceContext(
      rootPath: "/workspace",
      configFile: "niuv.workspace.toml",
      projects: @[],
      totalProjects: 0,
      parallelExecution: true
    )
    
    check context.rootPath == "/workspace"
    check context.parallelExecution == true
    check context.totalProjects == 0
    
  test "WorkspaceReportFormatter creation":
    let context = WorkspaceContext(
      rootPath: getCurrentDir(),
      configFile: "",
      projects: @[],
      totalProjects: 2,
      parallelExecution: false
    )
    
    let formatter = newWorkspaceReportFormatter(context)
    check formatter.context.totalProjects == 2
    check formatter.showProjectBreakdown == true
    check formatter.aggregateResults == true
    
  test "gatherWorkspaceContext":
    let context = gatherWorkspaceContext()
    check context.rootPath.len > 0
    # Should detect at least this project
    
  test "createWorkspaceTestSuite":
    let formatter = createWorkspaceTestSuite()
    check formatter != nil
    check formatter.context.rootPath.len > 0
    
  test "addProjectResults":
    var context = WorkspaceContext(
      rootPath: getCurrentDir(),
      configFile: "",
      projects: @[
        ProjectInfo(name: "proj1", path: "", nimbleFile: "", dependencies: @[], testResults: @[], stats: EnhancedTestStatistics()),
        ProjectInfo(name: "proj2", path: "", nimbleFile: "", dependencies: @[], testResults: @[], stats: EnhancedTestStatistics())
      ],
      totalProjects: 2,
      parallelExecution: false
    )
    
    var formatter = newWorkspaceReportFormatter(context)
    formatter.context = context
    
    let testResults = @[
      TestResult(
        name: "test1",
        suiteName: "suite1", 
        status: TestStatus.Pass,
        message: "",
        duration: 0.1,
        timestamp: now(),
        category: TestCategory.Unit
      )
    ]
    
    let stats = EnhancedTestStatistics(
      total: 1,
      passed: 1,
      failed: 0,
      skipped: 0,
      errors: 0,
      duration: 0.1,
      timestamp: now()
    )
    
    formatter.addProjectResults("proj1", testResults, stats)
    check formatter.context.projects[0].testResults.len == 1
    check formatter.context.projects[0].stats.passed == 1