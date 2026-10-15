import std/unittest

## Test Environment Reporting Module

import std/[unittest, times, tables, sets, json, os, strutils]
import ../src/environment/reporting

suite "Environment Reporting Tests":
  test "EnvironmentContext creation":
    let context = EnvironmentContext(
      envPath: "/test/env",
      nimVersion: "2.2.0",
      configFile: "niuv.toml",
      dependencies: @["dep1", "dep2"],
      parallelJobs: 4,
      lockFile: "nimble.lock"
    )
    
    check context.envPath == "/test/env"
    check context.nimVersion == "2.2.0"
    check context.dependencies.len == 2
    check context.parallelJobs == 4
    
  test "NiuvTestCategory enum values":
    check ord(EnvironmentTest) == 0
    check ord(ConfigurationTest) == 1
    check ord(DependencyTest) == 2
    
  test "EnvironmentReportFormatter creation":
    let context = EnvironmentContext(
      envPath: "/test/env",
      nimVersion: "2.2.0",
      configFile: "niuv.toml",
      dependencies: @[],
      parallelJobs: 2,
      lockFile: ""
    )
    
    let formatter = newEnvironmentReportFormatter(context)
    check formatter.context.envPath == "/test/env"
    check formatter.showEnvironmentInfo == true
    check formatter.showDependencyInfo == true
    
  test "gatherEnvironmentContext":
    let context = gatherEnvironmentContext()
    check context.envPath.len > 0
    # Context should have some basic information even with defaults
    
  test "createEnvironmentTestSuite":
    let formatter = createEnvironmentTestSuite("niuv_test_suite")
    check formatter != nil
    check formatter.context.envPath.len > 0
    
  test "migrateFromLegacyReporting":
    let legacyResults = @[
      (name: "test1", status: "pass", message: ""),
      (name: "test2", status: "fail", message: "error occurred"),
      (name: "test3", status: "skip", message: "skipped test")
    ]
    
    let migrated = migrateFromLegacyReporting(legacyResults)
    check migrated.len == 3
    check migrated[0].status == tsPassed
    check migrated[1].status == tsFailed
    check migrated[2].status == tsSkipped
    check migrated[1].message == "error occurred"