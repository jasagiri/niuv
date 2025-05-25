@echo off
REM Script to run the cancellation demo

REM Compile the demo
echo Compiling cancellation demo...
nim c -o:cancellation_demo.exe cancellation_demo.nim

REM Check if compilation was successful
if %ERRORLEVEL% neq 0 (
  echo Compilation failed! Exiting.
  exit /b 1
)

REM Default option if none provided
set OPTION=task-id
if not "%1"=="" set OPTION=%1

REM Run the demo with the specified option
echo Running cancellation demo with option: %OPTION%
cancellation_demo.exe %OPTION%

REM Clean up
echo Cleaning up...
del cancellation_demo.exe