import std/unittest

import ./test_workspace_simple
import ./test_workspace_coverage
import ./test_workspace_extended

when isMainModule:
  echo "Running all workspace tests..."
suite "workspace_all Tests":
  test "Basic test":
    check true
