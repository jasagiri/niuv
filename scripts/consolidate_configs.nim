## Script to consolidate and minimize niuv configuration files
## Uses nim-configkit and nim-testkit for configuration management

import std/[os, strutils, times]
import ../src/config_manager

proc main() =
  echo "=== niuv Configuration Consolidation ==="
  echo ""
  
  # Initialize configuration manager
  let manager = initNiuvConfigManager()
  
  echo "Detected profile: ", manager.profile
  echo ""
  
  # Backup existing configuration files
  echo "Backing up existing configuration files..."
  let backupDir = "config_backup_" & $epochTime().int
  createDir(backupDir)
  
  let configFiles = @[
    "nim.cfg",
    "nimble.cfg", 
    "config.nims",
    "src/nim.cfg",
    "tests/nim.cfg",
    "nimtestkit.toml"
  ]
  
  for file in configFiles:
    if fileExists(file):
      echo "  Backing up: ", file
      copyFile(file, backupDir / file.extractFilename)
  
  echo ""
  echo "Generating minimal configuration..."
  
  # Write minimal configurations
  manager.writeMinimalConfigs()
  manager.updateNimbleConfig()
  
  echo ""
  echo "Configuration files generated:"
  echo "  ✓ nim.cfg (minimal)"
  echo "  ✓ config.nims (dynamic profile-based configuration)"
  echo "  ✓ nimble.cfg (minimal)"
  
  if fileExists("nimtestkit.toml"):
    echo "  ✓ nimtestkit.toml (test configuration)"
  
  echo ""
  echo "Removed redundant files:"
  if not fileExists("src/nim.cfg"):
    echo "  ✗ src/nim.cfg"
  if not fileExists("tests/nim.cfg"):
    echo "  ✗ tests/nim.cfg"
  
  echo ""
  echo "Configuration consolidation complete!"
  echo "Backup saved to: ", backupDir
  
  # Show configuration summary
  echo ""
  echo "=== Configuration Summary ==="
  echo ""
  echo "Build profiles:"
  echo "  - debug: Development builds with debugging info"
  echo "  - release: Optimized production builds"
  echo "  - test: Test execution with nim-testkit integration"
  echo "  - benchmark: Performance testing builds"
  echo ""
  echo "Key features:"
  echo "  - Dynamic profile detection"
  echo "  - nim-configkit integration for flexible configuration"
  echo "  - nim-testkit integration for test configuration"
  echo "  - Minimal file footprint"
  echo "  - Environment variable overrides (NIUV_*)"
  echo ""
  echo "To customize configuration, create niuv.toml with:"
  echo """
[build]
dir = "build"

[debug]
opt = "none"
stackTrace = true
lineTrace = true

[release]
opt = "speed"

[test]
useTestKit = true
dir = "tests"
pattern = "test_*.nim"
parallel = false

[coverage]
enabled = true
threshold = 80.0
formats = ["html", "json"]
"""

when isMainModule:
  main()