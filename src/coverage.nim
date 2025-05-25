## Coverage Module for Niuv
## 
## Provides code coverage functionality following MECE principles.
## Integrates with nim-lang-core patterns for consistency.

import std/[os, strutils, sequtils, tables, json, times, osproc, strformat]
import ./config
import ./utils

type
  CoverageKind* = enum
    ckLine = "line"
    ckBranch = "branch"
    ckFunction = "function"
    
  CoverageFormat* = enum
    cfLcov = "lcov"
    cfHtml = "html"
    cfJson = "json"
    cfText = "text"
    
  CoverageData* = object
    file*: string
    totalLines*: int
    coveredLines*: int
    totalBranches*: int
    coveredBranches*: int
    totalFunctions*: int
    coveredFunctions*: int
    lineHits*: Table[int, int]  # line number -> hit count
    
  CoverageReport* = object
    timestamp*: DateTime
    projectRoot*: string
    files*: seq[CoverageData]
    totalCoverage*: float
    lineCoverage*: float
    branchCoverage*: float
    functionCoverage*: float

  CoverageConfig* = object
    enabled*: bool
    formats*: seq[CoverageFormat]
    outputDir*: string
    threshold*: float
    includePatterns*: seq[string]
    excludePatterns*: seq[string]
    sourcemap*: bool
    
  CoverageError* = object of CatchableError

# Forward declarations
proc collectCoverageData*(config: CoverageConfig, testFiles: seq[string]): CoverageReport
proc generateReport*(report: CoverageReport, format: CoverageFormat, outputPath: string)

proc loadCoverageConfig*(projectConfig: Config): CoverageConfig =
  ## Load coverage configuration from project config
  result = CoverageConfig(
    enabled: projectConfig.getConfigValue("coverage.enabled", "true") == "true",
    formats: @[cfHtml, cfJson],
    outputDir: projectConfig.getConfigValue("coverage.outputDir", "coverage"),
    threshold: parseFloat(projectConfig.getConfigValue("coverage.threshold", "80.0")),
    includePatterns: @["src/**/*.nim", "tests/**/*.nim"],
    excludePatterns: @["**/vendor/**", "**/nimcache/**"],
    sourcemap: true
  )
  
  # Parse formats from config
  let formatsStr = projectConfig.getConfigValue("coverage.formats", "html,json")
  result.formats = @[]
  for format in formatsStr.split(","):
    case format.strip().toLowerAscii()
    of "lcov": result.formats.add(cfLcov)
    of "html": result.formats.add(cfHtml)
    of "json": result.formats.add(cfJson)
    of "text": result.formats.add(cfText)
    else: discard

proc compileCoverageEnabled*(file: string, config: CoverageConfig): (string, int) =
  ## Compile a Nim file with coverage instrumentation
  let outFile = file.changeFileExt("")
  var cmd = fmt"nim c"
  
  if config.sourcemap:
    cmd &= " --sourcemap --lineDir:on"
    
  # Add coverage flags for GCC/Clang
  cmd &= " --debugger:native"
  cmd &= " --passC:\"-fprofile-arcs -ftest-coverage\""
  cmd &= " --passL:\"-fprofile-arcs -ftest-coverage\""
  
  # Output to specific directory
  let coverageBuildDir = config.outputDir / "build"
  createDir(coverageBuildDir)
  cmd &= fmt" -o:{coverageBuildDir}/{outFile.extractFilename()}"
  
  cmd &= fmt" {file}"
  
  logDebug(fmt"Compiling with coverage: {cmd}")
  result = execCmdEx(cmd)

proc runWithCoverage*(executable: string, config: CoverageConfig): (string, int) =
  ## Run an executable and collect coverage data
  let workDir = executable.parentDir()
  let exeName = executable.extractFilename()
  
  # Set environment for coverage output
  putEnv("GCOV_PREFIX", config.outputDir / "raw")
  putEnv("GCOV_PREFIX_STRIP", "99")  # Strip all path components
  
  logDebug(fmt"Running with coverage: {executable}")
  result = execCmdEx(fmt"./{exeName}", workingDir = workDir)

proc parseGcovOutput*(gcovFile: string): CoverageData =
  ## Parse a .gcov file to extract coverage data
  result = CoverageData(
    file: "",
    lineHits: initTable[int, int]()
  )
  
  let content = readFile(gcovFile)
  
  for line in content.splitLines():
    if line.contains(":Source:"):
      let parts = line.split(":Source:")
      if parts.len >= 2:
        result.file = parts[1].strip()
    elif line.contains(":") and result.file.len > 0:
      # Parse coverage line: "count:linenum:content"
      let firstColonIdx = line.find(":")
      if firstColonIdx >= 0:
        let count = line[0..<firstColonIdx].strip()
        let remaining = line[firstColonIdx+1..^1]
        let secondColonIdx = remaining.find(":")
        
        if secondColonIdx >= 0:
          let lineNumStr = remaining[0..<secondColonIdx].strip()
          
          if lineNumStr.len > 0 and lineNumStr[0].isDigit():
            let lineNum = parseInt(lineNumStr)
            
            if count == "-":
              # Non-executable line, skip
              continue
            elif count == "#####":
              # Not executed
              result.lineHits[lineNum] = 0
              result.totalLines += 1
            else:
              # Executed, parse count
              try:
                let hitCount = parseInt(count.replace("*", ""))
                result.lineHits[lineNum] = hitCount
                result.totalLines += 1
                result.coveredLines += 1
              except ValueError:
                discard

proc collectCoverageData*(config: CoverageConfig, testFiles: seq[string]): CoverageReport =
  ## Collect coverage data from test runs
  result = CoverageReport(
    timestamp: now(),
    projectRoot: getCurrentDir(),
    files: @[]
  )
  
  # Ensure output directories exist
  createDir(config.outputDir)
  createDir(config.outputDir / "raw")
  createDir(config.outputDir / "build")
  
  # Clean old coverage data
  for gcda in walkFiles(config.outputDir / "raw" / "*.gcda"):
    removeFile(gcda)
  for gcno in walkFiles(config.outputDir / "raw" / "*.gcno"):
    removeFile(gcno)
    
  echo "[INFO] Running tests with coverage..."
  
  var allSourceFiles = initTable[string, bool]()
  
  # Compile and run each test
  for testFile in testFiles:
    echo fmt"  Running {testFile.extractFilename()}"
    
    # Compile with coverage
    let (compileOut, compileCode) = compileCoverageEnabled(testFile, config)
    if compileCode != 0:
      logError(fmt"Failed to compile {testFile}: {compileOut}")
      continue
      
    # Run test
    let executable = config.outputDir / "build" / testFile.extractFilename().changeFileExt("")
    let (runOut, runCode) = runWithCoverage(executable, config)
    if runCode != 0:
      logWarning(fmt"Test {testFile} failed: {runOut}")
      
  # Process coverage data with gcov
  echo "\nProcessing coverage data..."
  
  # Find all .gcno files (compile-time coverage info)
  for gcnoFile in walkFiles(getCurrentDir() / "nimcache" / "*.gcno"):
    let baseName = gcnoFile.extractFilename().changeFileExt("")
    let gcdaFile = gcnoFile.changeFileExt("gcda")
    
    if fileExists(gcdaFile):
      # Run gcov
      let gcovCmd = fmt"gcov -b {gcnoFile}"
      let (gcovOut, gcovCode) = execCmdEx(gcovCmd, workingDir = gcnoFile.parentDir())
      
      if gcovCode == 0:
        # Find generated .gcov files
        for gcovFile in walkFiles(gcnoFile.parentDir() / "*.gcov"):
          if gcovFile.endsWith(".nim.gcov"):
            let data = parseGcovOutput(gcovFile)
            if data.file.len > 0 and data.totalLines > 0:
              # Only include project files
              if data.file.startsWith(result.projectRoot):
                let relPath = data.file[result.projectRoot.len..^1].strip(chars={'/'})
                # Skip system files, nimcache, and dependencies
                if relPath.startsWith("src/") or relPath.startsWith("tests/"):
                  result.files.add(data)
                  allSourceFiles[data.file] = true
  
  # Calculate overall coverage
  var totalLines = 0
  var coveredLines = 0
  
  for file in result.files:
    totalLines += file.totalLines
    coveredLines += file.coveredLines
    
  if totalLines > 0:
    result.totalCoverage = (coveredLines.float / totalLines.float) * 100.0
    result.lineCoverage = result.totalCoverage  # For now, same as total
  else:
    result.totalCoverage = 0.0
    result.lineCoverage = 0.0

proc generateLcovReport*(report: CoverageReport, outputPath: string) =
  ## Generate coverage report in LCOV format
  var content = ""
  
  for file in report.files:
    content &= fmt"SF:{file.file}" & "\n"
    
    # Add line coverage data
    for lineNum, hits in file.lineHits:
      content &= fmt"DA:{lineNum},{hits}" & "\n"
      
    content &= fmt"LF:{file.totalLines}" & "\n"
    content &= fmt"LH:{file.coveredLines}" & "\n"
    content &= "end_of_record\n"
    
  writeFile(outputPath, content)
  logInfo(fmt"LCOV report written to: {outputPath}")

proc generateHtmlReport*(report: CoverageReport, outputPath: string) =
  ## Generate coverage report in HTML format
  var html = """
<!DOCTYPE html>
<html>
<head>
  <title>Niuv Coverage Report</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }}
    .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
    h1 {{ color: #333; margin-bottom: 10px; }}
    .timestamp {{ color: #666; font-size: 14px; margin-bottom: 30px; }}
    .summary {{ background: #f8f9fa; padding: 20px; border-radius: 6px; margin-bottom: 30px; }}
    .metric {{ display: inline-block; margin-right: 30px; }}
    .metric-value {{ font-size: 36px; font-weight: bold; color: #333; }}
    .metric-label {{ font-size: 14px; color: #666; }}
    .good {{ color: #28a745; }}
    .warning {{ color: #ffc107; }}
    .bad {{ color: #dc3545; }}
    table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
    th {{ background: #f8f9fa; padding: 12px; text-align: left; font-weight: 600; border-bottom: 2px solid #dee2e6; }}
    td {{ padding: 12px; border-bottom: 1px solid #dee2e6; }}
    tr:hover {{ background: #f8f9fa; }}
    .coverage-bar {{ background: #e9ecef; height: 8px; border-radius: 4px; overflow: hidden; }}
    .coverage-fill {{ height: 100%; background: #28a745; transition: width 0.3s; }}
    .file-path {{ font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace; font-size: 13px; }}
  </style>
</head>
<body>
  <div class="container">
    <h1>Coverage Report</h1>
    <div class="timestamp">Generated: """ & $report.timestamp & """</div>
    
    <div class="summary">
      <div class="metric">
        <div class="metric-value """ & (if report.totalCoverage >= 80: "class=\"good\"" elif report.totalCoverage >= 60: "class=\"warning\"" else: "class=\"bad\"") & """>""" & fmt"{report.totalCoverage:.1f}%" & """</div>
        <div class="metric-label">Total Coverage</div>
      </div>
      <div class="metric">
        <div class="metric-value">""" & $report.files.len & """</div>
        <div class="metric-label">Files</div>
      </div>
    </div>
    
    <h2>File Coverage</h2>
    <table>
      <thead>
        <tr>
          <th>File</th>
          <th style="width: 120px;">Coverage</th>
          <th style="width: 150px;">Lines</th>
          <th style="width: 200px;">Progress</th>
        </tr>
      </thead>
      <tbody>
"""
  
  for file in report.files:
    let coverage = if file.totalLines > 0:
      (file.coveredLines.float / file.totalLines.float) * 100.0
    else:
      0.0
      
    let relativePath = file.file.replace(report.projectRoot & "/", "")
    let coverageClass = if coverage >= 80: "good" elif coverage >= 60: "warning" else: "bad"
    
    html &= """
        <tr>
          <td class="file-path">""" & relativePath & """</td>
          <td class="""" & coverageClass & """">""" & fmt"{coverage:.1f}%" & """</td>
          <td>""" & $file.coveredLines & "/" & $file.totalLines & """</td>
          <td>
            <div class="coverage-bar">
              <div class="coverage-fill" style="width: """ & fmt"{coverage:.0f}" & """%;"></div>
            </div>
          </td>
        </tr>
"""
  
  html &= """
      </tbody>
    </table>
  </div>
</body>
</html>
"""
  
  writeFile(outputPath, html)
  logInfo(fmt"HTML report written to: {outputPath}")

proc generateJsonReport*(report: CoverageReport, outputPath: string) =
  ## Generate coverage report in JSON format
  let jsonData = %*{
    "timestamp": $report.timestamp,
    "projectRoot": report.projectRoot,
    "summary": {
      "totalCoverage": report.totalCoverage,
      "lineCoverage": report.lineCoverage,
      "branchCoverage": report.branchCoverage,
      "functionCoverage": report.functionCoverage,
      "filesAnalyzed": report.files.len
    },
    "files": report.files.mapIt(%*{
      "path": it.file,
      "lineCoverage": if it.totalLines > 0: (it.coveredLines.float / it.totalLines.float) * 100.0 else: 0.0,
      "lines": {
        "covered": it.coveredLines,
        "total": it.totalLines
      },
      "branches": {
        "covered": it.coveredBranches,
        "total": it.totalBranches
      },
      "functions": {
        "covered": it.coveredFunctions,
        "total": it.totalFunctions
      }
    })
  }
  
  writeFile(outputPath, jsonData.pretty())
  logInfo(fmt"JSON report written to: {outputPath}")

proc generateTextReport*(report: CoverageReport, outputPath: string) =
  ## Generate coverage report in plain text format
  var content = "Niuv Coverage Report\n"
  content &= "===================\n\n"
  content &= fmt"Generated: {report.timestamp}" & "\n"
  content &= fmt"Project: {report.projectRoot}" & "\n\n"
  
  content &= "Summary\n"
  content &= "-------\n"
  content &= fmt"Total Coverage: {report.totalCoverage:.1f}%" & "\n"
  content &= fmt"Files Analyzed: {report.files.len}" & "\n\n"
  
  content &= "File Coverage\n"
  content &= "-------------\n"
  
  for file in report.files:
    let coverage = if file.totalLines > 0:
      (file.coveredLines.float / file.totalLines.float) * 100.0
    else:
      0.0
    let relativePath = file.file.replace(report.projectRoot & "/", "")
    content &= fmt"{relativePath:<50} {coverage:>6.1f}% ({file.coveredLines}/{file.totalLines})" & "\n"
    
  writeFile(outputPath, content)
  logInfo(fmt"Text report written to: {outputPath}")

proc generateReport*(report: CoverageReport, format: CoverageFormat, outputPath: string) =
  ## Generate coverage report in the specified format
  case format
  of cfLcov:
    generateLcovReport(report, outputPath)
  of cfHtml:
    generateHtmlReport(report, outputPath)
  of cfJson:
    generateJsonReport(report, outputPath)
  of cfText:
    generateTextReport(report, outputPath)

proc checkCoverageThreshold*(report: CoverageReport, threshold: float): bool =
  ## Check if coverage meets the threshold
  result = report.totalCoverage >= threshold
  
  if result:
    logInfo(fmt"✓ Coverage {report.totalCoverage:.1f}% meets threshold {threshold:.1f}%")
  else:
    logError(fmt"✗ Coverage {report.totalCoverage:.1f}% is below threshold {threshold:.1f}%")

proc runCoverage*(config: Config, testFiles: seq[string] = @[]): int =
  ## Main entry point for coverage functionality
  let coverageConfig = loadCoverageConfig(config)
  
  if not coverageConfig.enabled:
    logInfo("Coverage is disabled in configuration")
    return 0
    
  # Determine test files to run
  var files = testFiles
  if files.len == 0:
    # Find all test files
    for pattern in @["tests/test_*.nim", "tests/**/test_*.nim"]:
      for file in walkFiles(pattern):
        files.add(file)
        
  if files.len == 0:
    logError("No test files found")
    return 1
    
  # Collect coverage data
  let report = collectCoverageData(coverageConfig, files)
  
  # Generate reports in all requested formats
  for format in coverageConfig.formats:
    let filename = case format
      of cfLcov: "coverage.info"
      of cfHtml: "index.html"
      of cfJson: "coverage.json"
      of cfText: "coverage.txt"
      
    let outputPath = coverageConfig.outputDir / filename
    generateReport(report, format, outputPath)
    
  # Check threshold
  if not checkCoverageThreshold(report, coverageConfig.threshold):
    return 1
    
  return 0

# Export main functionality
proc coverage*(args: seq[string]): int =
  ## Coverage command handler
  let config = loadConfig()
  
  var testFiles: seq[string] = @[]
  for arg in args:
    if arg.endsWith(".nim"):
      testFiles.add(arg)
      
  result = runCoverage(config, testFiles)