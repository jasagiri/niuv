@echo off
REM Script to compile all test files to the build/tests directory

echo === Compiling all test files ===

REM Create needed directories
mkdir build\tests build\nimcache 2>nul

REM Find all test files
for /r tests %%F in (test_*.nim) do (
    REM Extract test name
    for %%N in ("%%~nF") do (
        echo Compiling %%~nF from %%F
        
        REM Compile without running
        nim c --nimcache:build/nimcache --out:build/tests/%%~nF.exe "%%F"
        
        if errorlevel 0 (
            echo ✓ Successfully compiled %%~nF
        ) else (
            echo ✗ Failed to compile %%~nF
        )
    )
)

echo All tests compiled to build\tests\