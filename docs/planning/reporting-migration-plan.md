# Niuv to Nim-TestKit Reporting Migration Plan

## Overview

This document provides a comprehensive plan for migrating niuv's reporting functionality to nim-testkit, analyzing overlaps, differences, and integration strategies.

## 1. Type Definitions Comparison

### Test Status

**niuv (reporting.nim)**:
```nim
type
  TestStatus* = enum
    Pass,    # テスト成功
    Fail,    # テスト失敗
    Skip,    # テストスキップ
    Error    # 実行エラー
```

**nim-testkit (core/types.nim)**:
```nim
type
  TestStatus* = enum
    tsUnknown = "unknown"
    tsPending = "pending"
    tsRunning = "running"
    tsPassed = "passed"
    tsFailed = "failed"
    tsSkipped = "skipped"
    tsError = "error"
```

**Migration Strategy**:
- nim-testkit has more granular states (Unknown, Pending, Running)
- Map niuv states: Pass→tsPassed, Fail→tsFailed, Skip→tsSkipped, Error→tsError
- Add lifecycle states to niuv's enhanced reporting

### Test Result

**niuv (reporting.nim)**:
```nim
type
  TestResult* = object
    name*: string            # テスト名
    suiteName*: string       # スイート名
    status*: TestStatus      # 状態
    message*: string         # メッセージ（エラー時）
    duration*: float         # 実行時間（秒）
    timestamp*: DateTime     # 実行時刻
```

**nim-testkit (core/types.nim)**:
```nim
type
  TestResult* = object
    name*: string
    category*: TestCategory
    status*: TestStatus
    startTime*: float
    endTime*: float
    duration*: float
    message*: string
    stackTrace*: string
    file*: string
    line*: int
```

**Migration Strategy**:
- nim-testkit has more detailed location info (file, line)
- nim-testkit uses category instead of suiteName
- nim-testkit has separate stackTrace field
- Enhance niuv to include file/line information
- Map suiteName to category or add suite support to nim-testkit

### Test Statistics/Report

**niuv (reporting.nim)**:
```nim
type
  TestStatistics* = object
    total*: int
    passed*: int
    failed*: int
    skipped*: int
    errors*: int
    duration*: float
    timestamp*: DateTime
    suites*: CountTable[string]
    failedTests*: HashSet[string]
```

**nim-testkit (core/types.nim)**:
```nim
type
  TestReport* = object
    suites*: seq[TestSuite]
    results*: seq[TestResult]
    totalTests*: int
    passed*: int
    failed*: int
    skipped*: int
    errors*: int
    startTime*: float
    endTime*: float
    duration*: float
```

**Migration Strategy**:
- Very similar structure
- nim-testkit includes suite objects, niuv uses CountTable
- nim-testkit stores all results, niuv tracks failed tests separately
- Merge approaches: keep suite objects and add failedTests tracking

## 2. Formatter Interfaces Comparison

### niuv's Formatter System

**Base Interface**:
```nim
type
  ReportFormatter* = ref object of RootObj
```

**Methods**:
- `beginTesting*(formatter: ReportFormatter)`
- `endTesting*(formatter: ReportFormatter, stats: TestStatistics)`
- `beginSuite*(formatter: ReportFormatter, suiteName: string)`
- `endSuite*(formatter: ReportFormatter, suiteName: string)`
- `reportTest*(formatter: ReportFormatter, result: TestResult)`
- `writeReport*(formatter: ReportFormatter, stats: TestStatistics, results: seq[TestResult])`

**Implementations**:
- ConsoleReportFormatter (colored output, verbosity levels)
- JsonReportFormatter (file/stdout, prettify option)
- HtmlReportFormatter (custom CSS, templating)

### nim-testkit's Formatter System

**Current Approach**:
- No formal formatter interface
- Direct functions for different formats:
  - `generateJUnitXML*(suite: TestSuite): string`
  - `generateTAP*(suite: TestSuite): string`
  - `printColoredOutput(suite: TestSuite, config: TestKitConfig)`
  - `toJson*(report: TestReport): string` (in results.nim)

**Migration Strategy**:
1. Create formal formatter interface in nim-testkit based on niuv's design
2. Migrate niuv's formatters as implementations
3. Refactor existing format functions to use new interface

## 3. Output Formats Comparison

### Supported Formats

**niuv**:
- Console (with colors, verbosity levels, Japanese messages)
- JSON (pretty/compact, file/stdout)
- HTML (custom CSS, full template)

**nim-testkit**:
- Text (colored console output)
- JSON (simple serialization)
- XML (JUnit format)
- TAP (Test Anything Protocol)
- JUnit (dedicated XML format)

**Migration Strategy**:
- Combine all formats in unified system
- Port niuv's HTML formatter to nim-testkit
- Enhance JSON formatter with niuv's features
- Keep nim-testkit's TAP and JUnit support

## 4. Feature Comparison

### niuv Unique Features

1. **Lifecycle hooks**: beginTesting, endTesting, beginSuite, endSuite
2. **Japanese language support** in console output
3. **Verbosity levels** (0: minimal, 1: standard, 2: detailed)
4. **Suite tracking** with CountTable
5. **Failed test tracking** with HashSet
6. **Custom CSS** for HTML reports
7. **Pretty JSON** option

### nim-testkit Unique Features

1. **Test categories** (unit, integration, system, performance, custom)
2. **Test filtering** by pattern
3. **Parallel execution** support
4. **Cache support** for test results
5. **File/line tracking** for test locations
6. **Stack trace** as separate field
7. **TAP and JUnit** output formats

## 5. Migration Plan

### Phase 1: Create Unified Type System

```nim
# In nim-testkit/src/core/reporting_types.nim
type
  # Enhanced TestResult combining both systems
  TestResult* = object
    # From nim-testkit
    name*: string
    category*: TestCategory
    status*: TestStatus
    startTime*: float
    endTime*: float
    duration*: float
    message*: string
    stackTrace*: string
    file*: string
    line*: int
    # From niuv
    suiteName*: string       # Suite support
    timestamp*: DateTime     # Execution timestamp
    
  # Formatter interface from niuv
  ReportFormatter* = ref object of RootObj
  
  # Enhanced report with niuv features
  TestReport* = object
    # From nim-testkit
    suites*: seq[TestSuite]
    results*: seq[TestResult]
    totalTests*: int
    passed*: int
    failed*: int
    skipped*: int
    errors*: int
    startTime*: float
    endTime*: float
    duration*: float
    # From niuv
    timestamp*: DateTime
    failedTests*: HashSet[string]
    suiteStats*: CountTable[string]
```

### Phase 2: Implement Formatter Interface

```nim
# In nim-testkit/src/formatters/base.nim
import ../core/reporting_types

method beginTesting*(formatter: ReportFormatter) {.base.} =
  discard

method endTesting*(formatter: ReportFormatter, report: TestReport) {.base.} =
  discard

method beginSuite*(formatter: ReportFormatter, suiteName: string) {.base.} =
  discard

method endSuite*(formatter: ReportFormatter, suiteName: string) {.base.} =
  discard

method reportTest*(formatter: ReportFormatter, result: TestResult) {.base.} =
  discard

method writeReport*(formatter: ReportFormatter, report: TestReport) {.base.} =
  discard
```

### Phase 3: Migrate Formatters

1. **Console Formatter**: 
   - Port from niuv with verbosity levels
   - Keep nim-testkit's color functions
   - Add internationalization support

2. **JSON Formatter**:
   - Merge niuv's pretty print with nim-testkit's serialization
   - Add file output option

3. **HTML Formatter**:
   - Direct port from niuv
   - Enhance with nim-testkit's categories

4. **Keep nim-testkit formatters**:
   - Refactor TAP generator to formatter
   - Refactor JUnit generator to formatter

### Phase 4: Integration Points

#### For niuv:

1. **Create adapter layer**:
```nim
# In niuv/src/testkit_reporting_adapter.nim
import nim_testkit/formatters/[base, console, json, html]

proc createTestKitFormatter*(format: string): ReportFormatter =
  case format
  of "console": newConsoleReportFormatter()
  of "json": newJsonReportFormatter()
  of "html": newHtmlReportFormatter()
  else: newConsoleReportFormatter()
```

2. **Keep niuv-specific features**:
   - Cucumber integration
   - Progress reporting
   - Workspace test coordination

#### For nim-testkit:

1. **Enhance runner.nim**:
```nim
proc runTestsWithFormatter*(formatter: ReportFormatter) =
  formatter.beginTesting()
  # ... run tests ...
  formatter.endTesting(report)
```

2. **Add configuration**:
```nim
type
  TestKitConfig* = object
    # ... existing fields ...
    formatter*: ReportFormatter
    verbosityLevel*: int
```

## 6. What Stays in Each Project

### Remains in niuv:

1. **Cucumber adapter** - BDD-specific reporting
2. **Workspace reporting** - Multi-project aggregation
3. **Progress tracking** - Real-time build progress
4. **Japanese localization** - Can be optional in nim-testkit

### Moves to nim-testkit:

1. **Core formatter interface**
2. **Basic formatters** (Console, JSON, HTML)
3. **Test result types**
4. **Statistics tracking**

### Enhanced in nim-testkit:

1. **Suite support** from niuv
2. **Verbosity levels** from niuv
3. **Failed test tracking** from niuv
4. **Timestamp support** from niuv

## 7. Implementation Timeline

1. **Week 1**: Create unified type system and formatter interface
2. **Week 2**: Migrate and test formatters
3. **Week 3**: Create adapters and integration layers
4. **Week 4**: Update documentation and examples

## 8. Benefits

1. **For nim-testkit**:
   - Gains flexible formatter system
   - Better reporting capabilities
   - HTML output support

2. **For niuv**:
   - Reduces code duplication
   - Leverages maintained reporting infrastructure
   - Focus on build tool features

3. **For users**:
   - Consistent reporting across tools
   - More output format options
   - Better extensibility