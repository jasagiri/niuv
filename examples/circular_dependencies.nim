import std/[tables, os, strutils, strutils]
import ../src/parallel

# Example of detecting circular dependencies
# This demonstrates how circular dependencies are detected
# and reported with a descriptive error.

# Create a temporary directory for our example
var tempDir = getTempDir() / "niuv_circular_example"
if not dirExists(tempDir):
  createDir(tempDir)

echo "Using temporary directory: ", tempDir

# Define a cyclic dependency graph:
#
# task1 → task2 → task3 → task1 (CYCLE!)

# Create tasks with a circular dependency
var tasks: seq[ParallelTask] = @[
  # Task 1: Depends on Task 3 (creates a cycle)
  ParallelTask(
    id: "task1",
    command: "echo \"Task 1 running\"",
    workingDir: tempDir,
    env: initTable[string, string](),
    priority: Normal,
    dependencies: @["task3"]  # This creates a cycle!
  ),
  
  # Task 2: Depends on Task 1
  ParallelTask(
    id: "task2",
    command: "echo \"Task 2 running\"",
    workingDir: tempDir,
    env: initTable[string, string](),
    priority: Normal,
    dependencies: @["task1"]
  ),
  
  # Task 3: Depends on Task 2
  ParallelTask(
    id: "task3",
    command: "echo \"Task 3 running\"",
    workingDir: tempDir,
    env: initTable[string, string](),
    priority: Normal,
    dependencies: @["task2"]
  )
]

# Try to run tasks with circular dependencies
echo "Attempting to run tasks with circular dependencies..."
try:
  let results = executeParallel(tasks)
  echo "Unexpected success! This should have failed due to circular dependencies."
except DependencyError as e:
  echo "Detected cyclic dependency (as expected):"
  echo "  Error: ", e.msg

# Now let's fix the circular dependency
echo "\nFixing the circular dependency..."
tasks[0].dependencies = @[]  # Remove the dependency that creates the cycle

# Enable verbose output to see the dependency graph
putEnv("NIUV_VERBOSE", "1")

# Run with the fixed dependencies
echo "Running tasks with fixed dependencies..."
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