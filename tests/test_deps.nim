import std/[unittest, os, tables, sequtils, osproc, strutils, json, times]
import ../src/deps
import ./testutils

suite "Dependency Management Tests":
  setup:
    prepareTestDirectory()
    
    # 基本的な.nimbleファイルを作成
    writeFile("test_project.nimble", """
# Package
version       = "0.1.0"
author        = "Test Author"
description   = "Test package"
license       = "MIT"

# Dependencies
requires "nim >= 1.6.0"
""")
    
    # 環境を初期化
    discard execCmdEx(niuvBin & " init")
  
  teardown:
    cleanupTestDirectory()
  
  test "Parse nimble file with various dependency formats":
    # さまざまな形式の依存関係を含む.nimbleファイルを作成
    writeFile("complex.nimble", """
# Package
version       = "0.1.0"
author        = "Test Author"
description   = "Test package"
license       = "MIT"

# Dependencies
requires "nim >= 1.6.0"
requires "httpclient"
requires "jester >= 0.5.0"
requires "unittest2" # dev
requires "docopt@0.6.8"
requires "asynctools" # dev
requires "db_connector < 0.1.0"

task test, "Run tests":
  requires "testament"
  echo "Running tests"
""")
    
    # .nimbleファイルの解析
    let packages = parseNimbleFile("complex.nimble")
    
    # パッケージ数の確認 (complex.nimbleには7つのrequires文がある)
    check packages.len == 7
    
    # 各パッケージの内容を確認
    check:
      packages[0].name == "nim"
      packages[0].version == ">= 1.6.0"
      packages[0].isDev == false
      
      packages[1].name == "httpclient"
      packages[1].version == ""
      packages[1].isDev == false
      
      packages[2].name == "jester"
      packages[2].version == ">= 0.5.0"
      packages[2].isDev == false
      
      packages[3].name == "unittest2"
      packages[3].version == ""
      packages[3].isDev == true
      
      packages[4].name == "docopt"
      packages[4].version == "@0.6.8"
      packages[4].isDev == false
      
      packages[5].name == "asynctools"
      packages[5].version == ""
      packages[5].isDev == true
      
      # タスク内の依存関係は無視されるはず
      not packages.anyIt(it.name == "testament")
  
  test "Add package to nimble file":
    # 一意なプロジェクト名を使用
    let projectName = "test_project_" & $epochTime()
    writeFile(projectName & ".nimble", """
# Package
version       = "0.1.0"
author        = "Test Author"
description   = "Test package"
license       = "MIT"

# Dependencies
requires "nim >= 1.6.0"
""")

    # パッケージを追加
    discard addPackage("jester", "", false, true)

    # .nimbleファイルの内容を確認 - ファイルを読み直す
    var content = readFile(projectName & ".nimble")
    check:
      strutils.contains(content, "requires \"jester\"")
      not content.contains("requires \"jester\" # dev")

    # パッケージを開発用依存として追加
    discard addPackage("unittest2", "", true, true)

    # .nimbleファイルの内容を再確認 - ファイルを読み直す
    content = readFile(projectName & ".nimble")
    check:
      strutils.contains(content, "requires \"unittest2\" # dev")
    
    # クリーンアップ
    removeFile(projectName & ".nimble")
  
  test "Add package with version constraint":
    # バージョン制約付きでパッケージを追加
    discard addPackage("jester", ">= 0.5.0", false, true)
    
    # .nimbleファイルの内容を確認
    let content = readFile("test_project.nimble")
    check content.contains("requires \"jester >= 0.5.0\"")
  
  test "Remove package from nimble file":
    # まずパッケージを追加
    discard addPackage("jester", "", false, true)
    discard addPackage("unittest2", "", true, true)
    
    # .nimbleファイルの内容を確認
    var content = readFile("test_project.nimble")
    check:
      content.contains("requires \"jester\"")
      content.contains("requires \"unittest2\" # dev")
    
    # パッケージを削除
    discard removePackage("jester", true)
    
    # .nimbleファイルの内容を再確認
    content = readFile("test_project.nimble")
    check:
      not content.contains("requires \"jester\"")
      content.contains("requires \"unittest2\" # dev")
    
    # 別のパッケージも削除
    discard removePackage("unittest2", true)
    
    # .nimbleファイルの内容を再確認
    content = readFile("test_project.nimble")
    check not content.contains("requires \"unittest2\" # dev")
  
  test "Get package information":
    # 既知のパッケージの情報を取得
    let info: JsonNode = getPackageInfo("jester")
    
    # 基本的な情報が含まれていることを確認
    check:
      info != nil
      info != nil and info.hasKey("name")
      info["name"].kind == JString
      info["name"].getStr() == "jester"
      info.hasKey("version")
      info["version"].kind == JString
      info["version"].getStr().len > 0
