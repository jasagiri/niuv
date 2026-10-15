import std/unittest

import std/[unittest, os, strutils, tables, json, tempfiles, sequtils]
import ../src/venv
import ../src/config
import ../src/utils
import ./testutils

suite "Venv Management Tests":
  setup:
    # テストモードを設定
    putEnv("NIUV_TEST_MODE", "1")
    let testDir = getTempDir() / "niuv_test_venv" & $getCurrentProcessId()
    putEnv("NIUV_TEST_HOME", testDir)
    createDir(testDir)
    setCurrentDir(testDir)

  teardown:
    # クリーンアップ
    let testDir = getEnv("NIUV_TEST_HOME")
    if dirExists(testDir):
      removeDir(testDir)
    delEnv("NIUV_TEST_MODE")
    delEnv("NIUV_TEST_HOME")

  test "Get venv path":
    let path = getVenvPath("myenv")
    check path.endsWith("myenv")
    check path.contains(".niuv/venvs") or path.contains("niuv_test")

  test "Create venv - basic":
    let venv = createVenv("testenv", "2.2.4")
    check venv.name == "testenv"
    check venv.nimVersion == "2.2.4"
    check venv.packages.len == 0
    check dirExists(venv.path)

  test "Create venv - empty name error":
    expect VenvError:
      discard createVenv("", "2.2.4")

  test "Create venv - duplicate error":
    discard createVenv("dupenv", "2.2.4")
    expect VenvError:
      discard createVenv("dupenv", "2.2.4")

  test "Create venv - default version":
    let venv = createVenv("defaultenv")
    check venv.nimVersion == "2.2.4"  # Default version

  test "List venvs - empty":
    let venvs = listVenvs()
    check venvs.len == 0

  test "List venvs - with environments":
    discard createVenv("env1", "2.2.0")
    discard createVenv("env2", "2.2.4")
    let venvs = listVenvs()
    check venvs.len == 2
    check venvs.anyIt(it.name == "env1")
    check venvs.anyIt(it.name == "env2")

  test "Delete venv":
    discard createVenv("todelete", "2.2.4")
    deleteVenv("todelete")
    let venvs = listVenvs()
    check not venvs.anyIt(it.name == "todelete")

  test "Delete venv - non-existent":
    expect VenvError:
      deleteVenv("nonexistent")

  test "Activate venv":
    discard createVenv("toactivate", "2.2.4")
    activateVenv("toactivate")
    check getEnv("NIUV_ACTIVE_VENV") == "toactivate"

  # TODO: deactivateVenv is not implemented
  # test "Deactivate venv":
  #   discard createVenv("todeactivate", "2.2.4")
  #   activateVenv("todeactivate")
  #   deactivateVenv()
  #   check getEnv("NIUV_ACTIVE_VENV") == ""

  test "Get active venv":
    check getActiveVenv().isNone
    discard createVenv("activetest", "2.2.4")
    activateVenv("activetest")
    let active = getActiveVenv()
    check active.isSome
    check active.get() == "activetest"

  test "Save and load venv info":
    var venv = createVenv("infotest", "2.2.4")
    venv.packages["chronos"] = "3.2.0"
    venv.packages["jester"] = "0.5.0"
    saveVenvInfo(venv)
    
    let loaded = loadVenvInfo("infotest")
    check loaded.name == venv.name
    check loaded.nimVersion == venv.nimVersion
    check loaded.packages.len == 2
    check loaded.packages["chronos"] == "3.2.0"
    check loaded.packages["jester"] == "0.5.0"

  test "Install package to venv":
    var venv = createVenv("pkgtest", "2.2.4")
    installPackageToVenv(venv, "results", "1.0.0")
    check venv.packages["results"] == "1.0.0"
    
    # 再読み込みして確認
    let loaded = loadVenvInfo("pkgtest")
    check loaded.packages["results"] == "1.0.0"

  test "Remove package from venv":
    var venv = createVenv("rmtest", "2.2.4")
    installPackageToVenv(venv, "toremove", "1.0.0")
    removePackageFromVenv(venv, "toremove")
    check not venv.packages.hasKey("toremove")

  test "Clone venv":
    var original = createVenv("original", "2.2.4")
    installPackageToVenv(original, "pkg1", "1.0.0")
    installPackageToVenv(original, "pkg2", "2.0.0")
    
    let cloned = cloneVenv("original", "cloned")
    check cloned.name == "cloned"
    check cloned.nimVersion == original.nimVersion
    check cloned.packages.len == original.packages.len
    check cloned.packages["pkg1"] == "1.0.0"
    check cloned.packages["pkg2"] == "2.0.0"

  test "Export venv":
    var venv = createVenv("exporttest", "2.2.4")
    installPackageToVenv(venv, "chronos", "3.2.0")
    installPackageToVenv(venv, "jester", "0.5.0")
    
    let exported = exportVenv("exporttest")
    check exported.contains("\"name\": \"exporttest\"")
    check exported.contains("\"nimVersion\": \"2.2.4\"")
    check exported.contains("\"chronos\": \"3.2.0\"")
    check exported.contains("\"jester\": \"0.5.0\"")

  test "Import venv":
    let importData = """{
      "name": "imported",
      "nimVersion": "2.2.0",
      "packages": {
        "results": "1.0.0",
        "chronos": "3.2.0"
      }
    }"""
    
    importVenv("imported", importData)
    let venv = loadVenvInfo("imported")
    check venv.name == "imported"
    check venv.nimVersion == "2.2.0"
    check venv.packages.len == 2
    check venv.packages["results"] == "1.0.0"
    check venv.packages["chronos"] == "3.2.0"

  test "Get venv size":
    discard createVenv("sizetest", "2.2.4")
    let size = getVenvSize("sizetest")
    check size > 0  # Should have some size

  test "Clean venv cache":
    var venv = createVenv("cachetest", "2.2.4")
    # Create some dummy cache files
    let cacheDir = venv.path / "nimcache"
    createDir(cacheDir)
    writeFile(cacheDir / "test.c", "dummy")
    
    cleanVenvCache("cachetest")
    check not fileExists(cacheDir / "test.c")

  test "Validate venv name":
    check validateVenvName("validname")
    check validateVenvName("valid-name")
    check validateVenvName("valid_name")
    check validateVenvName("valid123")
    
    check not validateVenvName("")
    check not validateVenvName("invalid name")  # space
    check not validateVenvName("invalid/name")  # slash
    check not validateVenvName(".")
    check not validateVenvName("..")

  test "Error handling - config error":
    # Simulate config error by setting invalid test home
    putEnv("NIUV_TEST_HOME", "/nonexistent/path/that/should/not/exist")
    expect VenvError:
      discard createVenv("errortest", "2.2.4")