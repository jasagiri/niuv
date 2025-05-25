import std/[os, strutils, terminal, times, osproc]
import ./deps, ./env, ./install, ./utils, ./cli, ./workspace, ./niuv_testing
import ./coverage, ./test_coverage

# Conditional import for testkit features
when defined(niuvTestKit):
  import ./testkit_adapter

type
  NiuvError* = object of CatchableError

proc showVersion() =
  ## バージョン情報を表示する
  const version = "0.1.0"
  styledEcho(styleBright, fgGreen, "niuv ", version, " - Nim Virtual Environment Manager")
  styledEcho("Copyright (c) ", $now().year, " Niuv Contributors")
  styledEcho("MIT License")

proc showHelp() =
  ## ヘルプメッセージを表示する
  styledEcho(styleBright, fgGreen, "niuv - Nim Virtual Environment Manager\n")
  echo """
Usage:
  niuv init [options]          Initialize a new virtual environment
  niuv install [options]       Install packages from .nimble file
  niuv add <package> [options] Add a package to dependencies and install it
  niuv remove <package>        Remove a package from dependencies
  niuv sync [options]          Synchronize installed packages with dependencies
  niuv activate                Activate the virtual environment
  niuv shell                   Start a new shell with activated environment
  niuv run <command>           Run a command in the virtual environment
  niuv info                    Show information about the current environment
  niuv setup                   Setup shell integration
  niuv generate [options]      Generate a project using scaffold template
  niuv clean                   Clean build artifacts
  niuv cleanall                Clean all artifacts including nimbledeps
  niuv workspace init          Initialize a new workspace
  niuv workspace install       Install all workspace dependencies
  niuv workspace build         Build all workspace packages
  niuv workspace test          Test all workspace packages
  niuv workspace publish       Publish workspace packages
  niuv test [subcommand]       Run tests (subcommands: run, analyze, generate, coverage)
  niuv help                    Show this help message
  niuv version                 Show version information

Options:
  --dev                      Include development dependencies
  --nim-version=<version>    Use specific Nim version
  --verbose                  Show verbose output
  --parallel=<n>             Number of parallel jobs (default: number of CPU cores)
  --cache-dir=<dir>          Custom cache directory
  --force                    Force operation even when there are warnings
  --no-lock                  Disable automatic lockfile generation
  --lockfile=<file>          Specify alternative lockfile path
  --nimble-dir=<dir>         Specify alternative Nimble directory
  --use-resolver             Use SAT solver-based dependency resolver
  --minimal-versions         Prefer minimal versions (with --use-resolver)
  --conservative-versions    Prefer currently installed versions (with --use-resolver)
  --force-resolve            Force re-resolution ignoring lockfile
  --help                     Show help message

Options for 'generate':
  --dir=<dir>                Directory to create the project in (default: project name)
  --desc=<desc>              Short description of the project
  --author=<name>            Author name for the project
  --license=<license>        License for the project (default: MIT)

Test Subcommands:
  niuv test                    Run all tests (default)
  niuv test run [files...]     Run specific test files or pattern
  niuv test analyze            Analyze test structure using MECE principles
  niuv test generate <type>    Generate test files (unit/integration/system)
  niuv test coverage           Run tests with code coverage

Examples:
  niuv test                    # Run all tests
  niuv test test_config.nim    # Run specific test file
  niuv test "test_*.nim"       # Run tests matching pattern
  niuv test analyze            # Analyze test structure
  niuv test generate unit api  # Generate unit test for api module
  niuv test coverage           # Run tests with coverage
"""

proc generateProject(args: seq[string], options: CliOptions): bool =
  ## スキャフォールドテンプレートを使用してプロジェクトを生成する
  if args.len < 1:
    cli.showError("Project name is required")
    return false

  let projectName = args[0]
  var scaffoldArgs = ""

  # Setup options
  if options.dirPath.len > 0:
    scaffoldArgs &= " --base-dir=" & options.dirPath

  # Other options
  if getEnv("NIUV_PROJECT_DESCRIPTION").len > 0:
    scaffoldArgs &= " --description=\"" & getEnv("NIUV_PROJECT_DESCRIPTION") & "\""
  elif options.description.len > 0:
    scaffoldArgs &= " --description=\"" & options.description & "\""

  if getEnv("NIUV_PROJECT_AUTHOR").len > 0:
    scaffoldArgs &= " --author=\"" & getEnv("NIUV_PROJECT_AUTHOR") & "\""
  elif options.author.len > 0:
    scaffoldArgs &= " --author=\"" & options.author & "\""

  if getEnv("NIUV_PROJECT_LICENSE").len > 0:
    scaffoldArgs &= " --license=" & getEnv("NIUV_PROJECT_LICENSE")

  # Execute scaffold tool
  let cmdLine = "nim c -r src/templates/scaffold.nim " & projectName & scaffoldArgs
  if options.verbose:
    cli.showInfo("Executing: " & cmdLine)

  try:
    let (output, exitCode) = execCmdEx(cmdLine)
    if options.verbose or exitCode != 0:
      echo output

    return exitCode == 0
  except:
    cli.showError("Failed to execute scaffold tool")
    return false

proc handleTestRun(args: seq[string], options: CliOptions): bool =
  ## Handle 'niuv test run' subcommand with minimal configuration
  var testConfig = newTestRunnerConfig()
  testConfig.verbose = options.verbose
  
  # Simple argument parsing - just files/patterns
  for arg in args:
    if arg.endsWith(".nim"):
      testConfig.testFiles.add(arg)
      testConfig.mode = trmSingle
    else:
      # Treat as pattern
      testConfig.pattern = arg
      testConfig.mode = trmPattern
  
  runAndReport(testConfig)

proc handleTestAnalyze(args: seq[string], options: CliOptions): bool =
  ## Handle 'niuv test analyze' subcommand
  when defined(niuvTestKit):
    let report = analyzeMECE()
    printMECEReport(report)
    report.isValid
  else:
    cli.showError("test analyze requires nim-testkit. Compile with -d:niuvTestKit")
    false

proc handleTestGenerate(args: seq[string], options: CliOptions): bool =
  ## Handle 'niuv test generate' subcommand
  when defined(niuvTestKit):
    if args.len < 1:
      cli.showError("Usage: niuv test generate <type> [name]")
      cli.showError("Types: unit, integration, system")
      false
    else:
      let testType = args[0]
      let testName = if args.len > 1: args[1] else: "test_" & testType
      generateTest(testType, testName, "tests")
  else:
    cli.showError("test generate requires nim-testkit. Compile with -d:niuvTestKit")
    false

proc handleTestCoverage(args: seq[string], options: CliOptions): bool =
  ## Handle 'niuv test coverage' subcommand with minimal options
  var coverageArgs: seq[string] = @[]
  
  # Pass through any arguments directly
  for arg in args:
    coverageArgs.add(arg)
  
  testWithCoverage(coverageArgs) == 0

proc detectNiuvProject(): bool =
  ## 現在のディレクトリがniuvプロジェクトかどうかを検出する
  try:
    # .nimbleファイルの検索
    var nimbleFiles: seq[string] = @[]
    for kind, path in walkDir(getCurrentDir()):
      if kind == pcFile and path.endsWith(".nimble"):
        nimbleFiles.add(path)

    if nimbleFiles.len == 0:
      return false

    # .nimbleファイルの内容を確認
    for nimbleFile in nimbleFiles:
      let content = readFile(nimbleFile)
      # niuvに関連する記述があるか確認
      if content.contains("requires \"niuv") or
         content.contains("exec \"niuv ") or
         content.contains("niuv run"):
        return true

    return false
  except:
    return false

proc main() =
  # テストモードの確認
  let isTestMode = getEnv("NIUV_TEST_MODE") == "1"

  # ヘルプの表示（引数なし）
  if paramCount() < 1:
    showHelp()
    quit(0)

  var args = commandLineParams()
  let command = args[0]

  # バージョン情報またはヘルプの表示
  if command == "version":
    showVersion()
    quit(0)
  elif command == "help":
    showHelp()
    quit(0)

  # 引数を消費
  args.delete(0)

  # コマンドラインオプションのパース
  var options = newCliOptions()
  parseOptions(args, options)

  # 出力を調整
  if options.verbose:
    utils.setupLogging(true)

  # ディレクトリの準備
  if not dirExists(getHomeDir() / ".niuv"):
    try:
      createDir(getHomeDir() / ".niuv")
      createDir(getHomeDir() / ".niuv/cache")
    except:
      if options.verbose:
        cli.showWarning("Failed to create home directory: " & getHomeDir() / ".niuv")

  # niuvプロジェクトの検出
  let isNiuvProject = detectNiuvProject()
  if isNiuvProject:
    cli.showInfo("Detected niuv project")

  # コマンド実行
  try:
    let result = case command:
      of "init":
        env.initializeEnvironment(options)

      of "install":
        install.installPackages(options)

      of "add":
        if args.len < 1:
          cli.showError("Package name is required")
          quit(1)
        let packageName = args[0]
        let version = if args.len > 1: args[1] else: ""
        deps.addPackage(packageName, version, options.includeDev, options.verbose)

      of "remove":
        if args.len < 1:
          cli.showError("Package name is required")
          quit(1)
        let packageName = args[0]
        deps.removePackage(packageName, options.verbose)

      of "sync":
        install.syncLockfile(options)

      of "activate":
        env.activateEnvironment(options.verbose)

      of "shell":
        env.startShellWithEnvironment(options.verbose)

      of "run":
        if args.len < 1:
          cli.showError("Command is required")
          quit(1)
        let cmd = args.join(" ")
        env.runInEnvironment(cmd, options.verbose)

      of "info":
        env.showEnvironmentInfo()
        true

      of "setup":
        env.setupShellIntegration()

      of "generate":
        generateProject(args, options)

      of "clean":
        utils.cleanBuildArtifacts(options.verbose)

      of "cleanall":
        utils.cleanAll(options.verbose)
      
      of "test":
        # Simplified test command with subcommands
        if args.len == 0:
          # Default to 'run' subcommand
          handleTestRun(@[], options)
        else:
          let subcommand = args[0]
          let subArgs = if args.len > 1: args[1..^1] else: @[]
          
          case subcommand
          of "run":
            handleTestRun(subArgs, options)
          of "analyze":
            handleTestAnalyze(subArgs, options)
          of "generate":
            handleTestGenerate(subArgs, options)
          of "coverage":
            handleTestCoverage(subArgs, options)
          else:
            # If not a subcommand, treat as test file/pattern for 'run'
            handleTestRun(args, options)
      
      of "workspace":
        if args.len < 1:
          cli.showError("Workspace subcommand is required")
          quit(1)
        
        let subcommand = args[0]
        case subcommand:
        of "init":
          let members = if args.len > 1: args[1..^1] else: @["packages/*"]
          createWorkspaceConfig(getCurrentDir(), members)
        
        of "install":
          let ws = loadWorkspace()
          ws.installWorkspace(options)
        
        of "build":
          let ws = loadWorkspace()
          ws.buildWorkspace(options)
        
        of "test":
          let ws = loadWorkspace()
          ws.testWorkspace(options)
        
        of "publish":
          let ws = loadWorkspace()
          ws.publishWorkspacePackages(options)
        
        else:
          cli.showError("Unknown workspace subcommand: " & subcommand)
          false

      of "help":
        showHelp()
        true

      else:
        cli.showError("Unknown command: " & command)
        showHelp()
        quit(1)

    # 結果の処理
    if not result and not isTestMode:
      cli.showError("Command failed: " & command)
      quit(1)

  except NiuvError as e:
    cli.showError(e.msg)
    quit(1)
  except IOError as e:
    cli.showError("I/O error: " & e.msg)
    if options.verbose:
      echo getStackTrace(e)
    quit(1)
  except Exception as e:
    cli.showError("Unexpected error: " & e.msg)
    if options.verbose:
      echo getStackTrace(e)
    quit(1)

when isMainModule:
  main()