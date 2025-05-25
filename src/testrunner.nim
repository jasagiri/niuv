import std/[os, osproc, strutils, strformat, algorithm]

type
  TestOptions* = object
    verbose*: bool
    pattern*: string
    failFast*: bool
    outputPath*: string
    runInParallel*: bool
    maxJobs*: int

proc findTestFiles*(pattern: string = "test_*.nim"): seq[string] =
  ## Find all test files matching the pattern in the tests directory
  echo &"Finding test files matching pattern: {pattern}"
  result = @[]
  let testPath = "tests" / pattern
  echo &"Searching in: {testPath}"
  
  for file in walkFiles(testPath):
    echo &"  Checking file: {file}"
    if file.endsWith(".nim") and not file.endsWith("test_all.nim") and not file.endsWith("testutils.nim"):
      echo &"    Adding to test list: {file}"
      result.add(file)

  # Sort alphabetically (more predictable)
  result.sort()
  echo &"Found {result.len} test files"

proc compileTest*(file: string, outputPath: string = "build/tests"): string =
  ## Compile a test file and return the path to the compiled binary
  let
    (_, name, _) = splitFile(file)
    outputDir = outputPath
    outputFile = outputDir / name
  
  # Create output directory if it doesn't exist
  createDir(outputDir)
  createDir("build/nimcache")
  
  # Compile the test
  let cmd = &"nim c -o:{outputFile} --nimblePath:nimbledeps/pkgs --nimcache:build/nimcache {file}"
  let (output, exitCode) = execCmdEx(cmd)
  
  if exitCode != 0:
    echo &"Failed to compile {file}: {output}"
    return ""
  
  return outputFile

proc runTest*(testBinary: string, verbose: bool = false): (bool, string) =
  ## Run a test binary and return if it passed and the output
  let (output, exitCode) = execCmdEx(testBinary)
  return (exitCode == 0, output)

proc runAllTests*(options: TestOptions): bool =
  ## Run all tests matching the pattern
  let testFiles = findTestFiles(options.pattern)
  
  if testFiles.len == 0:
    echo "No test files found matching pattern: ", options.pattern
    return false
  
  echo &"Found {testFiles.len} test files to run"
  
  var
    compiledTests: seq[string] = @[]
    passedTests: seq[string] = @[]
    failedTests: seq[string] = @[]
  
  # Compile all tests
  for file in testFiles:
    echo &"Compiling {file}..."
    let testBinary = compileTest(file, options.outputPath)
    if testBinary != "":
      compiledTests.add(testBinary)
    else:
      failedTests.add(file)
      if options.failFast:
        echo "Compilation failed, stopping due to --fail-fast"
        return false
  
  echo &"Compiled {compiledTests.len} test binaries"
  
  # Run all tests
  for testBinary in compiledTests:
    let (_, name, _) = splitFile(testBinary)
    echo &"Running {name}..."
    let (passed, output) = runTest(testBinary, options.verbose)
    
    if options.verbose:
      echo output
    
    if passed:
      passedTests.add(name)
      echo &"  ✓ {name} passed"
    else:
      failedTests.add(name)
      echo &"  ✗ {name} failed"
      if options.failFast:
        echo "Test failed, stopping due to --fail-fast"
        echo "Failed tests: ", failedTests.join(", ")
        return false
  
  let success = failedTests.len == 0
  echo "============================================================"
  echo &"Tests: {passedTests.len} passed, {failedTests.len} failed"
  
  if not success:
    echo "Failed tests: ", failedTests.join(", ")
  
  return success

when isMainModule:
  import parseopt
  
  echo "TestRunner starting..."
  
  var options = TestOptions(
    verbose: false,
    pattern: "test_*.nim",
    failFast: false,
    outputPath: "build/tests",
    runInParallel: false,
    maxJobs: 0
  )
  
  echo "Parsing command line options..."
  var p = initOptParser()
  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      options.pattern = key
    of cmdLongOption, cmdShortOption:
      case key
      of "verbose", "v": options.verbose = true
      of "fail-fast", "f": options.failFast = true
      of "output", "o": options.outputPath = val
      of "parallel", "p": options.runInParallel = true
      of "jobs", "j": options.maxJobs = parseInt(val)
    of cmdEnd: discard
  
  echo "Running tests with options:"
  echo "  Pattern: ", options.pattern
  echo "  Verbose: ", options.verbose
  echo "  Output path: ", options.outputPath
  
  let success = runAllTests(options)
  quit(if success: 0 else: 1)