# Package
version       = "0.1.0"
author        = "Example Author"
description   = "Example Project using Niuv"
license       = "MIT"
srcDir        = "src"
bin           = @["example_project"]

# Dependencies
requires "nim >= 2.2.0"

# Standard dependencies
requires "jester >= 0.5.0"     # Web framework
requires "karax >= 1.2.0"      # UI framework

# Development dependencies
requires "unittest2"           # dev
requires "testify"             # dev

# Tasks
task dev, "Run development server":
  exec "niuv run nim c -r src/server.nim"

task build, "Build release version":
  exec "niuv run nim c -d:release -o:example_project src/main.nim"

task setup, "Set up development environment":
  exec "niuv init --nim-version=2.2.0"
  exec "niuv install --dev"
EOF < /dev/null