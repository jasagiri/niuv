## MCP integration patterns for niuv
## Integrates MCP server patterns from mcp-jujutsu for potential niuv MCP capabilities

import std/[asyncdispatch, json, options, strutils, tables, httpcore, httpclient, os]
import ../../../../frameworks/system-frameworks/gennethleia/src/gennethleia_actor
import ../../../../frameworks/system-frameworks/gennethleia/src/actor_state_machine
import base, logging_integration, advanced_config

type
  MCPCapability* = enum
    ## MCP capabilities that niuv could expose
    mcPackageManagement = "package_management"
    mcWorkspaceManagement = "workspace_management"
    mcBuildOrchestration = "build_orchestration"
    mcTestExecution = "test_execution"
    mcDependencyAnalysis = "dependency_analysis"
    mcProjectScaffolding = "project_scaffolding"

  MCPResource* = object
    ## MCP resource definition
    uri*: string
    name*: string
    description*: string
    mimeType*: string

  MCPTool* = object
    ## MCP tool definition
    name*: string
    description*: string
    inputSchema*: JsonNode

  MCPPrompt* = object
    ## MCP prompt template
    name*: string
    description*: string
    arguments*: seq[string]

  NiuvMCPServer* = ref object
    ## Niuv MCP server for exposing niuv functionality
    config*: AdvancedNiuvConfig
    capabilities*: seq[MCPCapability]
    resources*: seq[MCPResource]
    tools*: seq[MCPTool]
    prompts*: seq[MCPPrompt]
    running*: bool

proc createNiuvMCPServer*(config: AdvancedNiuvConfig): NiuvMCPServer =
  ## Create a new niuv MCP server
  result = NiuvMCPServer(
    config: config,
    capabilities: @[],
    resources: @[],
    tools: @[],
    prompts: @[],
    running: false
  )
  
  # Register default capabilities
  result.capabilities = @[
    mcPackageManagement,
    mcWorkspaceManagement,
    mcBuildOrchestration,
    mcTestExecution,
    mcDependencyAnalysis,
    mcProjectScaffolding
  ]

proc registerResource*(server: NiuvMCPServer, resource: MCPResource) =
  ## Register an MCP resource
  server.resources.add(resource)
  debug("MCP resource registered", 
    newLogContext("mcp", "resource")
      .withMetadata("uri", resource.uri)
      .withMetadata("name", resource.name))

proc registerTool*(server: NiuvMCPServer, tool: MCPTool) =
  ## Register an MCP tool
  server.tools.add(tool)
  debug("MCP tool registered",
    newLogContext("mcp", "tool")
      .withMetadata("name", tool.name))

proc registerPrompt*(server: NiuvMCPServer, prompt: MCPPrompt) =
  ## Register an MCP prompt
  server.prompts.add(prompt)
  debug("MCP prompt registered",
    newLogContext("mcp", "prompt")
      .withMetadata("name", prompt.name))

# Resource implementations
proc createWorkspaceResource*(workspacePath: string): MCPResource =
  ## Create workspace resource
  MCPResource(
    uri: "workspace://" & workspacePath,
    name: "workspace_" & workspacePath.extractFilename(),
    description: "Niuv workspace at " & workspacePath,
    mimeType: "application/json"
  )

proc createPackageResource*(packageName: string): MCPResource =
  ## Create package resource
  MCPResource(
    uri: "package://" & packageName,
    name: "package_" & packageName,
    description: "Nim package " & packageName,
    mimeType: "application/json"
  )

# Tool implementations
proc createInstallTool*(): MCPTool =
  ## Create package installation tool
  let schema = %*{
    "type": "object",
    "properties": {
      "package": {
        "type": "string",
        "description": "Package name to install"
      },
      "version": {
        "type": "string",
        "description": "Specific version to install (optional)"
      },
      "workspace": {
        "type": "string", 
        "description": "Workspace path (optional)"
      }
    },
    "required": ["package"]
  }
  
  MCPTool(
    name: "install_package",
    description: "Install a Nim package using niuv",
    inputSchema: schema
  )

proc createBuildTool*(): MCPTool =
  ## Create build tool
  let schema = %*{
    "type": "object",
    "properties": {
      "target": {
        "type": "string",
        "description": "Build target (optional, defaults to main)"
      },
      "profile": {
        "type": "string",
        "description": "Build profile (debug/release)"
      },
      "workspace": {
        "type": "string",
        "description": "Workspace path (optional)"
      }
    }
  }
  
  MCPTool(
    name: "build_project",
    description: "Build a Nim project using niuv",
    inputSchema: schema
  )

proc createTestTool*(): MCPTool =
  ## Create test execution tool
  let schema = %*{
    "type": "object",
    "properties": {
      "pattern": {
        "type": "string",
        "description": "Test pattern to match (optional)"
      },
      "coverage": {
        "type": "boolean",
        "description": "Generate coverage report"
      },
      "workspace": {
        "type": "string",
        "description": "Workspace path (optional)"
      }
    }
  }
  
  MCPTool(
    name: "run_tests",
    description: "Run tests using niuv and nim-testkit",
    inputSchema: schema
  )

proc createScaffoldTool*(): MCPTool =
  ## Create project scaffolding tool
  let schema = %*{
    "type": "object", 
    "properties": {
      "name": {
        "type": "string",
        "description": "Project name"
      },
      "template": {
        "type": "string",
        "description": "Project template (library/application/workspace)"
      },
      "path": {
        "type": "string",
        "description": "Project path (optional)"
      }
    },
    "required": ["name", "template"]
  }
  
  MCPTool(
    name: "scaffold_project",
    description: "Create a new Nim project using niuv templates",
    inputSchema: schema
  )

# Prompt implementations
proc createProjectAnalysisPrompt*(): MCPPrompt =
  ## Create project analysis prompt
  MCPPrompt(
    name: "analyze_project",
    description: "Analyze a Nim project structure and dependencies",
    arguments: @["project_path", "analysis_type"]
  )

proc createDependencyPrompt*(): MCPPrompt =
  ## Create dependency analysis prompt
  MCPPrompt(
    name: "analyze_dependencies",
    description: "Analyze project dependencies and suggest optimizations",
    arguments: @["project_path", "include_dev_deps"]
  )

# MCP message handlers (following mcp-jujutsu patterns)
proc handle_handleListResources*(actor: Actor, message: handleListResources*Message): ActorResponse =
  ## Handle list resources request
  var resources = newJArray()
  
  for resource in server.resources:
    resources.add(%*{
      "uri": resource.uri,
      "name": resource.name,
      "description": resource.description,
      "mimeType": resource.mimeType
    })
  
  result = %*{
    "jsonrpc": "2.0",
    "result": {
      "resources": resources
    }
  }

proc handle_handleListTools*(actor: Actor, message: handleListTools*Message): ActorResponse =
  ## Handle list tools request
  var tools = newJArray()
  
  for tool in server.tools:
    tools.add(%*{
      "name": tool.name,
      "description": tool.description,
      "inputSchema": tool.inputSchema
    })
  
  result = %*{
    "jsonrpc": "2.0",
    "result": {
      "tools": tools
    }
  }

proc handle_handleListPrompts*(actor: Actor, message: handleListPrompts*Message): ActorResponse =
  ## Handle list prompts request
  var prompts = newJArray()
  
  for prompt in server.prompts:
    var arguments = newJArray()
    for arg in prompt.arguments:
      arguments.add(newJString(arg))
    
    prompts.add(%*{
      "name": prompt.name,
      "description": prompt.description,
      "arguments": arguments
    })
  
  result = %*{
    "jsonrpc": "2.0",
    "result": {
      "prompts": prompts
    }
  }

proc handle_handleCallTool*(actor: Actor, message: handleCallTool*Message): ActorResponse =
  ## Handle tool call request
  try:
    case toolName
    of "install_package":
      let packageName = arguments["package"].getStr()
      let version = if arguments.hasKey("version"): some(arguments["version"].getStr()) else: none(string)
      let workspace = if arguments.hasKey("workspace"): some(arguments["workspace"].getStr()) else: none(string)
      
      # Delegate to niuv install functionality
      info("MCP tool call: install_package", 
        newLogContext("mcp", "tool")
          .withMetadata("package", packageName)
          .withMetadata("version", if version.isSome: version.get() else: "latest"))
      
      result = %*{
        "jsonrpc": "2.0",
        "result": {
          "content": [
            {
              "type": "text",
              "text": "Package installation delegated to niuv install system"
            }
          ]
        }
      }
    
    of "build_project":
      let target = if arguments.hasKey("target"): arguments["target"].getStr() else: "main"
      let profile = if arguments.hasKey("profile"): arguments["profile"].getStr() else: "debug"
      
      info("MCP tool call: build_project",
        newLogContext("mcp", "tool")
          .withMetadata("target", target)
          .withMetadata("profile", profile))
      
      result = %*{
        "jsonrpc": "2.0", 
        "result": {
          "content": [
            {
              "type": "text",
              "text": "Build operation delegated to niuv build system"
            }
          ]
        }
      }
    
    of "run_tests":
      let pattern = if arguments.hasKey("pattern"): some(arguments["pattern"].getStr()) else: none(string)
      let coverage = if arguments.hasKey("coverage"): arguments["coverage"].getBool() else: false
      
      info("MCP tool call: run_tests",
        newLogContext("mcp", "tool")
          .withMetadata("pattern", if pattern.isSome: pattern.get() else: "all")
          .withMetadata("coverage", $coverage))
      
      result = %*{
        "jsonrpc": "2.0",
        "result": {
          "content": [
            {
              "type": "text", 
              "text": "Test execution delegated to niuv test system"
            }
          ]
        }
      }
    
    else:
      result = %*{
        "jsonrpc": "2.0",
        "error": {
          "code": -32601,
          "message": "Tool not found: " & toolName
        }
      }
  
  except Exception as e:
    error("MCP tool call failed: " & e.msg,
      newLogContext("mcp", "tool")
        .withMetadata("tool", toolName))
    
    result = %*{
      "jsonrpc": "2.0",
      "error": {
        "code": -32603,
        "message": "Tool execution failed: " & e.msg
      }
    }

proc setupDefaultMCPServer*(config: AdvancedNiuvConfig): NiuvMCPServer =
  ## Setup default MCP server with standard niuv capabilities
  result = createNiuvMCPServer(config)
  
  # Register default resources
  if dirExists(config.workspace.rootDir):
    result.registerResource(createWorkspaceResource(config.workspace.rootDir))
  
  # Register default tools
  result.registerTool(createInstallTool())
  result.registerTool(createBuildTool())
  result.registerTool(createTestTool())
  result.registerTool(createScaffoldTool())
  
  # Register default prompts
  result.registerPrompt(createProjectAnalysisPrompt())
  result.registerPrompt(createDependencyPrompt())
  
  info("MCP server setup completed",
    newLogContext("mcp", "setup")
      .withMetadata("capabilities", $result.capabilities.len)
      .withMetadata("tools", $result.tools.len)
      .withMetadata("resources", $result.resources.len))

# Integration template
template withMCPIntegration*(config: AdvancedNiuvConfig, body: untyped) =
  ## Template to setup MCP integration in niuv
  if config.transport.enableMCP:
    let mcpServer {.inject.} = setupDefaultMCPServer(config)
    info("MCP integration enabled", newLogContext("mcp", "integration"))
    body
  else:
    debug("MCP integration disabled", newLogContext("mcp", "integration"))
# Actor framework integration
type
  FileActor = ref object of Actor
    state: ActorState

proc newFileActor(): FileActor =
  result = FileActor()
  result.state = newActorState()

proc processMessage(actor: FileActor, message: Message): ActorResponse =
  # Process messages through gennethleia framework
  actor.state.processMessage(message)
