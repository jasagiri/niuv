# MCP-Jujutsu Integration Plan for niuv

## Overview

This document outlines how niuv can leverage and integrate patterns from mcp-jujutsu to enhance its functionality as a nimble replacement.

## Key Patterns to Integrate

### 1. Configuration Management

**From mcp-jujutsu:**
- TOML-based configuration with validation
- Environment variable overrides
- Profile-based configuration (single/multi mode)

**Apply to niuv:**
```nim
# src/config/enhanced_config.nim
type
  NiuvProfile* = enum
    npDevelopment = "development"
    npStaging = "staging" 
    npProduction = "production"
    
  NiuvConfig* = object
    profile*: NiuvProfile
    buildConfig*: BuildConfig
    testConfig*: TestConfig
    vcsConfig*: VcsConfig
```

### 2. Performance Optimization

**From mcp-jujutsu:**
- LRU caching for expensive operations
- Performance profiling
- Async operations with proper error handling

**Apply to niuv:**
```nim
# src/performance/cache.nim
var
  dependencyCache* = initLRUCache[string, DependencyInfo](maxSize = 200)
  buildCache* = initLRUCache[string, BuildResult](maxSize = 50)
  testCache* = initLRUCache[string, TestResult](maxSize = 100)
```

### 3. Structured Logging

**From mcp-jujutsu:**
- Configurable log levels
- Structured JSON logging
- Context-aware logging

**Apply to niuv:**
```nim
# src/logging/niuv_logger.nim
proc logOperation*(operation: string, context: JsonNode, level: LogLevel)
proc logBuildResult*(project: string, success: bool, duration: Duration)
proc logTestResults*(results: TestSuite, coverage: float)
```

### 4. Testing Framework Integration

**From mcp-jujutsu:**
- Comprehensive test coverage (95%+)
- Integration tests with external tools
- MECE test organization

**Apply to niuv:**
- Use nim-testkit as the primary testing framework
- Implement similar test structure as mcp-jujutsu
- Add integration tests for nimble compatibility

### 5. CI/CD Pipeline

**From mcp-jujutsu:**
- Multi-platform GitHub Actions workflows
- Automated testing and release
- Docker support

**Apply to niuv:**
- Adapt mcp-jujutsu's CI/CD templates
- Add nimble ecosystem specific tests
- Include dependency compatibility checks

## Implementation Plan

### Phase 1: Core Infrastructure

1. **Enhanced Configuration System**
   ```bash
   # Copy and adapt configuration patterns
   cp mcp-jujutsu/src/core/config/ niuv/src/config/enhanced/
   ```

2. **Performance Framework**
   ```bash
   # Adapt performance monitoring
   cp mcp-jujutsu/src/core/performance/ niuv/src/performance/
   ```

3. **Logging Infrastructure**
   ```bash
   # Enhanced logging system
   cp mcp-jujutsu/src/core/logging/ niuv/src/logging/enhanced/
   ```

### Phase 2: Testing Integration

1. **Test Framework Setup**
   - Migrate to nim-testkit as primary framework
   - Implement MECE test organization
   - Add comprehensive coverage tracking

2. **Integration Tests**
   - Nimble compatibility tests
   - Package manager integration tests
   - Multi-project workspace tests

### Phase 3: Advanced Features

1. **Multi-Project Management**
   - Adapt mcp-jujutsu's multi-repository patterns
   - Implement workspace-level operations
   - Cross-project dependency analysis

2. **Plugin Architecture**
   - Extensible command system
   - Custom task definitions
   - Third-party integrations

## Specific Adaptations

### Configuration Files

**mcp-jujutsu pattern:**
```toml
[server]
mode = "single"
port = 8080

[analysis]
max_depth = 5
cache_ttl = 300
```

**niuv adaptation:**
```toml
[build]
mode = "project"     # project, workspace
profile = "development"

[dependencies] 
cache_ttl = 300
parallel_jobs = 4

[testing]
framework = "nim-testkit"
coverage_threshold = 80.0
```

### Command Structure

**mcp-jujutsu pattern:**
```nim
# Single/multi mode selection
if config.serverMode == smMulti:
  startMultiRepoServer()
else:
  startSingleRepoServer()
```

**niuv adaptation:**
```nim
# Project/workspace mode selection
if config.buildMode == bmWorkspace:
  handleWorkspaceCommand()
else:
  handleProjectCommand()
```

### Error Handling

**mcp-jujutsu pattern:**
```nim
try:
  result = await operation()
except OperationError as e:
  logError("Operation failed", context = %*{"error": e.msg})
  return failure(e.msg)
```

**niuv adaptation:**
```nim
try:
  result = await buildOperation()
except BuildError as e:
  logBuildError(project, e.msg, %*{"command": cmd})
  return BuildResult(success: false, error: e.msg)
```

## Benefits of Integration

1. **Proven Patterns**: mcp-jujutsu has 95%+ test coverage and robust architecture
2. **Performance**: Built-in caching and profiling capabilities
3. **Maintainability**: Structured logging and error handling
4. **Scalability**: Multi-project/workspace support patterns
5. **Quality**: Comprehensive testing and CI/CD workflows

## Migration Strategy

### 1. Gradual Integration
- Start with performance and logging frameworks
- Maintain backward compatibility
- Progressive enhancement of features

### 2. Testing Strategy
- Parallel test implementation during migration
- Comprehensive integration testing
- Performance benchmarking

### 3. Documentation
- Adapt mcp-jujutsu's documentation patterns
- API reference generation
- Configuration guides

## Implementation Timeline

### Week 1-2: Infrastructure
- Performance framework integration
- Enhanced logging system
- Configuration system upgrade

### Week 3-4: Testing
- nim-testkit integration
- Test structure migration
- Coverage improvement

### Week 5-6: Advanced Features
- Multi-project support
- Workspace management
- Plugin architecture

### Week 7-8: Polish
- Documentation update
- CI/CD pipeline
- Performance optimization

This integration plan leverages mcp-jujutsu's mature patterns while adapting them specifically for niuv's role as a nimble replacement.