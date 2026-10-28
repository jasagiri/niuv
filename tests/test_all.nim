## Every E test of niuv in one run. Add a new test file here and to the
## nimble task.

import unit/[test_child, test_cli, test_decl, test_gleambuild, test_inbuilder, test_lock, test_manifest, test_nimbuild, test_resolve, test_sbom, test_target, test_wasm, test_workspace]

const files = [test_child.testFile, test_cli.testFile, test_decl.testFile, test_gleambuild.testFile, test_inbuilder.testFile, test_lock.testFile, test_manifest.testFile, test_nimbuild.testFile, test_resolve.testFile, test_sbom.testFile, test_target.testFile, test_wasm.testFile, test_workspace.testFile]

echo "niuv: ", files.len, " test files"
