#!/bin/bash
# Custom matchers for ShellSpec tests

# Matcher to check if a file contains specific nim flags
shellspec_matcher_include_nim_flags() {
  shellspec_matcher__match() {
    local flags="$1"
    shellspec_match "$SHELLSPEC_SUBJECT" "*$flags*"
  }

  shellspec_matcher__failure_message() {
    shellspec_putsn "expected: output to include nim flags '$1'"
    shellspec_putsn "     got: $SHELLSPEC_SUBJECT"
  }

  shellspec_matcher__failure_message_when_negated() {
    shellspec_putsn "expected: output not to include nim flags '$1'"
    shellspec_putsn "     got: $SHELLSPEC_SUBJECT"
  }
}

# Matcher to check if directory structure exists
shellspec_matcher_have_build_structure() {
  shellspec_matcher__match() {
    [[ -d "build/debug/bin" ]] && \
    [[ -d "build/debug/tests" ]] && \
    [[ -d "build/debug/examples" ]] && \
    [[ -d "build/nimcache" ]]
  }

  shellspec_matcher__failure_message() {
    shellspec_putsn "expected: standard build directory structure to exist"
    shellspec_putsn "missing directories:"
    [[ ! -d "build/debug/bin" ]] && shellspec_putsn "  - build/debug/bin"
    [[ ! -d "build/debug/tests" ]] && shellspec_putsn "  - build/debug/tests"
    [[ ! -d "build/debug/examples" ]] && shellspec_putsn "  - build/debug/examples"
    [[ ! -d "build/nimcache" ]] && shellspec_putsn "  - build/nimcache"
  }

  shellspec_matcher__failure_message_when_negated() {
    shellspec_putsn "expected: standard build directory structure not to exist"
  }
}

# Matcher for test result format
shellspec_matcher_show_test_results() {
  shellspec_matcher__match() {
    local passed="$1"
    local total="$2"
    shellspec_match "$SHELLSPEC_SUBJECT" "*Test Results: $passed/$total passed*"
  }

  shellspec_matcher__failure_message() {
    shellspec_putsn "expected: test results showing $1/$2 passed"
    shellspec_putsn "     got: $SHELLSPEC_SUBJECT"
  }

  shellspec_matcher__failure_message_when_negated() {
    shellspec_putsn "expected: test results not showing $1/$2 passed"
    shellspec_putsn "     got: $SHELLSPEC_SUBJECT"
  }
}