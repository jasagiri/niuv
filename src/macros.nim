import std/[macros, os, times]
import ./utils  # formatDuration

type
  NiuvError* = object of CatchableError

# withEnv マクロ: 一時的に環境変数を変更して処理を実行
macro withEnv*(envVars: openArray[tuple[key, val: string]], body: untyped): untyped =
  ## 一時的に環境変数を変更してコードブロックを実行するマクロ
  ## 
  ## 例:
  ## ```
  ## withEnv([("PATH", "new_path"), ("NIMBLE_PATH", "new_nimble_path")]):
  ##   echo getEnv("PATH")  # new_path
  ## # 環境変数は元に戻る
  ## ```
  
  result = newStmtList()
  
  # 元の環境変数を保存
  let oldEnvVars = genSym(nskVar, "oldEnvVars")
  result.add quote do:
    var `oldEnvVars` = newSeq[(string, string)]()
  
  # 環境変数を変更し、元の値を保存
  for i in 0 ..< envVars.len:
    let key = newLit(envVars[i][0])
    let val = newLit(envVars[i][1])
    
    result.add quote do:
      `oldEnvVars`.add((`key`, getEnv(`key`)))
      putEnv(`key`, `val`)
  
  # 本体を実行
  result.add body
  
  # 環境変数を元に戻す
  result.add quote do:
    for (key, val) in `oldEnvVars`:
      putEnv(key, val)

# benchmark マクロ: コードの実行時間を計測
macro benchmark*(name: string, body: untyped): untyped =
  ## コードブロックの実行時間を計測するマクロ
  ##
  ## 例:
  ## ```
  ## benchmark "My operation":
  ##   # 計測したいコード
  ##   doSomething()
  ## # 「My operation took 1.234 seconds」のように出力される
  ## ```
  
  result = quote do:
    let startTime = cpuTime()
    var benchmarkResult {.inject.} = block:
      `body`
    let endTime = cpuTime()
    let duration = endTime - startTime
    echo `name`, " took ", formatDuration(duration)
    benchmarkResult

# safeExec マクロ: 例外を捕捉して安全に実行
macro safeExec*(body: untyped, handler: untyped = nil): untyped =
  ## 例外を捕捉して安全に実行するマクロ
  ##
  ## 例:
  ## ```
  ## safeExec:
  ##   riskyOperation()
  ## do (e: ref Exception):
  ##   echo "エラー: ", e.msg
  ## ```
  
  var handlerBody = if handler.kind == nnkNilLit: 
                       quote do: 
                         echo "Error: ", getCurrentExceptionMsg()
                         false
                     else:
                       handler
  
  result = quote do:
    try:
      `body`
      true
    except:
      `handlerBody`

# ensureDir マクロ: ディレクトリが存在することを確認
macro ensureDir*(dirs: varargs[string]): untyped =
  ## 指定されたディレクトリが存在することを確認し、必要なら作成するマクロ
  ##
  ## 例:
  ## ```
  ## ensureDir "path/to/dir", "another/dir"
  ## ```
  
  result = newStmtList()
  
  for dir in dirs:
    result.add quote do:
      if not dirExists(`dir`):
        try:
          createDir(`dir`)
        except:
          raise newException(NiuvError, "Failed to create directory: " & `dir`)

# withTempDir マクロ: 一時ディレクトリを作成して処理を実行
macro withTempDir*(dirVarName: untyped, body: untyped): untyped =
  ## 一時ディレクトリを作成し、処理後に削除するマクロ
  ##
  ## 例:
  ## ```
  ## withTempDir tmpDir:
  ##   writeFile(tmpDir / "test.txt", "Hello")
  ## # 一時ディレクトリは自動的に削除される
  ## ```
  
  result = quote do:
    let `dirVarName` = getTempDir() / "niuv_" & $getCurrentProcessId() & "_" & $getTime().toUnix()
    try:
      createDir(`dirVarName`)
      `body`
    finally:
      try:
        removeDir(`dirVarName`)
      except:
        echo "Warning: Failed to remove temporary directory: ", `dirVarName`
