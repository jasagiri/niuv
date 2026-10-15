import std/[tables, os, strutils, strutils]
import ../src/parallel

# Example of using task dependencies in parallel execution
# This demonstrates how to create a graph of dependent tasks
# and ensure they execute in the correct order, even when
# running in parallel.

# Create a temporary directory for our example
var tempDir = getTempDir() / "niuv_dependency_example"
if not dirExists(tempDir):
  createDir(tempDir)

echo "Using temporary directory: ", tempDir

# Define a simple dependency graph:
#
# task1 → task3 → task5
#    ↓     ↑     ↑
# task2 → task4 →┘

# Create tasks with dependencies
var tasks: seq[ParallelTask] = @[
  # Task 1: No dependencies
  ParallelTask(
    id: "task1",
    command: "echo \"Task 1 running\" && sleep 1",
    workingDir: tempDir,
    env: initTable[string, string](),
    priority: Normal
  ),
  
  # Task 2: No dependencies
  ParallelTask(
    id: "task2",
    command: "echo \"Task 2 running\" && sleep 1",
    workingDir: tempDir,
    env: initTable[string, string](),
    priority: Normal
  ),
  
  # Task 3: Depends on Task 1
  ParallelTask(
    id: "task3",
    command: "echo \"Task 3 running (after task1)\" && sleep 1",
    workingDir: tempDir,
    env: initTable[string, string](),
    priority: High,  # High priority, but still respects dependencies
    dependencies: @["task1"]
  ),
  
  # Task 4: Depends on Task 2
  ParallelTask(
    id: "task4",
    command: "echo \"Task 4 running (after task2)\" && sleep 1",
    workingDir: tempDir,
    env: initTable[string, string](),
    priority: Normal,
    dependencies: @["task2"]
  ),
  
  # Task 5: Depends on Task 3 and Task 4
  ParallelTask(
    id: "task5",
    command: "echo \"Task 5 running (after task3 and task4)\" && sleep 1",
    workingDir: tempDir,
    env: initTable[string, string](),
    priority: Low,  # Low priority, but dependent on earlier tasks
    dependencies: @["task3", "task4"]
  )
]

# Enable verbose output to see the dependency graph
putEnv("NIUV_VERBOSE", "1")

echo "Running tasks with dependencies..."
let results = executeParallel(tasks)

echo "\n--- Execution Summary ---"
for result in results:
  echo "Task ", result.id, " completed with exit code ", result.exitCode
  echo "  Output: ", result.output.strip()
  if result.dependsOn.len > 0:
    echo "  Dependencies: [", result.dependsOn.join(", "), "]"

# Cleanup
putEnv("NIUV_VERBOSE", "0")
echo "\nCleaning up temporary directory..."
removeDir(tempDir)
echo "Done."