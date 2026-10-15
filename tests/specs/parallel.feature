Feature: Parallel Task Execution
  As a Nim developer
  I want to execute tasks in parallel
  So that I can improve performance and efficiency

  Background:
    Given I have Niuv installed
    And I am in a project directory

  Scenario: Execute independent tasks in parallel
    Given multiple independent tasks
    When I run them in parallel
    Then all tasks should complete successfully
    And execution time should be faster than sequential execution
    And task outputs should be collected correctly

  Scenario: Set custom number of parallel jobs
    Given tasks that can run in parallel
    When I run with "--jobs=4" option
    Then exactly 4 jobs should run in parallel
    And system resources should be properly utilized
    And all tasks should complete successfully

  Scenario: Auto-detect optimal parallel jobs
    Given tasks that can run in parallel
    When I run without specifying job count
    Then an optimal number of parallel jobs should be used
    And the job count should respect system CPU cores
    And all tasks should complete successfully

  Scenario: Handle task dependencies
    Given tasks with dependencies
    When I run them in parallel
    Then dependent tasks should wait for prerequisites to complete
    And task execution order should respect dependencies
    And all tasks should complete successfully

  Scenario: Parallel error handling
    Given tasks where some will fail
    When I run them in parallel
    Then errors should be properly reported
    And successful tasks should still complete
    And error details should be available for each failed task

  Scenario: Cancel parallel execution
    Given long-running parallel tasks
    When I send a cancellation signal
    Then all running tasks should be terminated cleanly
    And resources should be properly released
    And partial results should be reported

  Scenario: Progress reporting for parallel tasks
    Given multiple parallel tasks
    When I run them with progress reporting
    Then overall progress should be displayed
    And individual task progress should be visible
    And progress updates should be in real-time

  Scenario: Parallel tasks with shared resources
    Given tasks that need to access shared resources
    When I run them in parallel
    Then resource access should be properly synchronized
    And no race conditions should occur
    And all tasks should complete successfully

  Scenario: Retry failed parallel tasks
    Given tasks that might fail transiently
    When I run them with retry enabled
    Then failed tasks should be retried automatically
    And retry count should be respected
    And eventually successful tasks should be reported as success