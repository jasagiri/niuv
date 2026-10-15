## Every E test of niuv in one run. Add a new test file here and to the
## nimble task.

import unit/[test_cli, test_decl, test_lock, test_nimbuild, test_resolve, test_workspace]

const files = [test_cli.testFile, test_decl.testFile, test_lock.testFile, test_nimbuild.testFile, test_resolve.testFile, test_workspace.testFile]

echo "niuv: ", files.len, " test files"
