import std/unittest

## Test Reporting Integration with nim-testkit

import std/[unittest, times, tables, sets, json, os, strutils]
import ../src/environment/reporting
import ../../nim-testkit/src/reporting

suite "Reporting Integration Tests":
  test "nim-testkit TestStatus compatibility":
    check ord(TestStatus.Pass) == 0
    check ord(TestStatus.Fail) == 1
    check ord(TestStatus.Skip) == 2
    check ord(TestStatus.Error) == 3
    
  test "nim-testkit TestResult creation":
    let result = TestResult(
      name: "test example",
      suiteName: "Test Suite",
      status: TestStatus.Pass,
      message: "",
      duration: 0.123,
      timestamp: now(),
      category: TestCategory.Unit
    )
    
    check result.name == "test example"
    check result.suiteName == "Test Suite"
    check result.status == TestStatus.Pass
    check result.duration == 0.123
    check result.category == TestCategory.Unit
    
  test "EnhancedTestStatistics creation":
    let stats = EnhancedTestStatistics(
      total: 10,
      passed: 7,
      failed: 2,
      skipped: 1,
      errors: 0,
      duration: 1.5,
      timestamp: now()
    )
    
    check stats.total == 10
    check stats.passed == 7
    check stats.failed == 2
    check stats.skipped == 1
    check stats.errors == 0
    check stats.duration == 1.5
    
  test "Enhanced formatters creation":
    let consoleFormatter = newEnhancedConsoleFormatter()
    check consoleFormatter.colored == true
    
    let jsonFormatter = newEnhancedJsonFormatter("test.json")
    check jsonFormatter != nil
    
    let htmlFormatter = newEnhancedHtmlFormatter("test.html", "Test Report")
    check htmlFormatter != nil
    
  test "Environment context integration":
    let context = gatherEnvironmentContext()
    let envFormatter = newEnvironmentReportFormatter(context)
    
    check envFormatter != nil
    check envFormatter.context.envPath.len > 0
    
  test "Legacy to nim-testkit migration":
    let legacyResults = @[
      (name: "test1", status: "pass", message: ""),
      (name: "test2", status: "fail", message: "error"),
      (name: "test3", status: "skip", message: "skipped")
    ]
    
    let migratedResults = migrateFromLegacyReporting(legacyResults)
    
    check migratedResults.len == 3
    check migratedResults[0].status == TestStatus.Pass
    check migratedResults[1].status == TestStatus.Fail
    check migratedResults[1].message == "error"
    check migratedResults[2].status == TestStatus.Skip
    
  test "MultiReportFormatter usage":
    let multiFormatter = newMultiReportFormatter(@[
      newEnhancedConsoleFormatter(),
      newEnhancedJsonFormatter(),
    ])
    
    check multiFormatter != nil
    
    # Test with sample data
    let stats = EnhancedTestStatistics(
      total: 1,
      passed: 1,
      failed: 0,
      skipped: 0,
      errors: 0,
      duration: 0.1,
      timestamp: now()
    )
    
    # Should not throw exceptions
    multiFormatter.beginTesting()
    multiFormatter.endTesting(stats)
    check true
    
  test "Category statistics tracking":
    var stats = EnhancedTestStatistics()
    
    # Simulate adding category statistics
    let unitStats = (total: 5, passed: 4, failed: 1, skipped: 0)
    let integrationStats = (total: 3, passed: 2, failed: 0, skipped: 1)
    
    stats.categoryStats[TestCategory.Unit] = unitStats
    stats.categoryStats[TestCategory.Integration] = integrationStats
    
    check stats.categoryStats[TestCategory.Unit].total == 5
    check stats.categoryStats[TestCategory.Unit].passed == 4
    check stats.categoryStats[TestCategory.Integration].total == 3
    check stats.categoryStats[TestCategory.Integration].skipped == 1
    
  test "Environment formatter methods":
    let context = EnvironmentContext(
      envPath: "/test/env",
      nimVersion: "2.2.0",
      configFile: "niuv.toml",
      dependencies: @["dep1", "dep2"],
      parallelJobs: 4,
      lockFile: "nimble.lock"
    )
    
    let formatter = newEnvironmentReportFormatter(context)
    
    # Test methods don't throw exceptions
    formatter.beginTesting()
    
    let stats = EnhancedTestStatistics(
      total: 2,
      passed: 2,
      failed: 0,
      skipped: 0,
      errors: 0,
      duration: 0.2,
      timestamp: now()
    )
    
    formatter.endTesting(stats)
    check true