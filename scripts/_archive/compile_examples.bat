@echo off
REM Script to compile all example files to the build/examples directory

echo === Compiling all example files ===

REM Create needed directories
if not exist build\examples mkdir build\examples
if not exist build\nimcache mkdir build\nimcache

REM Find and compile all example files
for %%F in (examples\*.nim) do (
    echo Compiling %%~nF from %%F
    nim c --nimcache:build/nimcache --out:build/examples/%%~nF.exe %%F
    if errorlevel 1 (
        echo X Failed to compile %%~nF
    ) else (
        echo √ Successfully compiled %%~nF
    )
)

echo All examples compiled to build\examples\