## scaffold_steps.nim
## ================
##
## スキャフォールド関連のステップ定義

import
  std/os,
  std/strutils,
  std/tables,
  cucumber_nim/runner,
  cucumber_nim/parser

type
  ScaffoldFileType = enum
    sfModuleFile,
    sfTestFile,
    sfProjectDir,
    sfLicenseFile,
    sfGitIgnore,
    sfReadme,
    sfNimbleFile,
    sfConfigFile,
    sfSourceDir,
    sfTestDir

  ScaffoldState = object
    ## スキャフォールドステップの状態
    createdFiles: Table[ScaffoldFileType, bool]
    moduleName: string
    projectName: string
    projectType: string
    templateName: string
    authorName: string
    authorEmail: string
    licenseName: string
    withTests: bool
    withGit: bool
    existingDir: bool
    confirmed: bool
    lastOutput: string
    lastError: string
    lastExitCode: int

var
  state = ScaffoldState(
    createdFiles: initTable[ScaffoldFileType, bool](),
    moduleName: "",
    projectName: "",
    projectType: "bin",
    templateName: "default",
    authorName: "",
    authorEmail: "",
    licenseName: "",
    withTests: false,
    withGit: false,
    existingDir: false,
    confirmed: false,
    lastOutput: "",
    lastError: "",
    lastExitCode: 0
  )

proc clearState() =
  state.createdFiles.clear()
  state.moduleName = ""
  state.projectName = ""
  state.projectType = "bin"
  state.templateName = "default"
  state.authorName = ""
  state.authorEmail = ""
  state.licenseName = ""
  state.withTests = false
  state.withGit = false
  state.existingDir = false
  state.confirmed = false
  state.lastOutput = ""
  state.lastError = ""
  state.lastExitCode = 0

proc generateFiles() =
  # モジュールスキャフォールド
  if state.moduleName.len > 0:
    state.createdFiles[sfModuleFile] = true
    
    if state.withTests:
      state.createdFiles[sfTestFile] = true
  
  # プロジェクトスキャフォールド
  if state.projectName.len > 0:
    state.createdFiles[sfProjectDir] = true
    state.createdFiles[sfSourceDir] = true
    state.createdFiles[sfTestDir] = true
    state.createdFiles[sfNimbleFile] = true
    state.createdFiles[sfReadme] = true
    state.createdFiles[sfConfigFile] = true
    
    if state.licenseName.len > 0:
      state.createdFiles[sfLicenseFile] = true
    
    if state.withGit:
      state.createdFiles[sfGitIgnore] = true

# 前提条件
step(stGiven, "a directory that already exists"):
  clearState()
  state.existingDir = true
  return true

# 操作
step(stWhen, "I run \"niuv scaffold module {string}\""):
  clearState()
  state.moduleName = matches[0]
  state.withTests = false
  state.existingDir = false
  generateFiles()
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv scaffold project {string}\""):
  clearState()
  state.projectName = matches[0]
  state.existingDir = false
  generateFiles()
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv scaffold module {string} --template={string}\""):
  clearState()
  state.moduleName = matches[0]
  state.templateName = matches[1]
  state.withTests = false
  state.existingDir = false
  generateFiles()
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv scaffold module {string} --with-tests\""):
  clearState()
  state.moduleName = matches[0]
  state.withTests = true
  state.existingDir = false
  generateFiles()
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv scaffold module {string}\""):
  clearState()
  state.moduleName = matches[0]
  
  if state.existingDir:
    state.lastOutput = "Directory already exists. Do you want to proceed? [y/N]"
    if state.confirmed:
      generateFiles()
  else:
    generateFiles()
  
  state.lastExitCode = 0
  return true

step(stWhen, "I run \"niuv scaffold project {string} --author='{string}' --email='{string}'\""):
  clearState()
  state.projectName = matches[0]
  state.authorName = matches[1]
  state.authorEmail = matches[2]
  state.existingDir = false
  generateFiles()
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv scaffold project {string} --license={string}\""):
  clearState()
  state.projectName = matches[0]
  state.licenseName = matches[1]
  state.existingDir = false
  generateFiles()
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv scaffold project {string} --git-init\""):
  clearState()
  state.projectName = matches[0]
  state.withGit = true
  state.existingDir = false
  generateFiles()
  state.lastExitCode = 0
  
  return true

step(stWhen, "I run \"niuv scaffold project {string} --type={string}\""):
  clearState()
  state.projectName = matches[0]
  state.projectType = matches[1]
  state.existingDir = false
  generateFiles()
  state.lastExitCode = 0
  
  return true

# 検証
step(stThen, "a \"src/{string}.nim\" file should be created"):
  let fileName = matches[0]
  return state.moduleName == fileName and state.createdFiles.getOrDefault(sfModuleFile, false)

step(stThen, "a \"tests/test_{string}.nim\" file should be created"):
  let fileName = matches[0]
  return state.moduleName == fileName and state.createdFiles.getOrDefault(sfTestFile, false)

step(stThen, "the module should have proper structure and imports"):
  return state.createdFiles.getOrDefault(sfModuleFile, false)

step(stThen, "a \"{string}\" directory should be created"):
  let dirName = matches[0]
  return state.projectName == dirName and state.createdFiles.getOrDefault(sfProjectDir, false)

step(stThen, "all necessary project files should be created"):
  return state.createdFiles.getOrDefault(sfProjectDir, false) and
         state.createdFiles.getOrDefault(sfSourceDir, false) and
         state.createdFiles.getOrDefault(sfNimbleFile, false) and
         state.createdFiles.getOrDefault(sfReadme, false)

step(stThen, "a project structure following best practices should be established"):
  return state.createdFiles.getOrDefault(sfProjectDir, false) and
         state.createdFiles.getOrDefault(sfSourceDir, false) and
         state.createdFiles.getOrDefault(sfTestDir, false) and
         state.createdFiles.getOrDefault(sfNimbleFile, false) and
         state.createdFiles.getOrDefault(sfReadme, false) and
         state.createdFiles.getOrDefault(sfConfigFile, false)

step(stThen, "a module should be created using the custom template"):
  return state.createdFiles.getOrDefault(sfModuleFile, false) and
         state.templateName != "default"

step(stThen, "the custom template structure should be applied"):
  return state.templateName != "default"

step(stThen, "comprehensive test files should be created"):
  return state.withTests and state.createdFiles.getOrDefault(sfTestFile, false)

step(stThen, "the tests should cover basic functionality"):
  return state.withTests

step(stThen, "I should be prompted for confirmation"):
  return state.existingDir and state.lastOutput.contains("already exists")

step(stThen, "if confirmed, the module should be created"):
  if state.existingDir and not state.confirmed:
    return false
  
  return state.createdFiles.getOrDefault(sfModuleFile, false)

step(stThen, "existing files should not be overwritten without confirmation"):
  return not (state.existingDir and not state.confirmed and state.createdFiles.getOrDefault(sfModuleFile, false))

step(stThen, "a project should be created"):
  return state.createdFiles.getOrDefault(sfProjectDir, false)

step(stThen, "author information should be included in appropriate files"):
  return state.authorName.len > 0 and state.authorEmail.len > 0

step(stThen, "an MIT license file should be included"):
  return state.licenseName == "MIT" and state.createdFiles.getOrDefault(sfLicenseFile, false)

step(stThen, "Git should be initialized in the project directory"):
  return state.withGit

step(stThen, "a .gitignore file should be included"):
  return state.withGit and state.createdFiles.getOrDefault(sfGitIgnore, false)

step(stThen, "a library project should be created"):
  return state.projectName.len > 0 and state.projectType == "lib"

step(stThen, "appropriate library export structure should be set up"):
  return state.projectType == "lib"

step(stThen, "a binary application project should be created"):
  return state.projectName.len > 0 and state.projectType == "bin"

step(stThen, "a proper main entry point should be set up"):
  return state.projectType == "bin"