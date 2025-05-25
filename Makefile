# Makefile for niuv

# Determine OS-specific commands
ifeq ($(OS),Windows_NT)
	RM := rmdir /s /q
	MKDIR := mkdir
	SEP := \\
	SHELL := cmd.exe
	ENV_CMD := env.bat
else
	RM := rm -rf
	MKDIR := mkdir -p
	SEP := /
	ENV_CMD := ./env.sh
endif

# Directories
PROJECT_ROOT := .
SRC_DIR := $(PROJECT_ROOT)$(SEP)src
TESTS_DIR := $(PROJECT_ROOT)$(SEP)tests
BUILD_DIR := $(PROJECT_ROOT)$(SEP)build
DOCS_DIR := $(PROJECT_ROOT)$(SEP)docs
EXAMPLES_DIR := $(PROJECT_ROOT)$(SEP)examples
BIN_DIR := $(BUILD_DIR)$(SEP)bin

# Main targets
.PHONY: all build compile clean test docs examples run help coverage coverage-html coverage-lcov coverage-clean

all: build

help:
	@echo "Niuv - Make Targets"
	@echo "==================="
	@echo "build        - Build the project using nimble"
	@echo "compile      - Build using direct nim compiler"
	@echo "clean        - Remove all build artifacts"
	@echo "test         - Run all tests"
	@echo "test_file    - Run a specific test (TEST=test_file.nim)"
	@echo "coverage     - Generate test coverage report"
	@echo "coverage-html - Generate HTML coverage report"
	@echo "coverage-lcov - Generate LCOV coverage report"
	@echo "docs         - Generate documentation"
	@echo "examples     - Build all examples"
	@echo "run_example  - Build and run an example (EXAMPLE=example.nim)"
	@echo "deps         - Install dependencies"

# Build using nimble
build:
	# First clean any binary in the root directory
ifeq ($(OS),Windows_NT)
	if exist power_assert.exe del power_assert.exe
else
	rm -f $(PROJECT_ROOT)/power_assert
endif
	# Then run the build
	nimble build
	# Ensure no binary left in root directory
ifeq ($(OS),Windows_NT)
	if exist power_assert.exe move power_assert.exe $(BIN_DIR)
else
	[ -f $(PROJECT_ROOT)/power_assert ] && mv $(PROJECT_ROOT)/power_assert $(BIN_DIR) || true
endif

# Direct compilation with nim
compile:
	nim c -d:release -o:$(BIN_DIR)$(SEP)power_assert $(SRC_DIR)$(SEP)power_assert.nim

# Clean build artifacts
clean:
	nimble clean

# Run tests
test:
	nimble test

# Run a specific test
test_file:
	TEST_FILE=$(TEST) nimble test

# Generate coverage report
coverage:
	./niuv coverage --format=html,json,lcov

# Generate HTML coverage report only
coverage-html:
	./niuv coverage --format=html

# Generate LCOV coverage report only
coverage-lcov:
	./niuv coverage --format=lcov

# Clean coverage data
coverage-clean:
	$(RM) coverage
	$(RM) *.gcda *.gcno
	find . -name "*.gcda" -delete 2>/dev/null || true
	find . -name "*.gcno" -delete 2>/dev/null || true

# Generate documentation
docs:
	nimble docs

# Build examples
examples:
	nim c -o:$(BUILD_DIR)$(SEP)examples$(SEP)power_assert_example $(EXAMPLES_DIR)$(SEP)example.nim

# Run a specific example
run_example:
	nim c -r $(EXAMPLES_DIR)$(SEP)$(EXAMPLE)

# Install dependencies
deps:
	nimble install -y