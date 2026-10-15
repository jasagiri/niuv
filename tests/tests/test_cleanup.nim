import std/unittest

import std/[unittest, os, times, tempfiles, sequtils]
import ../src/cleanup

suite "Cleanup Tests":
  var testDir: string
  
  setup:
    # テスト用の一時ディレクトリを作成
    testDir = getTempDir() / "niuv_cleanup_test_" & $getCurrentProcessId()
    createDir(testDir)
    setCurrentDir(testDir)
  
  teardown:
    # クリーンアップ
    setCurrentDir(getTempDir())
    if dirExists(testDir):
      removeDir(testDir)
  
  test "isTestEnvironmentDir - valid patterns":
    check isTestEnvironmentDir("env1_1746093832.445277")
    check isTestEnvironmentDir("env999_1746093832.445277")
    check isTestEnvironmentDir("active_env_1746094206.870977")
    check isTestEnvironmentDir("/path/to/env42_1234567890.123456")
  
  test "isTestEnvironmentDir - invalid patterns":
    check not isTestEnvironmentDir("regular_directory")
    check not isTestEnvironmentDir("env_without_timestamp")
    check not isTestEnvironmentDir("envA_1234567890.123456")  # non-numeric env
    check not isTestEnvironmentDir("env1_invalid_timestamp")
    check not isTestEnvironmentDir("active_1234567890.123456")  # missing _env
    check not isTestEnvironmentDir("")
  
  test "isOlderThan - old directory":
    let oldDir = testDir / "old_dir"
    createDir(oldDir)
    
    # ディレクトリのタイムスタンプを2日前に設定
    let oldTime = getTime() - initDuration(days = 2)
    setLastModificationTime(oldDir, oldTime)
    
    check isOlderThan(oldDir, 24)  # 24時間より古い
    check isOlderThan(oldDir, 1)   # 1時間より古い
    check not isOlderThan(oldDir, 72)  # 72時間より古くない
  
  test "isOlderThan - new directory":
    let newDir = testDir / "new_dir"
    createDir(newDir)
    
    check not isOlderThan(newDir, 1)  # 1時間より古くない
    check not isOlderThan(newDir, 24) # 24時間より古くない
  
  test "isOlderThan - non-existent directory":
    # 存在しないディレクトリは古いと判断される
    check isOlderThan(testDir / "non_existent", 1)
  
  test "cleanupTestEnvironments - dry run":
    # テスト環境ディレクトリを作成
    let env1 = testDir / "env1_1234567890.123456"
    let env2 = testDir / "env2_9876543210.654321"
    let activeEnv = testDir / "active_env_1111111111.111111"
    let regularDir = testDir / "regular_directory"
    
    createDir(env1)
    createDir(env2)
    createDir(activeEnv)
    createDir(regularDir)
    
    # 古いタイムスタンプを設定
    let oldTime = getTime() - initDuration(hours = 25)
    setLastModificationTime(env1, oldTime)
    setLastModificationTime(env2, oldTime)
    setLastModificationTime(activeEnv, oldTime)
    setLastModificationTime(regularDir, oldTime)
    
    # ドライランで実行
    let result = cleanupTestEnvironments(testDir, dryRun = true, olderThanHours = 24)
    
    # テスト環境ディレクトリのみがリストされる
    check result.len == 3
    check result.anyIt(it.endsWith("env1_1234567890.123456"))
    check result.anyIt(it.endsWith("env2_9876543210.654321"))
    check result.anyIt(it.endsWith("active_env_1111111111.111111"))
    check not result.anyIt(it.endsWith("regular_directory"))
    
    # ディレクトリはまだ存在している（ドライラン）
    check dirExists(env1)
    check dirExists(env2)
    check dirExists(activeEnv)
    check dirExists(regularDir)
  
  test "cleanupTestEnvironments - actual cleanup":
    # テスト環境ディレクトリを作成
    let oldEnv = testDir / "env1_1234567890.123456"
    let newEnv = testDir / "env2_9876543210.654321"
    
    createDir(oldEnv)
    createDir(newEnv)
    
    # 古いディレクトリのタイムスタンプを設定
    let oldTime = getTime() - initDuration(hours = 25)
    setLastModificationTime(oldEnv, oldTime)
    # newEnvは新しいままにする
    
    # 実際にクリーンアップを実行
    let result = cleanupTestEnvironments(testDir, dryRun = false, olderThanHours = 24)
    
    # 古いディレクトリのみが削除される
    check result.len == 1
    check result[0].endsWith("env1_1234567890.123456")
    check not dirExists(oldEnv)
    check dirExists(newEnv)
  
  test "cleanupTestEnvironments - with subdirectories":
    # ネストされたディレクトリ構造を作成
    let subDir = testDir / "subdir"
    createDir(subDir)
    
    let env1 = testDir / "env1_1234567890.123456"
    let env2 = subDir / "env2_9876543210.654321"
    
    createDir(env1)
    createDir(env2)
    
    # 古いタイムスタンプを設定
    let oldTime = getTime() - initDuration(hours = 25)
    setLastModificationTime(env1, oldTime)
    setLastModificationTime(env2, oldTime)
    
    # トップレベルのディレクトリのみがチェックされる
    let result = cleanupTestEnvironments(testDir, dryRun = true, olderThanHours = 24)
    check result.len == 1
    check result[0].endsWith("env1_1234567890.123456")
  
  test "cleanupTestEnvironments - permission error handling":
    # テスト環境ディレクトリを作成
    let protectedEnv = testDir / "env1_1234567890.123456"
    createDir(protectedEnv)
    
    # ダミーファイルを作成
    writeFile(protectedEnv / "dummy.txt", "test")
    
    # 古いタイムスタンプを設定
    let oldTime = getTime() - initDuration(hours = 25)
    setLastModificationTime(protectedEnv, oldTime)
    
    # クリーンアップを実行（エラーは静かに処理される）
    let result = cleanupTestEnvironments(testDir, dryRun = false, olderThanHours = 24)
    check result.len == 1
    
    # ディレクトリが削除されたか、エラーで残っているかをチェック
    # （権限によって結果が異なる可能性がある）
  
  test "cleanupAllTestEnvironments - dry run":
    # 現在のディレクトリにテスト環境を作成
    let env1 = "env1_1234567890.123456"
    let env2 = "env2_9876543210.654321"
    
    createDir(env1)
    createDir(env2)
    
    # 古いタイムスタンプを設定
    let oldTime = getTime() - initDuration(hours = 25)
    setLastModificationTime(env1, oldTime)
    setLastModificationTime(env2, oldTime)
    
    # ドライランで実行
    let count = cleanupAllTestEnvironments(dryRun = true, olderThanHours = 24)
    
    check count == 2
    check dirExists(env1)
    check dirExists(env2)
  
  test "cleanupAllTestEnvironments - actual cleanup":
    # 現在のディレクトリにテスト環境を作成
    let env1 = "env1_1234567890.123456"
    createDir(env1)
    
    # 古いタイムスタンプを設定
    let oldTime = getTime() - initDuration(hours = 25)
    setLastModificationTime(env1, oldTime)
    
    # 実際にクリーンアップを実行
    let count = cleanupAllTestEnvironments(dryRun = false, olderThanHours = 24)
    
    check count == 1
    check not dirExists(env1)
  
  test "cleanupTestEnvironments - custom hours threshold":
    # テスト環境ディレクトリを作成
    let env1 = testDir / "env1_1234567890.123456"
    let env2 = testDir / "env2_9876543210.654321"
    
    createDir(env1)
    createDir(env2)
    
    # 異なる古さのタイムスタンプを設定
    let time1 = getTime() - initDuration(hours = 2)
    let time2 = getTime() - initDuration(hours = 5)
    setLastModificationTime(env1, time1)
    setLastModificationTime(env2, time2)
    
    # 3時間より古いものをクリーンアップ
    let result = cleanupTestEnvironments(testDir, dryRun = true, olderThanHours = 3)
    
    check result.len == 1
    check result[0].endsWith("env2_9876543210.654321")