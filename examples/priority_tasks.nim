import std/[os, strutils, tables, sequtils, times]
import ../src/parallel

## This example demonstrates how to use task prioritization in parallel execution
## to ensure high-priority tasks are executed before lower-priority ones.

proc main() =
  echo "Task Prioritization Example"
  echo "==========================="
  
  # Enable verbose logging
  putEnv("NIUV_VERBOSE", "1")
  
  # Create temp directory for demonstration
  let tempDir = getTempDir() / "niuv_priority_example_" & $epochTime()
  createDir(tempDir)
  echo "Created temporary directory: ", tempDir
  
  try:
    # Example 1: Tasks with different priorities
    echo "\nExample 1: Tasks with different priorities"
    echo "----------------------------------------"
    
    # Create tasks with different priorities
    var tasks: seq[ParallelTask] = @[
      ParallelTask(
        id: "task-low-1",
        command: "echo \"Low priority task 1\"",
        workingDir: tempDir,
        env: initTable[string, string](),
        priority: Low
      ),
      ParallelTask(
        id: "task-high-1",
        command: "echo \"High priority task 1\"",
        workingDir: tempDir,
        env: initTable[string, string](),
        priority: High
      ),
      ParallelTask(
        id: "task-normal-1",
        command: "echo \"Normal priority task 1\"",
        workingDir: tempDir,
        env: initTable[string, string](),
        priority: Normal
      ),
      ParallelTask(
        id: "task-high-2",
        command: "echo \"High priority task 2\"",
        workingDir: tempDir,
        env: initTable[string, string](),
        priority: High
      ),
      ParallelTask(
        id: "task-low-2",
        command: "echo \"Low priority task 2\"",
        workingDir: tempDir,
        env: initTable[string, string](),
        priority: Low
      )
    ]
    
    # Create commands array with priority hints (used by runParallel)
    let commands = @[
      "priority=low echo \"Another low priority task\"",
      "priority=high echo \"Another high priority task\"",
      "echo \"Default priority task\"",
      "priority=high echo \"One more high priority task\"",
      "priority=low echo \"One more low priority task\""
    ]
    
    # Run tasks with sorting by priority
    # Note: High priority tasks will be executed first due to priority sorting
    let results = runParallelCommands(tasks, commands, numJobs = 2)
    
    echo "\nTask Execution Order (as determined by priority):"
    for i, result in results:
      echo "  ", i+1, ": [", result.priority, "] ", result.id, " -> ", result.output.strip()
    
    # Example 2: Mixing long-running and high-priority tasks
    echo "\nExample 2: Long-running tasks with different priorities"
    echo "---------------------------------------------------"
    
    # Create a mix of long-running and quick tasks with different priorities
    let commands2 = @[
      "sleep 3 && echo \"Low priority long task\"", # Low priority, long-running
      "priority=high echo \"High priority quick task 1\"", # High priority, quick
      "sleep 2 && echo \"Normal priority medium task\"", # Normal priority, medium
      "priority=high echo \"High priority quick task 2\"", # High priority, quick
      "priority=low sleep 1 && echo \"Low priority short task\"" # Low priority, shorter
    ]
    
    # Run tasks with 3 workers
    let results2 = runParallelCommands(@[], commands2, numJobs = 3)
    
    echo "\nTask Results (notice high priority tasks finish earlier):"
    for i, result in results2:
      echo "  ", i+1, ": [", result.priority, "] completed in ", 
           formatFloat(result.elapsedTime, ffDecimal, 3), "s: ", 
           result.output.strip()
  
  finally:
    # Clean up
    if dirExists(tempDir):
      removeDir(tempDir)
      echo "\nCleaned up temporary directory"

when isMainModule:
  main()