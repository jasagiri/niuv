## run_features.nim
## ==============
##
## Cucumberスタイルのfeatureテストを実行するためのラッパー
## このファイルは互換性のために残されています。
## 新しいfeature_runner.nimに移行してください。

import
  std/os,
  std/strformat

when isMainModule:
  echo "This file is maintained for backwards compatibility."
  echo "Use the feature_runner in src/tools/test/feature_runner.nim instead."
  echo "Script wrapper is available at: scripts/features/run_features.sh"
  
  const scriptPath = getEnv("OS").toLowerAscii.contains("windows") ? 
    getCurrentDir() / "scripts/features/run_features.bat" :
    getCurrentDir() / "scripts/features/run_features.sh"
  
  if fileExists(scriptPath):
    let params = commandLineParams()
    var cmd = scriptPath
    for param in params:
      cmd.add(" " & param)
    
    echo fmt"Executing: {cmd}"
    discard execShellCmd(cmd)
  else:
    echo fmt"Error: Script not found at {scriptPath}"
    quit(1)