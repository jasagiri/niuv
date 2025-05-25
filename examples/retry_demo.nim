import ../src/parallel
import std/[os, tables, strformat, strutils, random, algorithm]

proc createFlakyCommand(successProbability: float = 0.3): string =
  # Creates a command that succeeds with the given probability
  # For demonstration purposes, this uses random numbers for simulation
  # In a real-world scenario, you would use actual commands that might fail
  
  # Generate a random seed based on current time
  randomize()
  
  # Commands for different platforms
  when defined(windows):
    # Windows version using PowerShell
    return "powershell -Command \"if ((Get-Random -Minimum 0 -Maximum 100) -lt " & $int(successProbability * 100) & ") { exit 0 } else { Write-Error 'Simulated failure'; exit 1 }\""
  else:
    # Unix version
    return "bash -c 'if (( $(echo \"$(( RANDOM % 100 )) < " & $int(successProbability * 100) & "\" | bc -l) )); then echo \"Success!\"; else echo \"Simulated failure\" >&2; exit 1; fi'"

proc main() =
  echo "Task Retry Capability Demo"
  echo "-------------------------"
  echo ""
  
  # Set up a temporary directory for our example
  let tempDir = getTempDir() / "niuv_retry_example"
  removeDir(tempDir)
  createDir(tempDir)
  
  echo "This example demonstrates the task retry capability for handling flaky commands."
  echo "We'll create several tasks with different retry policies:"
  echo "1. A reliable task that always succeeds (no retry needed)"
  echo "2. A flaky task with no retry policy (will likely fail)"
  echo "3. A flaky task with 3 retry attempts (higher chance of success)"
  echo "4. A very flaky task with 10 retry attempts (even higher chance of success)"
  echo ""
  
  # Create a sequence of tasks with different retry settings
  var tasks: seq[ParallelTask] = @[
    # Task 1: Reliable task (always succeeds)
    ParallelTask(
      id: "reliable_task",
      command: "echo 'This is a reliable task that always succeeds'",
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: High,
      maxRetries: 0,  # No retries needed
      retryDelay: 1.0
    ),
    
    # Task 2: Flaky task with no retry (30% chance of success)
    ParallelTask(
      id: "flaky_no_retry",
      command: createFlakyCommand(0.3),
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: Normal,
      maxRetries: 0,  # No retries
      retryDelay: 1.0
    ),
    
    # Task 3: Flaky task with 3 retries (30% chance of success per attempt)
    ParallelTask(
      id: "flaky_with_retry",
      command: createFlakyCommand(0.3),
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: Normal,
      maxRetries: 3,  # 3 retry attempts
      retryDelay: 1.0
    ),
    
    # Task 4: Very flaky task (10% chance of success) with 10 retries
    ParallelTask(
      id: "very_flaky_with_retry",
      command: createFlakyCommand(0.1),
      workingDir: tempDir,
      env: initTable[string, string](),
      priority: Low,
      maxRetries: 10,  # 10 retry attempts
      retryDelay: 0.5  # Shorter delay between retries
    )
  ]
  
  echo "Running tasks with different retry policies..."
  echo "Each flaky task has a random chance of success on each attempt."
  echo "Notice how retry capabilities improve the overall success rate."
  echo ""
  
  # Enable progress display for better visibility
  enableProgressDisplay(true)
  
  # Run the tasks and collect results
  let results = executeParallel(tasks, 1)  # Run sequentially for clearer demonstration
  
  echo ""
  echo "All tasks completed!"
  echo "Results summary:"
  
  # Display results
  var succeeded = 0
  var failed = 0
  for r in results:
    if r.status == Completed:
      succeeded += 1
    elif r.status == Failed:
      failed += 1

  echo "Tasks succeeded: " & $succeeded & "/" & $results.len
  echo "Tasks failed: " & $failed & "/" & $results.len
  echo ""
  
  # Show detailed results
  for result in results:
    echo "Task '" & result.id & "':"
    echo "  - Status: " & $result.status
    echo "  - Exit code: " & $result.exitCode

    # Print information about retries if applicable
    if result.retryCount > 0:
      echo "  - Retried " & $result.retryCount & " time(s)"

      # If the task succeeded after retries, show that
      if result.status == Completed:
        echo "  - Succeeded after " & $result.retryCount & " retries"
      else:
        echo "  - Failed despite " & $result.retryCount & " retries"
    
    echo ""
  
  # Clean up
  echo "Cleaning up temporary directory..."
  removeDir(tempDir)
  echo "Done!"

when isMainModule:
  main()