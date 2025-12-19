@echo off
:: Cong cu tao Shortcut bypass UAC cho bat ky ung dung nao

:: Tu dong xin quyen Admin
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    goto UACPrompt
) else (
    goto gotAdmin
)

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

cls
echo ========================================
echo  Tao Shortcut Bypass UAC
echo ========================================
echo.

:: Nhap duong dan ung dung
:InputPath
set "APP_PATH="
echo Nhap duong dan day du cua ung dung:
echo (hoac keo tha file vao day)
echo.
set /p "APP_PATH=Duong dan: "

:: Xoa dau ngoac kep neu co
set "APP_PATH=%APP_PATH:"=%"

:: Kiem tra file co ton tai khong
if not exist "%APP_PATH%" (
    echo.
    echo [LOI] Khong tim thay file: %APP_PATH%
    echo.
    pause
    goto InputPath
)

:: Lay ten file
for %%F in ("%APP_PATH%") do (
    set "APP_NAME=%%~nF"
    set "APP_FULL=%%~fF"
)

echo.
echo Ung dung: %APP_NAME%
echo Duong dan: %APP_FULL%
echo.

:: Nhap ten shortcut
set "SHORTCUT_NAME=%APP_NAME%"
echo Nhap ten shortcut (Enter de dung '%APP_NAME%'):
set /p "SHORTCUT_NAME="
if "%SHORTCUT_NAME%"=="" set "SHORTCUT_NAME=%APP_NAME%"

:: Tao ten task duy nhat
set "TASK_NAME=%APP_NAME%_NoUAC"

echo.
echo Dang tao Task Scheduler...

:: Xoa task cu neu co
schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>&1

:: Tao XML cho Task
set "XML=%TEMP%\task_%RANDOM%.xml"
(
echo ^<?xml version="1.0" encoding="UTF-16"?^>
echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo   ^<RegistrationInfo^>
echo     ^<Description^>Bypass UAC for %APP_NAME%^</Description^>
echo   ^</RegistrationInfo^>
echo   ^<Triggers /^>
echo   ^<Principals^>
echo     ^<Principal^>
echo       ^<LogonType^>InteractiveToken^</LogonType^>
echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
echo     ^</Principal^>
echo   ^</Principals^>
echo   ^<Settings^>
echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
echo     ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
echo     ^<Enabled^>true^</Enabled^>
echo     ^<Hidden^>false^</Hidden^>
echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
echo   ^</Settings^>
echo   ^<Actions^>
echo     ^<Exec^>
echo       ^<Command^>"%APP_FULL%"^</Command^>
echo     ^</Exec^>
echo   ^</Actions^>
echo ^</Task^>
) > "%XML%"

schtasks /Create /XML "%XML%" /TN "%TASK_NAME%" /F
if %errorlevel% NEQ 0 (
    echo.
    echo [LOI] Khong the tao Task Scheduler
    del "%XML%" >nul 2>&1
    pause
    exit /b 1
)
del "%XML%" >nul 2>&1

echo [OK] Task Scheduler da duoc tao
echo.
echo Dang tao Shortcut tren Desktop...

:: Tao shortcut tren Desktop
set "VBS=%TEMP%\sc_%RANDOM%.vbs"
(
echo Set WshShell = CreateObject("WScript.Shell"^)
echo Set Shortcut = WshShell.CreateShortcut("%USERPROFILE%\Desktop\%SHORTCUT_NAME%.lnk"^)
echo Shortcut.TargetPath = "schtasks.exe"
echo Shortcut.Arguments = "/Run /TN ""%TASK_NAME%"""
echo Shortcut.WindowStyle = 7
echo Shortcut.IconLocation = "%APP_FULL%,0"
echo Shortcut.Description = "Run %APP_NAME% without UAC prompt"
echo Shortcut.Save
) > "%VBS%"

cscript //NoLogo "%VBS%"
if %errorlevel% NEQ 0 (
    echo.
    echo [LOI] Khong the tao shortcut
    del "%VBS%" >nul 2>&1
    pause
    exit /b 1
)
del "%VBS%" >nul 2>&1

echo [OK] Shortcut da duoc tao tren Desktop
echo.
echo ========================================
echo  HOAN TAT!
echo ========================================
echo.
echo Shortcut "%SHORTCUT_NAME%.lnk" da co tren Desktop
echo Ban co the chay ung dung ma khong can UAC prompt
echo.

:: Hoi co muon tao shortcut khac khong
echo.
echo Ban co muon tao shortcut khac khong? (Y/N)
choice /C YN /N /M ""
if %errorlevel%==1 (
    cls
    goto gotAdmin
)

exit