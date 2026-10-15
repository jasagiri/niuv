# CLAUDE.md - Enhanced Template with PDF-Derived Best Practices

This enhanced template incorporates insights from 15+ Claude Code practice documents, structured using MECE principles and integrated with GodsGolemInc ecosystem standards.

## Project Metadata
```yaml
Project: niuv
Version: 1.0.0
Created: 2025-06-24
Last Updated: 2025-06-24
Claude Code Compatibility: v2.0+
Ecosystem Layer: {Products|Frameworks|Runtime-Services|Protocols|Business-Domains|Libraries}
Template Version: 2.1.0 (Enhanced with PDF insights)
```

## Table of Contents
1. [Project Overview](#project-overview)
2. [Development Environment](#development-environment)
3. [Architecture & Design](#architecture--design)
4. [Development Workflow](#development-workflow)
5. [Quality Standards](#quality-standards)
6. [Knowledge Management](#knowledge-management)
7. [Team Collaboration](#team-collaboration)
8. [Advanced Configuration](#advanced-configuration)

---

## 1. Project Overview

### Project Identity
- **Name**: niuv
- **Purpose**: {Brief description of what this project does}
- **Business Value**: {Why this project exists}
- **Target Users**: {Who uses this project}
- **MECE Layer**: {Which ecosystem layer this belongs to}

### Technology Stack
```toml
# Primary Technologies
language = "Nim 2.0.0+"
framework = "{Primary framework if applicable}"
database = "{Database technology}"
deployment = "{Deployment platform}"

# Key Dependencies
[dependencies]
nim-ecosystem-utils = "latest"
nim-structured-logger = "latest"
nim-testkit = "latest"
# Add project-specific dependencies

# Claude Code Optimization (PDF Insight)
[claude_settings]
memory_management = "hierarchical"  # Based on folder hierarchy guidelines
custom_commands = true              # Enable for workflow optimization
token_optimization = true          # Reduce CLAUDE.md bloat
```

### Project Structure
```
niuv/
├── src/                    # Source code
├── tests/                  # Test files (100% coverage required)
├── docs/                   # Documentation
├── config/                 # Configuration files
├── scripts/                # Build and utility scripts
├── .claude/               # Claude Code settings (PDF insight)
│   ├── commands/          # Custom commands directory
│   └── settings.json      # Project-specific settings
├── niuv.toml              # Environment configuration
└── CLAUDE.md              # This file
```

---

## 2. Development Environment

### Setup Commands
```bash
# Environment Management (Universal)
niuv init                   # Initialize virtual environment
niuv install               # Install dependencies
niuv activate              # Activate environment
niuv status                # Check environment state
niuv doctor                # Diagnose issues

# Build & Test
niuv build                 # Build project
niuv test                  # Run all tests (must achieve 100% pass rate)
niuv test --coverage       # Run with coverage analysis (must achieve 100%)
niuv test --watch          # Watch mode for TDD (PDF insight)
niuv clean                 # Clean artifacts

# Claude Code Integration (PDF Insights)
claude --memory-path ./docs  # Use project-specific memory path
claude --enable-tdd         # Always use Test-Driven Development
claude --japanese           # Always respond in Japanese if applicable
```

### Custom Commands (PDF Insight: Token Optimization)
```bash
# Create custom commands to reduce CLAUDE.md bloat
# .claude/commands/test-workflow.md
/test-workflow              # Custom command for testing workflow
/deploy-staging            # Custom command for staging deployment
/code-review              # Custom command for code review process
/documentation-update     # Custom command for doc updates
```

### File Format Standards
```yaml
# Enforced across all text files
line_endings: "LF only (\\n)"
encoding: "UTF-8"
trailing_whitespace: "remove"
final_newline: "include (single LF)"
indentation: "{spaces|tabs} - {number}"
quote_style: "double quotes"  # or single, be consistent

# Memory Management (PDF insight)
memory_hierarchy: "folder-based"  # Use folder structure for memory organization
```

---

## 3. Architecture & Design

### MECE Layer Compliance
- **Current Layer**: {Products|Frameworks|Runtime-Services|Protocols|Business-Domains|Libraries}
- **Layer Dependencies**: {List allowed dependencies}
- **Forbidden Imports**: {What this layer cannot import directly}
- **Service Communication**: {How to communicate across layers}

### Memory Architecture (PDF Insight)
```markdown
## Hierarchical Memory Structure
### Project-Level Memory (this CLAUDE.md)
- Project overview and standards
- Global development rules
- Cross-component guidelines

### Component-Level Memory (subfolder CLAUDE.md files)
- Component-specific rules
- Local implementation details
- Module-specific patterns

### Workflow Memory (.claude/commands/)
- Reusable command patterns
- Automated workflow scripts
- Custom development flows
```

### Core Design Patterns
- **Actor Model**: Uses nim-libactors with delegation pattern
- **Logging Strategy**: nim-structured-logger exclusively
- **Utility Strategy**: nim-ecosystem-utils for all common operations
- **Testing Strategy**: nim-testkit with MECE test categories + TDD
- **Configuration**: niuv.toml for all settings
- **Memory Management**: Hierarchical folder-based approach (PDF insight)

### Architecture Decisions
```markdown
## Decision Log
### {Decision Date} - Token Optimization Strategy
**Problem**: CLAUDE.md becoming too large (352+ lines causing token waste)
**Decision**: Implement custom commands for repetitive workflows
**Rationale**: Reduce token consumption by 20% while maintaining functionality
**Consequences**: Requires setup of .claude/commands/ structure
**Status**: Active

### {Decision Date} - Memory Hierarchy Implementation
**Problem**: Context management across large project structures
**Decision**: Use folder-based hierarchical memory with subfolder CLAUDE.md files
**Rationale**: Better context isolation and more targeted AI assistance
**Consequences**: Requires maintenance of multiple CLAUDE.md files
**Status**: Active
```

---

## 4. Development Workflow

### Session Management Strategy (Enhanced)
```bash
# Session Types & When to Use
# Continuous Session (same feature area):
"Feature development → Testing → Documentation → Optimization"

# New Session (different feature area):
"Authentication work DONE → NEW SESSION → Database optimization"

# Explicit CLAUDE.md Loading (recommended):
"CLAUDE.mdを読んで、このプロジェクトの設定を理解してください"

# Memory Path Specification (PDF insight):
"--memory-path docs/ を使って、プロジェクト固有のコンテキストを読み込んで"
```

### TDD Integration (PDF Insight)
```bash
# Always Test-Driven Development
"常にTDD（テスト駆動開発）でコードを書いて"
"まずテストを書いてから実装を始めて"
"Red-Green-Refactorサイクルを厳守して"

# Test-First Commands
/test-first {feature}       # Start with test creation
/tdd-cycle {component}      # Complete TDD cycle
/refactor-safe {module}     # Safe refactoring with tests
```

### Custom Workflow Commands (PDF Insight)
```bash
# Efficiency Commands (replacing repetitive CLAUDE.md sections)
/setup-component {name}     # Standard component setup
/security-review           # Security-focused code review
/performance-check         # Performance analysis workflow
/documentation-sync        # Keep docs in sync with code
/deployment-checklist      # Pre-deployment validation

# Project-Specific Workflows
/feature-complete {name}    # Mark feature as complete
/integration-test          # Run integration test suite
/compliance-check          # Verify ecosystem compliance
```

### Permission Management & Safety (PDF Insight)
```yaml
# Safety Guardrails
permission_separation: "enabled"  # Separate read/write permissions
dangerous_operations: "require_confirmation"
system_files: "protected"
git_operations: "safe_mode"

# Risk Mitigation
backup_before_changes: true
rollback_capability: true
change_logging: "comprehensive"
```

---

## 5. Quality Standards

### Test Coverage Requirements (GodsGolemInc Standard + TDD)
- **Coverage Target**: 100% (no exceptions)
- **Pass Rate**: 100% (all tests must pass)
- **TDD Compliance**: All code must be test-first (PDF insight)
- **Test Categories (MECE)**:
  - Unit Tests: Single component isolation + TDD red-green-refactor
  - Integration Tests: Cross-component interaction
  - Property Tests: Automated invariant validation
  - Performance Tests: Benchmark and regression detection
  - Security Tests: Vulnerability and safety checks

### Code Quality Standards
```bash
# Quality Gates (All must pass)
nim check src/**/*.nim     # Syntax validation
niuv test --coverage       # 100% coverage required
niuv test --tdd-compliance # TDD workflow verification (PDF insight)
niuv build                 # Successful compilation
/security-review           # Custom security check command
```

### Token Optimization (PDF Insight)
```toml
# Performance Targets
[performance]
memory_usage_max = "{value} MB"
startup_time_max = "{value} ms"
response_time_p99 = "{value} ms"
throughput_min = "{value} ops/sec"

# Claude Code Optimization
[claude_optimization]
claude_md_size_max = "200 lines"     # Prevent bloat
custom_commands_count = "10+"        # Offload repetitive workflows
token_reduction_target = "20%"       # Efficiency goal
memory_hierarchy_depth = "3 levels"  # Folder-based organization
```

---

## 6. Knowledge Management

### Hierarchical Memory Strategy (PDF Insight)
```markdown
## Memory Organization
### Global Level (Project Root CLAUDE.md)
- Project standards and policies
- Cross-cutting concerns
- Ecosystem integration rules

### Component Level (Subfolder CLAUDE.md)
- Component-specific patterns
- Local implementation details
- Module interaction rules

### Workflow Level (.claude/commands/)
- Reusable command patterns
- Automated sequences
- Custom development flows

## Memory Path Configuration
```bash
# Explicit memory path usage
claude --memory-path docs/architecture/  # Architecture-specific context
claude --memory-path src/components/     # Component-specific context
claude --memory-path tests/integration/  # Testing-specific context
```

### File Discovery Index
```markdown
## Critical File Locations
### Configuration
- Main config: {path}
- Environment: {path}
- Dependencies: {path}
- Claude settings: .claude/settings.json

### Core Logic
- Entry point: {path}
- Main business logic: {path}
- External integrations: {path}

### Testing & TDD
- Test runner: {path}
- TDD templates: tests/templates/
- Test fixtures: {path}
```

### Command Repository (PDF Insight)
```markdown
## Custom Commands Registry
### Development Commands
- `/setup-component` - Standard component scaffolding
- `/tdd-cycle` - Complete test-driven development cycle
- `/code-review` - Automated code review checklist

### Quality Commands
- `/security-audit` - Comprehensive security analysis
- `/performance-profile` - Performance bottleneck identification
- `/compliance-check` - Ecosystem standard verification

### Deployment Commands
- `/deploy-staging` - Staging environment deployment
- `/production-checklist` - Pre-production validation
- `/rollback-safe` - Safe rollback procedures
```

---

## 7. Team Collaboration

### Session Handoff Protocol (Enhanced)
```bash
# Starting a New Session
"CLAUDE.mdの「プロジェクト解析履歴」を参照して、前回の解析状況を教えて"
"--memory-path {specific_path} を使って、{module}の継続開発を始めて"

# Memory-Aware Handoff (PDF insight)
"階層化メモリ構造を使って、{component}の開発コンテキストを引き継いで"
"/workflow-resume {session_id} で前回のワークフローを継続して"

# Ending a Session
"今回の調査結果を適切なCLAUDE.mdファイルに記録して"
"/session-summary で今回のセッション内容をまとめて"
```

### Documentation Standards (Enhanced)
```markdown
## Documentation Requirements
- **API Changes**: Update API_SPECIFICATION_V2.md
- **Architecture Changes**: Update architecture decision log
- **New Dependencies**: Document in technology stack
- **Breaking Changes**: Add to CHANGELOG.md
- **Security Changes**: Update security requirements
- **Memory Structure**: Update hierarchical CLAUDE.md files
- **Custom Commands**: Document new commands in .claude/commands/
```

### Settings Management (PDF Insight)
```json
// .claude/settings.json (Project-specific settings)
{
  "memory": {
    "hierarchical": true,
    "auto_discovery": true,
    "max_context_size": "32k"
  },
  "workflow": {
    "tdd_enforcement": true,
    "japanese_responses": true,
    "custom_commands_enabled": true
  },
  "safety": {
    "permission_separation": true,
    "dangerous_operations_require_confirmation": true,
    "backup_before_changes": true
  }
}
```

---

## 8. Advanced Configuration

### Dotfiles Integration (PDF Insight)
```bash
# Global Claude Code Configuration (~/.claude/)
# Should be managed in dotfiles for consistency

# ~/.claude/config.toml (Global settings)
[global]
language = "japanese"
tdd_mode = true
memory_management = "hierarchical"

[optimization]
token_efficiency = true
custom_commands_preferred = true
context_size_limit = "32k"

[safety]
permission_model = "separated"
confirmation_required = ["rm", "git push", "deploy"]
```

### Custom Commands Implementation
```bash
# .claude/commands/tdd-cycle.md
## TDD Cycle Command
1. Write failing test first (Red)
2. Write minimal code to pass (Green)
3. Refactor for quality (Refactor)
4. Commit with descriptive message

# .claude/commands/security-review.md
## Security Review Command
1. Check for hardcoded secrets
2. Validate input sanitization
3. Review authentication/authorization
4. Scan dependencies for vulnerabilities
5. Verify error handling doesn't leak info

# .claude/commands/deploy-staging.md
## Staging Deployment Command
1. Run full test suite
2. Check security compliance
3. Validate configuration
4. Deploy to staging
5. Run smoke tests
6. Update deployment log
```

### Environment-Specific Settings
```toml
# niuv.toml configuration
[project]
name = "niuv"
version = "1.0.0"

[quality_standards]
coverage_threshold = 100
test_pass_rate = 100
tdd_compliance = true                    # PDF insight
performance_regression_threshold = 5

[claude_integration]
memory_hierarchy = true                  # PDF insight
custom_commands = true                   # PDF insight
token_optimization = true               # PDF insight
japanese_mode = true                     # PDF insight
tdd_enforcement = true                   # PDF insight

[build]
optimization = "release"
debug_symbols = true
memory_model = "arc"  # or "orc"
```

### IDE Integration (Enhanced)
```json
// .vscode/settings.json
{
  "nim.suggest.enable": true,
  "nim.test.enable": true,
  "files.associations": {
    "*.nim": "nim",
    "CLAUDE.md": "markdown"
  },
  "claude.memory.hierarchical": true,
  "claude.commands.custom": true,
  "claude.tdd.enforcement": true
}
```

---

## Implementation Notes

### Claude Code Behavior (Enhanced with PDF insights)
```yaml
# Known Patterns & Optimizations
auto_loading: "inconsistent - use explicit loading"
format_checking: "post-edit only - no real-time preview"
large_projects: "use hierarchical memory approach"
session_memory: "persists context - good for continuous work"
token_optimization: "use custom commands for repetitive workflows"
memory_hierarchy: "folder-based context isolation"

# Recommended Practices (PDF-derived)
explicit_loading: '"CLAUDE.mdを読んで、このプロジェクトの設定を理解してください"'
memory_paths: '"--memory-path {specific_folder} を使って特定コンテキストで作業"'
tdd_enforcement: '"常にTDD（テスト駆動開発）でコードを書いて"'
japanese_responses: '"常に日本語で回答して"'
custom_commands: '"/workflow-name でカスタムワークフローを実行"'
```

### Token Optimization Strategies (PDF Insight)
```bash
# Before: Large CLAUDE.md (352+ lines)
# After: Streamlined CLAUDE.md + Custom Commands

# Efficiency Gains
token_reduction = "20%"        # From custom command usage
context_precision = "improved" # From hierarchical memory
workflow_speed = "faster"      # From automated commands
maintenance_ease = "better"    # From organized structure
```

---

## Project-Specific Customization

### {Replace with project-specific sections}
```markdown
## Custom Section Example
### TDD Workflow Integration
- Red: Write failing test first
- Green: Implement minimum viable solution
- Refactor: Improve code quality while maintaining tests
- Commit: Descriptive commit with test status

### Memory Hierarchy Setup
- Root CLAUDE.md: Project standards
- Component CLAUDE.md: Module-specific rules
- Workflow Commands: Automated sequences

### Security & Permission Strategy
- Read-only by default for system files
- Write permissions require explicit confirmation
- Dangerous operations (rm, git push) need approval
- Change logging for audit trail
```

---

## Maintenance & Updates

### Regular Review Schedule (Enhanced)
- **Daily**: TDD compliance verification, custom command usage
- **Weekly**: Test coverage verification, memory hierarchy optimization
- **Monthly**: Dependency updates, token usage analysis
- **Quarterly**: Architecture review, security audit

### Token Efficiency Monitoring
```bash
# Monitor CLAUDE.md size and token usage
wc -l CLAUDE.md                    # Keep under 200 lines
/token-usage-report                # Custom command for usage analysis
/optimize-memory-hierarchy         # Custom command for optimization
```

---

**Generated with Enhanced Claude Code Best Practices Framework**  
**Last Updated**: 2025-06-24  
**Template Version**: 2.1.0 (PDF-Enhanced)  
**Compatible with**: Claude Code v2.0+, GodsGolemInc Ecosystem  
**PDF Sources**: 15+ community best practice documents  
**Key Enhancements**: Token optimization, TDD integration, Memory hierarchy, Custom commands