import std/unittest

import parsetoml

let tomlStr = """
[workspace]
members = ["crate1", "crate2"]
resolver = "2"

[workspace.dependencies]
serde = { version = "1.0", features = ["derive"] }
tokio = { version = "1.39", features = ["full"] }
rand = "0.8"

[dependencies]
serde = { workspace = true }
tokio = { workspace = true }
"""

# Parse the TOML
let toml = parsetoml.parseString(tomlStr)

echo "=== Full TOML Structure ==="
echo toml
echo ""

echo "=== Accessing workspace section ==="
if toml.hasKey("workspace"):
  let workspace = toml["workspace"]
  echo "Type of workspace: ", workspace.kind
  echo "workspace content: ", workspace
  echo ""
  
  # Check if dependencies exists in workspace
  if workspace.kind == TomlValueKind.Table and workspace.hasKey("dependencies"):
    echo "workspace has dependencies key"
    let deps = workspace["dependencies"]
    echo "Type of workspace.dependencies: ", deps.kind
    echo "workspace.dependencies content: ", deps
  else:
    echo "workspace does not have dependencies key directly"

echo ""
echo "=== Checking for workspace.dependencies as top-level key ==="
if toml.hasKey("workspace.dependencies"):
  echo "Found 'workspace.dependencies' as a top-level key"
  let workspaceDeps = toml["workspace.dependencies"]
  echo "Type: ", workspaceDeps.kind
  echo "Content: ", workspaceDeps
else:
  echo "'workspace.dependencies' not found as top-level key"

echo ""
echo "=== All top-level keys ==="
if toml.kind == TomlValueKind.Table:
  for key in toml.tableVal.keys:
    echo "- ", key

echo ""
echo "=== Iterating through workspace.dependencies ==="
if toml.hasKey("workspace.dependencies"):
  let workspaceDeps = toml["workspace.dependencies"]
  if workspaceDeps.kind == TomlValueKind.Table:
    for depName, depValue in workspaceDeps.tableVal.pairs:
      echo "Package: ", depName
      echo "  Type: ", depValue.kind
      if depValue.kind == TomlValueKind.Table:
        echo "  Details: ", depValue
      elif depValue.kind == TomlValueKind.String:
        echo "  Version: ", depValue.getStr()
      echo ""

echo "=== Accessing specific dependency ==="
if toml.hasKey("workspace.dependencies"):
  let workspaceDeps = toml["workspace.dependencies"]
  if workspaceDeps.hasKey("serde"):
    let serde = workspaceDeps["serde"]
    echo "serde type: ", serde.kind
    if serde.kind == TomlValueKind.Table:
      if serde.hasKey("version"):
        echo "serde version: ", serde["version"].getStr()
      if serde.hasKey("features"):
        echo "serde features: ", serde["features"]
suite "parsetoml_nested Tests":
  test "Basic test":
    check true
