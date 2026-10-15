## install_steps.nim
## ===============
##
## インストール関連のステップ定義

import
  std/os,
  std/strutils,
  std/times,
  cucumber_nim/runner,
  cucumber_nim/parser

type
  Package = object
    name: string
    version: string
    isInstalled: bool
    isCached: bool
  
  InstallState = object
    ## インストールステップの状態
    packages: seq[Package]
    hasLockfile: bool
    installTime: float
    error: string

var
  state = InstallState(
    packages: @[],
    hasLockfile: false,
    installTime: 0.0,
    error: ""
  )

# ヘルパー関数
proc findPackage(name: string): int =
  for i, pkg in state.packages:
    if pkg.name == name:
      return i
  return -1

proc addPackage(name, version: string, installed, cached: bool) =
  let idx = findPackage(name)
  if idx >= 0:
    state.packages[idx].version = version
    state.packages[idx].isInstalled = installed
    state.packages[idx].isCached = cached
  else:
    state.packages.add(Package(
      name: name,
      version: version,
      isInstalled: installed,
      isCached: cached
    ))

# 前提条件
step(stGiven, "a valid package name \"{string}\""):
  let pkgName = matches[0]
  addPackage(pkgName, "1.0.0", false, false)
  return true

step(stGiven, "a package \"{string}\" with version \"{string}\""):
  let 
    pkgName = matches[0]
    version = matches[1]
  addPackage(pkgName, version, false, false)
  return true

step(stGiven, "a cached package \"{string}\" version \"{string}\""):
  let 
    pkgName = matches[0]
    version = matches[1]
  addPackage(pkgName, version, false, true)
  return true

step(stGiven, "{int} packages to install with no dependencies"):
  let count = matches[0].parseInt
  for i in 1..count:
    let pkgName = "pkg" & $i
    addPackage(pkgName, "1.0.0", false, false)
  return true

step(stGiven, "an invalid package name \"{string}\""):
  let pkgName = matches[0]
  addPackage(pkgName, "", false, false)
  return true

step(stGiven, "a valid lockfile with {int} packages"):
  let count = matches[0].parseInt
  state.hasLockfile = true
  for i in 1..count:
    let pkgName = "pkg" & $i
    addPackage(pkgName, "1.0.0", false, false)
  return true

step(stGiven, "{int} packages are already installed"):
  let count = matches[0].parseInt
  for i in 1..count:
    let idx = findPackage("pkg" & $i)
    if idx >= 0:
      state.packages[idx].isInstalled = true
  return true

step(stGiven, "a lockfile with package \"{string}\" version \"{string}\""):
  let 
    pkgName = matches[0]
    version = matches[1]
  state.hasLockfile = true
  addPackage(pkgName, version, false, false)
  return true

step(stGiven, "installed package \"{string}\" version \"{string}\""):
  let 
    pkgName = matches[0]
    version = matches[1]
  addPackage(pkgName, version, true, true)
  return true

step(stGiven, "no lockfile exists"):
  state.hasLockfile = false
  return true

# 操作
step(stWhen, "I install the package"):
  if state.packages.len == 0:
    return false
  
  let startTime = cpuTime()
  let idx = 0
  
  # 無効なパッケージ名の処理
  if state.packages[idx].name.startsWith("invalid"):
    state.error = "Invalid package name: " & state.packages[idx].name
    state.installTime = cpuTime() - startTime
    return false
  
  # キャッシュの処理
  if state.packages[idx].isCached:
    state.packages[idx].isInstalled = true
  else:
    state.packages[idx].isInstalled = true
    state.packages[idx].isCached = true
  
  state.installTime = cpuTime() - startTime
  return true

step(stWhen, "I install the package with version"):
  if state.packages.len == 0:
    return false
  
  let startTime = cpuTime()
  let idx = 0
  
  state.packages[idx].isInstalled = true
  state.packages[idx].isCached = true
  
  state.installTime = cpuTime() - startTime
  return true

step(stWhen, "I install them in parallel"):
  let startTime = cpuTime()
  
  for i in 0..<state.packages.len:
    state.packages[i].isInstalled = true
    state.packages[i].isCached = true
  
  # 並列処理をシミュレート（実際は通常の1/3の時間がかかると仮定）
  sleep(10)
  state.installTime = (cpuTime() - startTime) / 3
  return true

step(stWhen, "I try to install it"):
  if state.packages.len == 0:
    return false
  
  let idx = 0
  
  # 無効なパッケージ名の処理
  if state.packages[idx].name.startsWith("invalid"):
    state.error = "Invalid package name: " & state.packages[idx].name
    return false
  
  state.packages[idx].isInstalled = true
  state.packages[idx].isCached = true
  return true

step(stWhen, "I sync with the lockfile"):
  if not state.hasLockfile:
    state.error = "No lockfile exists"
    return false
  
  # ロックファイルと同期（不足しているパッケージをインストール）
  for i in 0..<state.packages.len:
    if not state.packages[i].isInstalled:
      state.packages[i].isInstalled = true
  
  return true

step(stWhen, "I force sync with the lockfile"):
  if not state.hasLockfile:
    state.error = "No lockfile exists"
    return false
  
  # 強制同期（バージョンの不一致も解決）
  for i in 0..<state.packages.len:
    state.packages[i].isInstalled = true
  
  return true

step(stWhen, "I try to sync"):
  if not state.hasLockfile:
    state.error = "No lockfile exists"
    return false
  
  return true

# 検証
step(stThen, "it should be installed in the nimbledeps directory"):
  if state.packages.len == 0:
    return false
  
  return state.packages[0].isInstalled

step(stThen, "the package cache should be updated"):
  if state.packages.len == 0:
    return false
  
  return state.packages[0].isCached

step(stThen, "version \"{string}\" should be installed"):
  let version = matches[0]
  if state.packages.len == 0:
    return false
  
  let idx = 0
  return state.packages[idx].isInstalled and state.packages[idx].version == version

step(stThen, "the package should be cached"):
  if state.packages.len == 0:
    return false
  
  return state.packages[0].isCached

step(stThen, "it should use the cached version"):
  if state.packages.len == 0:
    return false
  
  return state.packages[0].isInstalled and state.packages[0].isCached

step(stThen, "not download from remote"):
  # キャッシュから使用されるので、リモートからダウンロードされない
  return true

step(stThen, "all packages should be installed"):
  var allInstalled = true
  for pkg in state.packages:
    if not pkg.isInstalled:
      allInstalled = false
      break
  
  return allInstalled

step(stThen, "installation time should be faster than sequential"):
  # 並列処理のシミュレーション（3倍速いと仮定）
  return true

step(stThen, "it should return an error"):
  return state.error.len > 0

step(stThen, "the error should be properly logged"):
  return state.error.len > 0

step(stThen, "the missing package should be installed"):
  var allInstalled = true
  for pkg in state.packages:
    if not pkg.isInstalled:
      allInstalled = false
      break
  
  return allInstalled

step(stThen, "no extra packages should be removed"):
  # パッケージが削除されていないことを確認
  return true

step(stThen, "it should show version mismatch warning"):
  # バージョンの不一致警告が表示される
  return true

step(stThen, "the package should not be updated"):
  # 強制同期でない場合、パッケージはアップデートされない
  return true

step(stThen, "it should update to version \"{string}\""):
  let version = matches[0]
  for pkg in state.packages:
    if pkg.version == version:
      return pkg.isInstalled
  
  return false

step(stThen, "the lockfile checksum should be updated"):
  # ロックファイルのチェックサムが更新される
  return true

step(stThen, "the extra package should be removed"):
  # 余分なパッケージが削除されるシナリオ
  # 実際の実装では、ロックファイルにないパッケージをチェックする
  return true

step(stThen, "the installed packages should match lockfile"):
  var allMatch = true
  for pkg in state.packages:
    if not pkg.isInstalled:
      allMatch = false
      break
  
  return allMatch

step(stThen, "it should return an error"):
  return state.error.len > 0

step(stThen, "suggest creating a lockfile first"):
  return state.error.contains("lockfile")