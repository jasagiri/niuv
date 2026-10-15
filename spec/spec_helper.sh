#!/bin/bash
# ShellSpec helper configuration

# Set shell options for testing
set -euo pipefail

# Enable ShellSpec helpers
# shellcheck disable=SC2034
SHELLSPEC_LOAD_PATH="$SHELLSPEC_SPECDIR/support"

# Define test fixtures path
export FIXTURES_DIR="$SHELLSPEC_SPECDIR/fixtures"

# Create temporary test directory for each test run
export TEST_TEMP_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Register cleanup
trap cleanup EXIT

# Helper function to create test project structure
create_test_project() {
    local project_dir="${1:-$TEST_TEMP_DIR/test_project}"
    mkdir -p "$project_dir"/{src,tests,examples,build}
    
    # Create minimal niuv.nimble
    cat > "$project_dir/niuv.nimble" << 'EOF'
version = "0.1.0"
author = "Test"
description = "Test project"
license = "MIT"
srcDir = "src"
bin = @["niuv"]
EOF
    
    # Create test files
    echo 'echo "Test main"' > "$project_dir/src/niuv.nim"
    echo 'echo "Test example"' > "$project_dir/examples/example.nim"
    echo 'echo "Test test"' > "$project_dir/tests/test_example.nim"
    
    echo "$project_dir"
}

# Helper to capture both stdout and stderr
capture_output() {
    local cmd="$1"
    local stdout_file="$TEST_TEMP_DIR/stdout"
    local stderr_file="$TEST_TEMP_DIR/stderr"
    local exit_code
    
    # Execute command and capture output
    set +e
    eval "$cmd" > "$stdout_file" 2> "$stderr_file"
    exit_code=$?
    set -e
    
    # Store outputs in variables
    STDOUT=$(<"$stdout_file")
    STDERR=$(<"$stderr_file")
    EXIT_CODE=$exit_code
    
    return $exit_code
}

# Mock nim compiler for testing
mock_nim() {
    cat > "$TEST_TEMP_DIR/nim" << 'EOF'
#!/bin/bash
# Mock nim compiler
echo "Mock nim called with: $*" >&2

# Simulate success for most cases
if [[ "$*" == *"fail"* ]]; then
    exit 1
fi

# Create mock output file if --out is specified
for i in "$@"; do
    if [[ "$prev" == "--out:"* ]]; then
        outfile="${prev#--out:}"
        mkdir -p "$(dirname "$outfile")"
        touch "$outfile"
        chmod +x "$outfile"
    fi
    prev="$i"
done

exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/nim"
    export PATH="$TEST_TEMP_DIR:$PATH"
}

# Helper to count files matching pattern
count_files() {
    local pattern="$1"
    local dir="${2:-.}"
    find "$dir" -name "$pattern" -type f 2>/dev/null | wc -l | tr -d ' '
}