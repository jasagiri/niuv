Feature: Running Tests
  As a Nim developer
  I want to run tests for my projects
  So that I can ensure code quality and prevent regressions

  Background:
    Given I have Niuv installed
    And I am in a project directory with tests

  Scenario: Run all tests
    When I run "niuv test"
    Then all tests should be executed
    And a summary of test results should be displayed
    And the command should complete with appropriate status code

  Scenario: Run specific test file
    When I run "niuv test --file=tests/test_config.nim"
    Then only the specified test file should be executed
    And the test results should be displayed
    And the command should complete successfully

  Scenario: Run tests matching pattern
    When I run "niuv test --pattern=*_config*"
    Then only tests matching the pattern should be executed
    And the test results should be displayed
    And the command should complete successfully

  Scenario: Run tests with JUnit XML report
    When I run "niuv test --format=junit --output=test-results.xml"
    Then all tests should be executed
    And a JUnit XML report should be generated
    And the report should contain detailed test information
    And the command should complete successfully

  Scenario: Run tests with HTML report
    When I run "niuv test --format=html --output=test-results.html"
    Then all tests should be executed
    And an HTML report should be generated
    And the report should be viewable in a browser
    And the command should complete successfully

  Scenario: Run tests with JSON report
    When I run "niuv test --format=json --output=test-results.json"
    Then all tests should be executed
    And a JSON report should be generated
    And the report should contain detailed test information
    And the command should complete successfully

  Scenario: Run tests with verbose output
    When I run "niuv test --verbose"
    Then all tests should be executed
    And detailed output of each test should be displayed
    And the command should complete successfully

  Scenario: Run tests with parallel execution
    When I run "niuv test --parallel"
    Then tests should be executed in parallel
    And the execution should be faster than sequential
    And test results should be collected correctly
    And the command should complete successfully

  Scenario: Run failing tests
    Given tests with failures
    When I run "niuv test"
    Then failed tests should be reported
    And a summary of failures should be displayed
    And the command should exit with non-zero status
    
  Scenario: Run tests with coverage
    When I run "niuv test --coverage"
    Then all tests should be executed
    And code coverage information should be collected
    And a coverage report should be generated
    And the command should complete successfully