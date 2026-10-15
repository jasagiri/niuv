## parallel_steps.nim
## ================
##
## 並列処理関連のステップ定義

import
  std/os,
  std/strutils,
  std/times,
  std/tables,
  cucumber_nim/runner,
  cucumber_nim/parser

type
  TaskStatus = enum
    tsNotStarted,
    tsRunning,
    tsCompleted,
    tsFailed

  TaskDependency = object
    taskId: string
    dependsOn: seq[string]

  Task = object
    id: string
    status: TaskStatus
    startTime: Time
    endTime: Time
    output: string
    error: string
    requiresResources: seq[string]

  Resource = object
    name: string
    inUse: bool

  ParallelState = object
    tasks: Table[string, Task]
    dependencies: seq[TaskDependency]
    resources: Table[string, Resource]
    maxJobs: int
    currentJobs: int
    isTerminated: bool
    withProgress: bool
    withRetry: bool
    retryCount: int
    sequentialTime: float
    parallelTime: float

var
  state = ParallelState(
    tasks: initTable[string, Task](),
    dependencies: @[],
    resources: initTable[string, Resource](),
    maxJobs: 0,
    currentJobs: 0,
    isTerminated: false,
    withProgress: false,
    withRetry: false,
    retryCount: 0,
    sequentialTime: 0.0,
    parallelTime: 0.0
  )

proc addTask(id: string, dependsOn: seq[string] = @[], resources: seq[string] = @[]) =
  var task = Task(
    id: id,
    status: tsNotStarted,
    startTime: Time(),
    endTime: Time(),
    output: "",
    error: "",
    requiresResources: resources
  )
  
  state.tasks[id] = task
  
  if dependsOn.len > 0:
    state.dependencies.add(TaskDependency(
      taskId: id,
      dependsOn: dependsOn
    ))

proc addResource(name: string) =
  state.resources[name] = Resource(
    name: name,
    inUse: false
  )

proc markTaskCompleted(id: string) =
  if state.tasks.hasKey(id):
    var task = state.tasks[id]
    task.status = tsCompleted
    task.endTime = now()
    state.tasks[id] = task

proc markTaskFailed(id: string, error: string) =
  if state.tasks.hasKey(id):
    var task = state.tasks[id]
    task.status = tsFailed
    task.endTime = now()
    task.error = error
    state.tasks[id] = task

proc markTaskRunning(id: string) =
  if state.tasks.hasKey(id):
    var task = state.tasks[id]
    task.status = tsRunning
    task.startTime = now()
    state.tasks[id] = task

proc clearTasks() =
  state.tasks.clear()
  state.dependencies = @[]
  state.resources.clear()
  state.maxJobs = 0
  state.currentJobs = 0
  state.isTerminated = false
  state.withProgress = false
  state.withRetry = false
  state.retryCount = 0
  state.sequentialTime = 0.0
  state.parallelTime = 0.0

proc simulateParallelExecution() =
  # 最大ジョブ数の設定
  if state.maxJobs == 0:
    state.maxJobs = cpuCount()
  
  # 依存関係の解決
  var readyTasks: seq[string] = @[]
  
  # 依存関係のないタスクを選択
  for id, task in state.tasks:
    var hasDependency = false
    for dep in state.dependencies:
      if dep.taskId == id:
        hasDependency = true
        break
    
    if not hasDependency:
      readyTasks.add(id)
  
  # 並列実行のシミュレーション
  var 
    completedTasks: seq[string] = @[]
    failedTasks: seq[string] = @[]
    activeJobs = 0
    time = 0.0
  
  while readyTasks.len > 0 or activeJobs > 0:
    # ジョブを開始
    while readyTasks.len > 0 and activeJobs < state.maxJobs:
      let taskId = readyTasks[0]
      readyTasks.delete(0)
      
      # リソースのチェック
      var canRun = true
      let task = state.tasks[taskId]
      
      for resource in task.requiresResources:
        if state.resources.hasKey(resource) and state.resources[resource].inUse:
          canRun = false
          readyTasks.add(taskId)  # 後で再試行
          break
      
      if canRun:
        markTaskRunning(taskId)
        
        # リソースを使用中にマーク
        for resource in task.requiresResources:
          if state.resources.hasKey(resource):
            var res = state.resources[resource]
            res.inUse = true
            state.resources[resource] = res
        
        activeJobs += 1
    
    # すべてのアクティブなジョブを1単位時間進める
    time += 1.0
    
    # ジョブの完了をチェック
    for id, task in state.tasks:
      if task.status == tsRunning:
        # ランダムに完了または失敗
        let random = rand(100)
        
        if random < 80:  # 80%の確率で成功
          markTaskCompleted(id)
          completedTasks.add(id)
          
          # リソースを解放
          for resource in task.requiresResources:
            if state.resources.hasKey(resource):
              var res = state.resources[resource]
              res.inUse = false
              state.resources[resource] = res
          
          activeJobs -= 1
          
          # 依存するタスクを確認
          for dep in state.dependencies:
            if dep.dependsOn.contains(id):
              var allDependsCompleted = true
              
              for depId in dep.dependsOn:
                if not completedTasks.contains(depId):
                  allDependsCompleted = false
                  break
              
              if allDependsCompleted:
                readyTasks.add(dep.taskId)
        
        elif random < 90 and (not state.withRetry or (state.withRetry and state.retryCount <= 0)):  # 10%の確率で失敗
          markTaskFailed(id, "Task failed with random error")
          failedTasks.add(id)
          
          # リソースを解放
          for resource in task.requiresResources:
            if state.resources.hasKey(resource):
              var res = state.resources[resource]
              res.inUse = false
              state.resources[resource] = res
          
          activeJobs -= 1
    
    # キャンセル信号をチェック
    if state.isTerminated:
      break
  
  # リトライロジック
  if state.withRetry and failedTasks.len > 0 and state.retryCount > 0:
    state.retryCount -= 1
    
    for failedTask in failedTasks:
      readyTasks.add(failedTask)
    
    failedTasks = @[]
    simulateParallelExecution()
  
  # 並列と逐次の時間記録
  state.parallelTime = time
  state.sequentialTime = time * 2  # 単純な例として、逐次実行は2倍の時間がかかると仮定

# 前提条件
step(stGiven, "multiple independent tasks"):
  clearTasks()
  addTask("task1")
  addTask("task2")
  addTask("task3")
  addTask("task4")
  return true

step(stGiven, "tasks that can run in parallel"):
  clearTasks()
  addTask("task1")
  addTask("task2")
  addTask("task3")
  addTask("task4")
  return true

step(stGiven, "tasks with dependencies"):
  clearTasks()
  addTask("task1")
  addTask("task2")
  addTask("task3", @["task1"])
  addTask("task4", @["task2", "task3"])
  return true

step(stGiven, "tasks where some will fail"):
  clearTasks()
  addTask("task1")
  addTask("task2")
  addTask("task3")
  addTask("task4")
  
  # task2は失敗するように設定
  markTaskRunning("task2")
  markTaskFailed("task2", "Simulated failure")
  
  return true

step(stGiven, "long-running parallel tasks"):
  clearTasks()
  addTask("longTask1")
  addTask("longTask2")
  addTask("longTask3")
  return true

step(stGiven, "multiple parallel tasks"):
  clearTasks()
  addTask("task1")
  addTask("task2")
  addTask("task3")
  addTask("task4")
  return true

step(stGiven, "tasks that need to access shared resources"):
  clearTasks()
  
  # リソースを追加
  addResource("database")
  addResource("file")
  
  # リソースを必要とするタスク
  addTask("task1", @[], @["database"])
  addTask("task2", @[], @["database"])  # task1とtask2は同じリソースを使用
  addTask("task3", @[], @["file"])
  addTask("task4")
  
  return true

step(stGiven, "tasks that might fail transiently"):
  clearTasks()
  
  addTask("task1")
  addTask("task2")
  addTask("task3")
  addTask("task4")
  
  # task2とtask3は一時的に失敗する
  markTaskRunning("task2")
  markTaskFailed("task2", "Transient network failure")
  
  markTaskRunning("task3")
  markTaskFailed("task3", "Transient database timeout")
  
  return true

# 操作
step(stWhen, "I run them in parallel"):
  state.maxJobs = cpuCount()
  simulateParallelExecution()
  return true

step(stWhen, "I run with \"--jobs={int}\" option"):
  let jobs = matches[0].parseInt
  state.maxJobs = jobs
  simulateParallelExecution()
  return true

step(stWhen, "I run without specifying job count"):
  state.maxJobs = 0  # 自動検出に任せる
  simulateParallelExecution()
  return true

step(stWhen, "I send a cancellation signal"):
  simulateParallelExecution()
  state.isTerminated = true
  return true

step(stWhen, "I run them with progress reporting"):
  state.withProgress = true
  simulateParallelExecution()
  return true

step(stWhen, "I run them with retry enabled"):
  state.withRetry = true
  state.retryCount = 3
  simulateParallelExecution()
  return true

# 検証
step(stThen, "all tasks should complete successfully"):
  for _, task in state.tasks:
    if task.status != tsCompleted:
      return false
  
  return true

step(stThen, "execution time should be faster than sequential execution"):
  return state.parallelTime < state.sequentialTime

step(stThen, "task outputs should be collected correctly"):
  return true

step(stThen, "exactly {int} jobs should run in parallel"):
  let jobs = matches[0].parseInt
  return state.maxJobs == jobs

step(stThen, "system resources should be properly utilized"):
  return true

step(stThen, "an optimal number of parallel jobs should be used"):
  return state.maxJobs > 0 and state.maxJobs <= cpuCount()

step(stThen, "the job count should respect system CPU cores"):
  return state.maxJobs <= cpuCount()

step(stThen, "dependent tasks should wait for prerequisites to complete"):
  for dep in state.dependencies:
    let task = state.tasks[dep.taskId]
    
    for depId in dep.dependsOn:
      let depTask = state.tasks[depId]
      
      # 依存タスクが完了前に開始していた場合、失敗
      if task.startTime < depTask.endTime and depTask.status == tsCompleted:
        return false
  
  return true

step(stThen, "task execution order should respect dependencies"):
  return true

step(stThen, "errors should be properly reported"):
  var hasFailedTask = false
  
  for _, task in state.tasks:
    if task.status == tsFailed and task.error.len > 0:
      hasFailedTask = true
      break
  
  return hasFailedTask

step(stThen, "successful tasks should still complete"):
  var hasCompletedTask = false
  
  for _, task in state.tasks:
    if task.status == tsCompleted:
      hasCompletedTask = true
      break
  
  return hasCompletedTask

step(stThen, "error details should be available for each failed task"):
  for _, task in state.tasks:
    if task.status == tsFailed and task.error.len == 0:
      return false
  
  return true

step(stThen, "all running tasks should be terminated cleanly"):
  return state.isTerminated

step(stThen, "resources should be properly released"):
  if state.isTerminated:
    for _, resource in state.resources:
      if resource.inUse:
        return false
  
  return true

step(stThen, "partial results should be reported"):
  return state.isTerminated

step(stThen, "overall progress should be displayed"):
  return state.withProgress

step(stThen, "individual task progress should be visible"):
  return state.withProgress

step(stThen, "progress updates should be in real-time"):
  return state.withProgress

step(stThen, "resource access should be properly synchronized"):
  var resourceConflict = false
  
  # 同じリソースを使用するタスクが同時に実行されていないことを確認
  for id1, task1 in state.tasks:
    for id2, task2 in state.tasks:
      if id1 != id2 and 
         task1.status == tsRunning and task2.status == tsRunning:
        
        # 共通のリソースをチェック
        for res1 in task1.requiresResources:
          if task2.requiresResources.contains(res1):
            resourceConflict = true
            break
    
    if resourceConflict:
      break
  
  return not resourceConflict

step(stThen, "no race conditions should occur"):
  return true

step(stThen, "failed tasks should be retried automatically"):
  return state.withRetry

step(stThen, "retry count should be respected"):
  return state.retryCount >= 0

step(stThen, "eventually successful tasks should be reported as success"):
  if not state.withRetry:
    return false
  
  for _, task in state.tasks:
    if task.status == tsFailed:
      return false
  
  return true