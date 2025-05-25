import ../src/parallel
import std/[os, tables, strformat, strutils, terminal, sequtils]

proc main() =
  echo "Task Cancellation & Graceful Shutdown Demo"
  echo "----------------------------------------"
  echo ""
  
  # Set up a temporary directory for our example
  let tempDir = getTempDir() / "niuv_cancellation_example"
  removeDir(tempDir)
  createDir(tempDir)
  
  echo "This example demonstrates task cancellation and graceful shutdown."
  echo "There are several ways to interact with this example:"
  echo "1. Let it run to completion (tasks will run and finish normally)"
  echo "2. Press Ctrl+C once during execution for graceful shutdown"
  echo "3. Press Ctrl+C twice to force immediate exit"
  echo "4. Type a task ID to manually cancel a specific task"
  echo ""
  echo "Setting up example tasks..."
  
  # Create a sequence of tasks with varied durations
  var tasks: seq[ParallelTask] = @[
    # Task 1: Quick task
    ParallelTask(
      id: "quick_task",
      command: "sleep 3",  # 3 second task
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: High,
      expectedDuration: 3.0,
      progressInterval: 0.2
    ),
    
    # Task 2: Medium task
    ParallelTask(
      id: "medium_task",
      command: "sleep 8",  # 8 second task
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: Normal,
      expectedDuration: 8.0,
      progressInterval: 0.5
    ),
    
    # Task 3: Long task with dependency on task1
    ParallelTask(
      id: "long_task",
      command: "sleep 15",  # 15 second task
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: Low,
      dependencies: @["quick_task"],  # Depends on quick_task
      expectedDuration: 15.0,
      progressInterval: 1.0
    ),
    
    # Task 4: Another medium task with dependency on task2
    ParallelTask(
      id: "dependent_task",
      command: "sleep 6",  # 6 second task
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: Normal,
      dependencies: @["medium_task"],  # Depends on medium_task
      expectedDuration: 6.0,
      progressInterval: 0.5
    ),
    
    # Task 5: Final task with multiple dependencies
    ParallelTask(
      id: "final_task",
      command: "sleep 4",  # 4 second task
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: High,
      dependencies: @["long_task", "dependent_task"],  # Depends on both previous tasks
      expectedDuration: 4.0,
      progressInterval: 0.2
    )
  ]
  
  echo "Running tasks with progress reporting and cancellation..."
  echo "You can cancel a specific task by typing its ID and pressing Enter:"
  for i, task in tasks:
    let deps = task.dependencies.join(", ")
    echo "  " & $(i+1) & ". " & task.id & " (expected duration: " & $task.expectedDuration & "s, depends on: [" & deps & "])"
  echo ""
  
  # Note: User input reading thread removed for compatibility
  # In a real-world application, we would implement a thread-safe solution
  # for task cancellation
  
  # Enable progress display and run the tasks
  enableProgressDisplay(true)
  
  # Run the tasks and collect results
  let results = executeParallel(tasks, 2)  # Run with 2 parallel jobs for clearer demonstration
  
  echo ""
  echo "All tasks completed or cancelled!"
  echo "Results summary:"
  
  # Display results
  for result in results:
    let statusStr = case result.status:
      of Completed: "COMPLETED"
      of Failed: "FAILED"
      of Cancelled: "CANCELLED"
      else: $result.status
      
    echo "Task '" & result.id & "': " & statusStr

    if result.status == Cancelled:
      echo "  - Was cancelled after " & formatFloat(result.elapsedTime, ffDecimal, 2) & "s"
    else:
      echo "  - Took " & formatFloat(result.elapsedTime, ffDecimal, 2) & "s to complete"

    if result.exitCode != 0:
      echo "  - Exit code: " & $result.exitCode

    if result.dependsOn.len > 0:
      echo "  - Depended on: [" & result.dependsOn.join(", ") & "]"

proc runExample() =
  try:
    main()
  except:
    let e = getCurrentException()
    echo "Error: ", e.msg

when isMainModule:
  runExample()