## Task execution system for niuv
## Provides nimble-compatible task execution with enhancements

import std/[os, osproc, strutils, sequtils, tables, re, json]
import ../utils
import ../config
import ../delegation/[base, nimble_adapter]

type
  Task* = object
    name*: string
    description*: string
    body*: string
    dependencies*: seq[string]
    
  TaskGraph* = object
    tasks*: Table[string, Task]
    executionOrder*: seq[string]

proc parseNimbleFile*(path: string): seq[Task] =
  ## Parse tasks from a .nimble file
  result = @[]
  let content = readFile(path)
  
  # Regex to match task definitions
  let taskPattern = re"""task\s+(\w+)\s*,\s*"([^"]+)"\s*:"""
  var matches: array[2, string]
  var pos = 0
  
  while true:
    let matchPos = content.find(taskPattern, pos)
    if matchPos == -1:
      break
    
    if content.match(taskPattern, matches, matchPos):
      var task = Task(
        name: matches[0],
        description: matches[1],
        body: "",
        dependencies: @[]
      )
      
      # Find task body (everything until next task or end)
      let taskStart = content.find(":", matchPos) + 1
      var taskEnd = content.len
      
      # Look for next task
      let nextTaskPos = content.find(taskPattern, taskStart)
      if nextTaskPos != -1:
        taskEnd = nextTaskPos
      
      # Extract body and clean up indentation
      task.body = content[taskStart..<taskEnd].strip()
      
      # Parse dependencies from exec calls to other tasks
      let depPattern = re"""exec\s*"niuv\s+(\w+)""""
      var depMatches: array[1, string]
      var depPos = 0
      while task.body.match(depPattern, depMatches, depPos):
        task.dependencies.add(depMatches[0])
        depPos = task.body.find(depPattern, depPos) + 1
      
      result.add(task)
      pos = taskStart
    else:
      break

proc parseNiuvTasks*(config: Config): seq[Task] =
  ## Parse tasks from niuv configuration
  result = @[]
  # TODO: Implement when Config has tasks field

proc buildTaskGraph*(tasks: seq[Task]): TaskGraph =
  ## Build a task dependency graph
  result.tasks = initTable[string, Task]()
  for task in tasks:
    result.tasks[task.name] = task
  
  # Topological sort for execution order
  var visited = initTable[string, bool]()
  var tempMark = initTable[string, bool]()
  var order: seq[string] = @[]
  
  let tasksRef = new Table[string, Task]
  tasksRef[] = result.tasks
  
  proc visit(name: string) =
    if tempMark.getOrDefault(name, false):
      raise newException(ValueError, "Circular dependency detected in task: " & name)
    
    if not visited.getOrDefault(name, false):
      tempMark[name] = true
      
      if name in tasksRef[]:
        for dep in tasksRef[][name].dependencies:
          visit(dep)
      
      tempMark[name] = false
      visited[name] = true
      order.insert(name, 0)
  
  for taskName in result.tasks.keys:
    if not visited.getOrDefault(taskName, false):
      visit(taskName)
  
  result.executionOrder = order

proc executeTask*(task: Task, env: Table[string, string] = initTable[string, string]()): int =
  ## Execute a single task
  echo "Executing task '", task.name, "': ", task.description
  
  # Prepare environment
  var taskEnv = env
  taskEnv["TASK_NAME"] = task.name
  
  # Execute task body line by line
  for line in task.body.splitLines():
    let trimmed = line.strip()
    if trimmed == "" or trimmed.startsWith("#"):
      continue
    
    # Handle exec calls
    if trimmed.startsWith("exec "):
      let cmd = trimmed[5..^1].strip().strip(chars = {'"'})
      echo "  > ", cmd
      let (output, exitCode) = execCmdEx(cmd)
      if exitCode != 0:
        echo "Task failed: ", output
        return exitCode
      elif output.strip() != "":
        echo output.strip()
    
    # Handle echo calls
    elif trimmed.startsWith("echo "):
      let msg = trimmed[5..^1].strip().strip(chars = {'"'})
      echo msg
    
    # Handle other nim code (simplified)
    else:
      # For now, just execute as shell command
      let (output, exitCode) = execCmdEx(trimmed)
      if exitCode != 0:
        echo "Command failed: ", trimmed
        echo output
        return exitCode
  
  return 0

proc listTasks*(tasks: seq[Task]) =
  ## List all available tasks
  if tasks.len == 0:
    echo "No tasks defined"
    return
  
  echo "Available tasks:"
  echo ""
  
  let maxNameLen = tasks.mapIt(it.name.len).max + 2
  
  for task in tasks:
    echo "  ", task.name.alignLeft(maxNameLen), task.description
    if task.dependencies.len > 0:
      echo "    Depends on: ", task.dependencies.join(", ")

proc runTask*(config: DelegationConfig, taskName: string, args: seq[string] = @[]): int =
  ## Run a task with delegation support
  # First, try delegation to nimble
  config.delegateOr(dcTaskExecution):
    let options = {"args": args.join(" ")}.toTable
    let result = executeTasks(config, @[taskName], options)
    if result.success:
      for output in result.value:
        echo output
      return 0
    else:
      echo "Delegated task failed: ", result.error
      return 1
  do:
    # Fallback: Parse and execute tasks locally
    let nimbleFiles = toSeq(walkFiles("*.nimble"))
    if nimbleFiles.len == 0:
      echo "Error: No .nimble file found"
      return 1
    
    let tasks = parseNimbleFile(nimbleFiles[0])
    let graph = buildTaskGraph(tasks)
    
    if taskName notin graph.tasks:
      echo "Error: Task '", taskName, "' not found"
      echo ""
      listTasks(tasks)
      return 1
    
    # Execute task and its dependencies
    let task = graph.tasks[taskName]
    
    # Execute dependencies first
    for dep in task.dependencies:
      if dep in graph.tasks:
        let depResult = executeTask(graph.tasks[dep])
        if depResult != 0:
          echo "Dependency '", dep, "' failed"
          return depResult
    
    # Execute the task
    return executeTask(task)

proc taskCommand*(args: seq[string]): int =
  ## Main task command entry point
  if args.len == 0 or "--help" in args or "-h" in args:
    echo """
niuv task - Run tasks defined in .nimble file

Usage:
  niuv task <task-name> [args...]
  niuv task --list

Options:
  --list, -l     List all available tasks
  --help, -h     Show this help

Examples:
  niuv task test           # Run test task
  niuv task build          # Run build task
  niuv task docs           # Generate documentation
  niuv task --list         # List all tasks
"""
    return 0
  
  let config = loadDelegationConfig()
  
  if "--list" in args or "-l" in args:
    # List tasks
    let nimbleFiles = toSeq(walkFiles("*.nimble"))
    if nimbleFiles.len > 0:
      let tasks = parseNimbleFile(nimbleFiles[0])
      listTasks(tasks)
    else:
      echo "No .nimble file found"
    return 0
  
  # Run specified task
  let taskName = args[0]
  let taskArgs = if args.len > 1: args[1..^1] else: @[]
  
  return runTask(config, taskName, taskArgs)

# Convenience proc for running tasks directly
proc runNamedTask*(taskName: string): int =
  ## Run a named task (for backward compatibility)
  let config = loadDelegationConfig()
  return runTask(config, taskName)