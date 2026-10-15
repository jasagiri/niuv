---
inherit: ../../../CLAUDE.md
cascade: true
project: niuv
type: library
---

## [APPEND] Common Development Commands
### Nim Compiler Detection Commands
```bash
# Show which Nim compiler would be used
niuv nim which

# List all available Nim compilers
niuv nim list

# Install project-local Nim (future feature)
niuv nim install 2.0.4
```

## [NEW] Automatic Nim Detection

Niuv now automatically detects and uses available Nim compilers when no project-local Nim is found. This eliminates the need for manual configuration in most cases.

### Detection Priority

1. **Explicit `nim_path`** in `niuv.toml`
2. **Project-local Nim** in `.niuv/nim/bin/nim`
3. **NIUV_NIM_PATH** environment variable
4. **Version-matched Nim** (if `nim_version` specified)
5. **System PATH Nim**
6. **Choosenim current**
7. **Common installation paths**

### Configuration Options

```toml
[tool.niuv]
# Explicit path (highest priority)
nim_path = "/custom/path/to/nim"

# Version constraint (uses choosenim or finds matching)
nim_version = "2.0.0"

# Detection strategy
nim_detection = "auto"  # auto (default), manual, project-only

# Allow fallback to system Nim
allow_system_nim = true  # Default: true
```

### User Experience

When building without configuration:
```bash
$ niuv build
🔍 No project-local Nim found, searching system...
✅ Found Nim 2.0.4 at /usr/local/bin/nim
🔨 Building with system Nim...
```

With version constraint:
```bash
$ niuv build
🔍 Looking for Nim >= 2.0.0...
✅ Found Nim 2.0.4 via choosenim
🔨 Building...
```

### Implementation Details

The detection is handled by two modules:
- `nim_detector.nim`: Low-level compiler detection
- `nim_resolver.nim`: Integration with niuv configuration

Detection results are cached for 5 minutes to improve performance.

### Disabling System Fallback

For projects requiring strict isolation:
```toml
[tool.niuv]
allow_system_nim = false
```

This ensures only project-local Nim is used, failing if not found.