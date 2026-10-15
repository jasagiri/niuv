import ../src/parallel
import std/[os, tables, strformat, strutils]

proc main() =
  echo "Progress Reporting Example"
  echo "-------------------------"
  echo ""
  
  # Set up a temporary directory for our example
  let tempDir = getTempDir() / "niuv_progress_example"
  removeDir(tempDir)
  createDir(tempDir)
  
  echo "Setting up example tasks with progress reporting..."
  
  # Create a sequence of tasks with different durations and progress intervals
  var tasks: seq[ParallelTask] = @[
    # Task 1: Quick task with short progress interval
    ParallelTask(
      id: "quick_task",
      command: "sleep 5",  # 5 second task
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: High,
      expectedDuration: 5.0,  # 5 seconds expected
      progressInterval: 0.5   # Update progress every 0.5 seconds
    ),
    
    # Task 2: Medium task with moderate progress interval
    ParallelTask(
      id: "medium_task",
      command: "sleep 10",  # 10 second task
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: Normal,
      expectedDuration: 10.0,  # 10 seconds expected
      progressInterval: 1.0    # Update progress every 1 second
    ),
    
    # Task 3: Slow task with longer progress interval and dependencies
    ParallelTask(
      id: "slow_task",
      command: "sleep 15",  # 15 second task
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: Low,
      dependencies: @["quick_task"],  # Depends on quick_task
      expectedDuration: 15.0,  # 15 seconds expected
      progressInterval: 2.0    # Update progress every 2 seconds
    ),
    
    # Task 4: Custom progress message task
    ParallelTask(
      id: "custom_progress_task",
      command: fmt"echo 'Loop task starting' && for i in $(seq 1 10); do echo 'Processing item $i'; sleep 1; done",
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: Normal,
      dependencies: @["medium_task"],  # Depends on medium_task
      expectedDuration: 10.0,  # 10 seconds expected
      progressInterval: 1.0    # Update progress every 1 second
    )
  ]
  
  echo "Running tasks with progress reporting enabled..."
  echo ""
  
  # Enable progress display and run the tasks
  enableProgressDisplay(true)
  
  # Run the tasks and collect results
  let results = executeParallel(tasks, 4)  # Run with 4 parallel jobs
  
  echo ""
  echo "All tasks completed!"
  echo "-------------------"
  echo "Results summary:"
  
  # Display results
  for result in results:
    let status = if result.exitCode == 0: "SUCCESS" else: "FAILED"
    echo fmt"Task '{result.id}': {status} (took {result.elapsedTime:.2f}s)"
  
  # Clean up
  echo ""
  echo "Cleaning up temporary directory..."
  removeDir(tempDir)
  echo "Done!"

when isMainModule:
  main()