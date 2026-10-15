## Structured logging integration for niuv
## Adapts logging patterns from mcp-jujutsu for delegation and operation tracking

import std/[times, strutils, tables, options, terminal, os, json]
import base

type
  LogLevel* = enum
    ## Log levels from least to most severe
    llTrace = "TRACE"
    llDebug = "DEBUG" 
    llInfo = "INFO"
    llWarning = "WARN"
    llError = "ERROR"
    llFatal = "FATAL"

  NiuvLogContext* = ref object
    ## Context information for niuv operations
    operation*: string              # Operation being performed (build, install, test, etc.)
    component*: string              # Component name (delegation, vcs, workspace, etc.)
    delegate*: Option[string]       # Which delegate is being used
    workspace*: Option[string]      # Current workspace context
    sessionId*: Option[string]      # Session ID for operation tracking
    metadata*: Table[string, string] # Additional metadata

  LogOutput* = enum
    ## Logger output targets
    loConsole   # Output to console
    loFile      # Output to file

  NiuvLogConfig* = object
    ## Configuration for niuv logger
    minLevel*: LogLevel             # Minimum level to log
    outputs*: set[LogOutput]        # Where to output logs
    showColors*: bool               # Whether to use colors in console output
    logFilePath*: string            # Path to log file
    includeTimestamp*: bool         # Whether to include timestamps
    includeContext*: bool           # Whether to include context information
    includeDelegateInfo*: bool      # Whether to include delegation info

  NiuvLogger* = ref object
    ## Main logger for niuv
    config*: NiuvLogConfig
    defaultContext*: NiuvLogContext
    logFile*: File
    initialized*: bool

# Global logger instance
var globalLogger*: NiuvLogger

proc newLogContext*(operation: string = "", component: string = ""): NiuvLogContext =
  ## Create a new log context for niuv operations
  result = NiuvLogContext(
    operation: operation,
    component: component,
    delegate: none(string),
    workspace: none(string),
    sessionId: none(string),
    metadata: initTable[string, string]()
  )

proc withDelegate*(ctx: NiuvLogContext, delegate: string): NiuvLogContext =
  ## Add delegate information to context
  result = ctx
  result.delegate = some(delegate)

proc withWorkspace*(ctx: NiuvLogContext, workspace: string): NiuvLogContext =
  ## Add workspace information to context
  result = ctx
  result.workspace = some(workspace)

proc withMetadata*(ctx: NiuvLogContext, key: string, value: string): NiuvLogContext =
  ## Add metadata to context
  result = ctx
  result.metadata[key] = value

proc withSession*(ctx: NiuvLogContext, sessionId: string): NiuvLogContext =
  ## Add session ID to context
  result = ctx
  result.sessionId = some(sessionId)

proc getLogLevelColor*(level: LogLevel): string =
  ## Get color code for log level
  case level
  of llTrace: return $fgBlue
  of llDebug: return $fgCyan
  of llInfo: return $fgGreen
  of llWarning: return $fgYellow
  of llError: return $fgRed
  of llFatal: return $fgMagenta

proc formatLogMessage*(level: LogLevel, message: string, context: NiuvLogContext, config: NiuvLogConfig): string =
  ## Format a log message with context information
  result = ""
  
  # Timestamp
  if config.includeTimestamp:
    result.add("[" & now().format("yyyy-MM-dd HH:mm:ss") & "] ")
  
  # Log level with color if enabled
  if config.showColors and loConsole in config.outputs:
    result.add(getLogLevelColor(level) & $level & $resetStyle & " ")
  else:
    result.add($level & " ")
  
  # Context information
  if config.includeContext:
    var contextParts: seq[string] = @[]
    
    if context.operation != "":
      contextParts.add("op:" & context.operation)
    
    if context.component != "":
      contextParts.add("comp:" & context.component)
    
    if config.includeDelegateInfo and context.delegate.isSome:
      contextParts.add("delegate:" & context.delegate.get())
    
    if context.workspace.isSome:
      contextParts.add("ws:" & context.workspace.get())
    
    if context.sessionId.isSome:
      contextParts.add("session:" & context.sessionId.get())
    
    if contextParts.len > 0:
      result.add("[" & contextParts.join("|") & "] ")
  
  # Main message
  result.add(message)
  
  # Metadata
  if config.includeContext and context.metadata.len > 0:
    var metaParts: seq[string] = @[]
    for key, value in context.metadata:
      metaParts.add(key & "=" & value)
    result.add(" {" & metaParts.join(", ") & "}")

proc initLogger*(config: NiuvLogConfig): NiuvLogger =
  ## Initialize the niuv logger
  result = NiuvLogger(
    config: config,
    defaultContext: newLogContext("system", "logger"),
    initialized: false
  )
  
  # Open log file if file output is enabled
  if loFile in config.outputs:
    try:
      result.logFile = open(config.logFilePath, fmAppend)
      result.initialized = true
    except IOError:
      echo "Warning: Could not open log file " & config.logFilePath
      result.config.outputs.excl(loFile)
      result.initialized = true
  else:
    result.initialized = true

proc log*(logger: NiuvLogger, level: LogLevel, message: string, context: NiuvLogContext = nil) =
  ## Log a message with the given level and context
  if not logger.initialized:
    return
  
  if level < logger.config.minLevel:
    return
  
  let actualContext = if context != nil: context else: logger.defaultContext
  let formattedMessage = formatLogMessage(level, message, actualContext, logger.config)
  
  # Output to console
  if loConsole in logger.config.outputs:
    echo formattedMessage
  
  # Output to file
  if loFile in logger.config.outputs and logger.logFile != nil:
    try:
      logger.logFile.writeLine(formattedMessage)
      logger.logFile.flushFile()
    except IOError:
      # Fall back to console if file writing fails
      echo "Log file error: " & formattedMessage

# Convenience logging procedures
proc trace*(message: string, context: NiuvLogContext = nil) =
  if globalLogger != nil:
    globalLogger.log(llTrace, message, context)

proc debug*(message: string, context: NiuvLogContext = nil) =
  if globalLogger != nil:
    globalLogger.log(llDebug, message, context)

proc info*(message: string, context: NiuvLogContext = nil) =
  if globalLogger != nil:
    globalLogger.log(llInfo, message, context)

proc warning*(message: string, context: NiuvLogContext = nil) =
  if globalLogger != nil:
    globalLogger.log(llWarning, message, context)

proc error*(message: string, context: NiuvLogContext = nil) =
  if globalLogger != nil:
    globalLogger.log(llError, message, context)

proc fatal*(message: string, context: NiuvLogContext = nil) =
  if globalLogger != nil:
    globalLogger.log(llFatal, message, context)

# Delegation-specific logging
proc logDelegateOperation*(operation: string, delegate: string, success: bool, details: string = "") =
  ## Log a delegate operation result
  let ctx = newLogContext(operation, "delegation")
    .withDelegate(delegate)
    .withMetadata("success", $success)
  
  if details != "":
    discard ctx.withMetadata("details", details)
  
  if success:
    info("Delegate operation completed", ctx)
  else:
    error("Delegate operation failed", ctx)

proc logVCSOperation*(operation: string, vcsType: string, success: bool, output: string = "") =
  ## Log a VCS operation result
  let ctx = newLogContext(operation, "vcs")
    .withDelegate(vcsType)
    .withMetadata("success", $success)
  
  if output != "":
    discard ctx.withMetadata("output_length", $output.len)
  
  if success:
    debug("VCS operation completed", ctx)
  else:
    error("VCS operation failed", ctx)

proc logWorkspaceOperation*(operation: string, workspace: string, success: bool, details: string = "") =
  ## Log a workspace operation
  let ctx = newLogContext(operation, "workspace")
    .withWorkspace(workspace)
    .withMetadata("success", $success)
  
  if details != "":
    discard ctx.withMetadata("details", details)
  
  if success:
    info("Workspace operation completed", ctx)
  else:
    error("Workspace operation failed", ctx)

# Setup procedures
proc setupDefaultLogger*(logLevel: LogLevel = llInfo, enableFileLogging: bool = false) =
  ## Setup default logger for niuv
  let config = NiuvLogConfig(
    minLevel: logLevel,
    outputs: if enableFileLogging: {loConsole, loFile} else: {loConsole},
    showColors: true,
    logFilePath: getTempDir() / "niuv.log",
    includeTimestamp: true,
    includeContext: true,
    includeDelegateInfo: true
  )
  
  globalLogger = initLogger(config)
  
  info("Niuv logger initialized", newLogContext("setup", "logger")
    .withMetadata("level", $logLevel)
    .withMetadata("file_logging", $enableFileLogging))

# Template for logging delegation operations
template withOperationLogging*(operation: string, component: string, body: untyped) =
  ## Template to wrap operations with automatic logging
  let startTime = now()
  let ctx {.inject.} = newLogContext(operation, component)
  
  debug("Starting operation", ctx)
  
  try:
    body
    let duration = now() - startTime
    info("Operation completed", ctx.withMetadata("duration_ms", $duration.inMilliseconds))
  except Exception as e:
    let duration = now() - startTime
    error("Operation failed: " & e.msg, ctx.withMetadata("duration_ms", $duration.inMilliseconds))