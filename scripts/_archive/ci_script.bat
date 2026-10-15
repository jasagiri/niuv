@echo off
:: Example CI/CD script for Niuv integration on Windows

:: Install Niuv if not already installed
where niuv >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Installing Niuv...
    nimble install niuv
)

:: Initialize environment with specific Nim version
echo Initializing Niuv environment...
niuv init --nim-version=2.2.0 --verbose

:: Install dependencies (including dev for testing)
echo Installing dependencies...
niuv install --dev --parallel=4

:: Run tests
echo Running tests...
niuv run nim c -r tests/all_tests.nim

:: Build release version
echo Building release version...
niuv run nim c -d:release -o:app.exe src/main.nim

:: Create release artifacts
echo Creating release artifacts...
if not exist dist mkdir dist
copy app.exe dist\
xcopy /E /I public dist\public
copy README.md dist\
copy LICENSE dist\

echo CI/CD process completed successfully\!
EOF < /dev/null