## Test file for the migrated test report generator in src/tools/report/test_report.nim

import unittest
import std/os
import std/strutils
import std/json
import std/sequtils  # Add missing sequtils for filterIt

# Import the module to test and rename the TestResult type to avoid ambiguity
from ../src/tools/report/test_report as tr import nil

suite "Test Report Generator Tests":
  setup:
    # Create a temporary test directory
    let testDir = getTempDir() / "niuv_test_report_" & $getCurrentProcessId()
    createDir(testDir)
    
    # Create a sample test output
    let sampleOutput = """
[Suite] ConfigTests
[OK] Test config loading (0.0015s) [/path/to/test_config.nim:42]
[FAILED] Test config validation (0.0025s) [/path/to/test_config.nim:56]
[SKIPPED] Test optional config (0.0002s) [/path/to/test_config.nim:70]

[Suite] UtilsTests
[OK] Test file utilities (0.0035s) [/path/to/test_utils.nim:25]
[OK] Test string utilities (0.0012s) [/path/to/test_utils.nim:40]
"""
    
    let testOutputFile = testDir / "test_output.txt"
    writeFile(testOutputFile, sampleOutput)
  
  teardown:
    # Clean up after tests
    if dirExists(testDir):
      removeDir(testDir)
  
  test "parseTestOutput - correctly parses test results":
    # Read sample test output
    let testOutput = readFile(testDir / "test_output.txt")
    
    # Parse test output
    let report = tr.parseTestOutput(testOutput)
    
    # Check parsed results
    check report.passed == 3
    check report.failed == 1
    check report.skipped == 1
    check report.total == 5
    
    # Check individual test cases
    check report.cases.len == 5
    
    # First test case should be the config loading test
    let firstTest = report.cases[0]
    check firstTest.name == "Test config loading"
    check firstTest.result == tr.tPass
    check firstTest.suite == "ConfigTests"
    check firstTest.file == "/path/to/test_config.nim"
    check firstTest.line == 42
    check abs(firstTest.duration - 0.0015) < 0.00001
    
    # Check a failed test
    let failedTest = report.cases.filterIt(it.result == tr.tFail)[0]
    check failedTest.name == "Test config validation"
    check failedTest.suite == "ConfigTests"
    
    # Check a skipped test
    let skippedTest = report.cases.filterIt(it.result == tr.tSkip)[0]
    check skippedTest.name == "Test optional config"
    check skippedTest.suite == "ConfigTests"
  
  test "generateHtmlReport - creates valid HTML report":
    # Set up test
    let htmlOutputPath = testDir / "report.html"
    
    # Parse test output
    let htmlReport = tr.parseTestOutput(readFile(testOutputFile))
    
    # Generate HTML report
    let htmlSuccess = tr.generateHtmlReport(htmlReport, htmlOutputPath)
    check htmlSuccess == true
    check fileExists(htmlOutputPath) == true
    
    # Check content of HTML report
    let htmlContent = readFile(htmlOutputPath)
    check htmlContent.contains("Test Report") == true
    check htmlContent.contains("Passed: 3") == true
    check htmlContent.contains("Failed: 1") == true
    check htmlContent.contains("Skipped: 1") == true
    check htmlContent.contains("Total: 5") == true
    check htmlContent.contains("Test config loading") == true
    check htmlContent.contains("Test config validation") == true
    check htmlContent.contains("ConfigTests") == true
    check htmlContent.contains("UtilsTests") == true
  
  test "generateJsonReport - creates valid JSON report":
    # Set up test
    let jsonOutputPath = testDir / "report.json"
    
    # Parse test output
    let jsonReport = tr.parseTestOutput(readFile(testOutputFile))
    
    # Generate JSON report
    let jsonSuccess = tr.generateJsonReport(jsonReport, jsonOutputPath)
    check jsonSuccess == true
    check fileExists(jsonOutputPath) == true
    
    # Parse and check the JSON report
    let jsonContent = parseJson(readFile(jsonOutputPath))
    check jsonContent.hasKey("summary") == true
    check jsonContent["summary"]["passed"].getInt() == 3
    check jsonContent["summary"]["failed"].getInt() == 1
    check jsonContent["summary"]["skipped"].getInt() == 1
    check jsonContent["summary"]["total"].getInt() == 5
    
    check jsonContent.hasKey("tests") == true
    check jsonContent["tests"].len == 5
    
    # Check first test details
    let firstTest = jsonContent["tests"][0]
    check firstTest.hasKey("name") == true
    check firstTest["name"].getStr() == "Test config loading"
    check firstTest["result"].getStr() == "pass"
    check firstTest["suite"].getStr() == "ConfigTests"
  
  test "generateReport - complete workflow test":
    # Set up tests
    let fullJsonPath = testDir / "full_report.json"
    let fullHtmlPath = testDir / "full_report.html"
    
    # Execute the complete report generation
    let fullSuccess = tr.generateReport(testOutputFile, fullJsonPath, fullHtmlPath)
    check fullSuccess == true
    check fileExists(fullJsonPath) == true
    check fileExists(fullHtmlPath) == true
    
when isMainModule:
  discard