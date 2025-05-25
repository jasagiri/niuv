# テスト環境初期化スクリプト

import os

proc initTestEnv*() =
  ## テスト環境を初期化する
  let
    envDir = "tests/fixtures/testenv"
    configFile = "tests/fixtures/testenv/nim.cfg"
    configJson = "tests/fixtures/testenv/.niuv.json"
    testMarker = "tests/fixtures/testenv/test_marker"

  # テスト環境ディレクトリを作成
  if not dirExists(envDir):
    createDir(envDir)
    echo "Created test environment directory: ", envDir

  # 設定ファイルを作成
  if not fileExists(configFile):
    writeFile(configFile, """
# Test environment configuration
--path:../src
--path:../test
--path:../testenv
""")
    echo "Created config file: ", configFile

  # JSON設定ファイルを作成
  if not fileExists(configJson):
    writeFile(configJson, """{
  "nimVersion": "2.2.4",
  "projectName": "test_project",
  "parallelJobs": 4,
  "verbose": true
}""")
    echo "Created JSON config: ", configJson

  # テストマーカーファイルを作成
  if not fileExists(testMarker):
    writeFile(testMarker, "Test environment initialized successfully")
    echo "Created test marker file: ", testMarker

  echo "Test environment initialized successfully"

when isMainModule:
  initTestEnv()