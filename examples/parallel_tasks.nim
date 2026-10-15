import std/[os, strutils, tables, sequtils, times]
import ../src/parallel

## This example demonstrates how to use the parallel execution functionality
## to run multiple tasks concurrently with robust error handling, resource cleanup,
## and detailed logging.

proc main() =
  echo "Parallel Task Execution Example"
  echo "==============================="
  
  # Enable verbose logging
  putEnv("NIUV_VERBOSE", "1")
  
  # Create temp directory for demonstration
  let tempDir = getTempDir() / "niuv_example_" & $epochTime()
  createDir(tempDir)
  echo "Created temporary directory: ", tempDir
  
  # Create a subdirectory for demonstrating working directory changes
  let subDir = tempDir / "subdir"
  createDir(subDir)
  
  try:
    # Example 1: Basic parallel execution
    echo "\nExample 1: Basic parallel execution"
    echo "-----------------------------"
    
    let commands1 = @[
      "echo \"Task 1 output\"",
      "echo \"Task 2 output\"",
      "echo \"Task 3 output\""
    ]
    
    let results1 = runParallelCommands(@[], commands1)
    
    echo "\nResults summary:"
    for i, result in results1:
      echo "  Task ", i+1, ": Exit code ", result.exitCode, 
           ", Time: ", result.elapsedTime, "s"
      echo "    Output: ", result.output.strip()
    
    # Example 2: Parallel execution with different working directories
    echo "\nExample 2: Different working directories"
    echo "------------------------------------"
    
    var tasks2: seq[ParallelTask] = @[
      ParallelTask(
        id: "main-dir",
        command: "pwd",
        workingDir: tempDir,
        env: initTable[string, string]()
      ),
      ParallelTask(
        id: "sub-dir",
        command: "pwd",
        workingDir: subDir,
        env: initTable[string, string]()
      )
    ]
    
    let results2 = runParallelCommands(@[], @["pwd", "pwd"])
    
    echo "\nResults summary:"
    for i, result in results2:
      echo "  Task ", i+1, ": Exit code ", result.exitCode, 
           ", Directory: ", result.workingDir
    
    # Example 3: Handling task failures
    echo "\nExample 3: Handling task failures"
    echo "------------------------------"
    
    let commands3 = @[
      "echo \"Success task\"",
      "bash -c \"exit 1\"",       # This will fail with exit code 1
      "non_existent_command"      # This will fail with command not found
    ]
    
    let results3 = runParallelCommands(@[], commands3)
    
    echo "\nResults summary:"
    echo "  Successful tasks: ", results3.countIt(it.exitCode == 0), "/", results3.len
    echo "  Failed tasks: ", results3.countIt(it.exitCode != 0), "/", results3.len
    
    echo "\nFailure details:"
    for i, result in results3:
      if result.exitCode != 0:
        echo "  Task ", i+1, " (", result.command, "): Exit code ", result.exitCode
    
    # Example 4: Using environment variables
    echo "\nExample 4: Using environment variables"
    echo "----------------------------------"
    
    var tasks4: seq[ParallelTask] = @[
      ParallelTask(
        id: "env-test-1",
        command: "echo $EXAMPLE_VAR",
        workingDir: tempDir,
        env: {"EXAMPLE_VAR": "Hello from task 1"}.toTable
      ),
      ParallelTask(
        id: "env-test-2",
        command: "echo $EXAMPLE_VAR",
        workingDir: tempDir,
        env: {"EXAMPLE_VAR": "Hello from task 2"}.toTable
      )
    ]
    
    var commands4 = @["echo $EXAMPLE_VAR", "echo $EXAMPLE_VAR"]
    putEnv("EXAMPLE_VAR", "Default value")
    
    let results4 = runParallelCommands(tasks4, commands4)
    
    echo "\nResults summary:"
    for i, result in results4:
      echo "  Task ", i+1, ": Output: ", result.output.strip()
    
    # Example 5: Stress test with many parallel tasks
    echo "\nExample 5: Stress test with many parallel tasks"
    echo "------------------------------------------"
    
    var commands5 = newSeq[string]()
    for i in 1..20:
      commands5.add("sleep 0." & $i & " && echo \"Task " & $i & " complete\"")
    
    # Set number of parallel jobs explicitly 
    let results5 = runParallelCommands(@[], commands5, numJobs = 4)
    
    echo "\nResults summary:"
    echo "  Total tasks: ", results5.len
    echo "  Execution times (seconds):"
    
    var times = results5.mapIt(it.elapsedTime)
    echo "    Min: ", times.foldl(if a < b: a else: b, times[0])
    echo "    Max: ", times.foldl(if a > b: a else: b, times[0])
    echo "    Avg: ", times.foldl(a + b, 0.0) / float(times.len)
  
  finally:
    # Clean up
    if dirExists(tempDir):
      removeDir(tempDir)
      echo "\nCleaned up temporary directory"

when isMainModule:
  main()