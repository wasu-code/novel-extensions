@echo off
setlocal

REM Check if parameter is provided
if "%~1"=="" (
    echo Usage:
    echo    test index
    echo    test lang/Name
    exit /b 1
)

if /i "%~1"=="index" (
    java -jar extension-tester.jar --generate-index
) else (
    java -jar extension-tester.jar src\%~1%.lua
)