@echo off
setlocal EnableDelayedExpansion

REM Define the array of commands
set c[1]=java -jar extension-tester.jar --generate-index
set c[2]=java -jar extension-tester.jar src/pl/Pokatne.lua
set c[3]=java -jar extension-tester.jar src/en/Reddit.lua
set c[4]=java -jar extension-tester.jar src/all/AnyWeb.lua

REM Check for a command-line argument
if "%1" neq "" (
    REM Validate the argument
    if not defined c[%1%] (
        echo Invalid choice: %1.
        goto menu
    )
    REM Execute the command directly
    call !c[%1%]!
    goto end
)

:menu
cls
REM Display the list of commands
set i=1
for /F "tokens=2 delims==" %%a in ('set c[') do (
    echo !i!. %%a
    set /a i+=1
)

REM Get user selection
set /p choice="Enter your choice: "

REM Validate user input
if not defined c[%choice%] (
    echo Invalid choice. Exiting...
    goto end
)

REM Execute the selected command
call !c[%choice%]!
goto end

:end
