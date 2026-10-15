@echo off
REM Generate test reports from test output

REM Default values
set TEST_OUTPUT_FILE=build\test_output.log
set JSON_REPORT_FILE=build\reports\test_report.json
set HTML_REPORT_FILE=build\reports\test_report.html
set VERBOSE=

REM Parse command line arguments
:arg_loop
if "%~1"=="" goto arg_done
set ARG=%~1
if "%ARG:~0,9%"=="--output=" (
  set TEST_OUTPUT_FILE=%ARG:~9%
) else if "%ARG:~0,7%"=="--json=" (
  set JSON_REPORT_FILE=%ARG:~7%
) else if "%ARG:~0,7%"=="--html=" (
  set HTML_REPORT_FILE=%ARG:~7%
) else if "%ARG%"=="--verbose" (
  set VERBOSE=--verbose
) else if "%ARG%"=="--help" (
  echo Usage: generate_test_report.bat [options]
  echo Options:
  echo   --output=^<file^>       Test output file (default: build\test_output.log)
  echo   --json=^<file^>         JSON report output file (default: build\reports\test_report.json)
  echo   --html=^<file^>         HTML report output file (default: build\reports\test_report.html)
  echo   --verbose             Enable verbose output
  echo   --help                Show this help message
  exit /b 0
) else (
  REM Handle positional arguments
  if not defined POS_ARG1 (
    set TEST_OUTPUT_FILE=%~1
    set POS_ARG1=1
  ) else if not defined POS_ARG2 (
    set JSON_REPORT_FILE=%~1
    set POS_ARG2=1
  ) else if not defined POS_ARG3 (
    set HTML_REPORT_FILE=%~1
    set POS_ARG3=1
  )
)
shift
goto arg_loop
:arg_done

REM Ensure reports directory exists
if not exist "%JSON_REPORT_FILE%\..\" mkdir "%JSON_REPORT_FILE%\.."
if not exist "%HTML_REPORT_FILE%\..\" mkdir "%HTML_REPORT_FILE%\.."

REM Run test report generator
echo Generating test reports from %TEST_OUTPUT_FILE%
nim c -r src/tools/report/test_report.nim "%TEST_OUTPUT_FILE%" --json="%JSON_REPORT_FILE%" --html="%HTML_REPORT_FILE%" %VERBOSE%

REM Exit with the exit code of the test report generator
exit /b %ERRORLEVEL%