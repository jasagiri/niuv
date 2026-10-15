@echo off
:: Save old environment variables
set OLD_PATH=%PATH%
set OLD_NIMBLE_PATH=%NIMBLE_PATH%
set OLD_CD=%CD%

:: Set new environment variables
set PATH=%CD%\\nimbledeps\\bin;%PATH%
set NIMBLE_PATH=%CD%\\nimbledeps\\pkgs
set NIUV_ACTIVE=1
set NIUV_PROJECT=%CD%

:: Change prompt
set OLD_PROMPT=%PROMPT%
for %%i in ("%CD%") do set PROJECT_NAME=%%~ni
set PROMPT=(niuv:%PROJECT_NAME%) %PROMPT%

:: Create deactivate.bat
echo @echo off > deactivate.bat
echo :: Restore old environment variables >> deactivate.bat
echo set PATH=%OLD_PATH% >> deactivate.bat
echo set NIMBLE_PATH=%OLD_NIMBLE_PATH% >> deactivate.bat
echo set CD=%OLD_CD% >> deactivate.bat
echo set PROMPT=%OLD_PROMPT% >> deactivate.bat
echo set NIUV_ACTIVE= >> deactivate.bat
echo set NIUV_PROJECT= >> deactivate.bat
echo echo Virtual environment deactivated. >> deactivate.bat

echo Virtual environment activated. Use 'deactivate' to exit.
