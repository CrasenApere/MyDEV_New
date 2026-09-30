@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
set "SEVENZIP=C:\Program Files\7-Zip\7z.exe"
set "WSLNAME=LinuxBase"
set "TEMPDIR=%ROOT%.env_base"
set "BASETAR=%ROOT%master.tar"
set "PKGTAR=%ROOT%pkg.tar"
set "ARCHIVE=%ROOT%master.7z"
set "PKGARCHIVE=%ROOT%pkg.7z"

if not exist "%SEVENZIP%" ( echo [ERROR] 7-Zip not found & pause & exit /b 1 )
if not exist "%ARCHIVE%"  ( echo [ERROR] master.7z not found & pause & exit /b 1 )

:MENU
cls
echo ================================
echo  Add pkg?
echo   [1] Yes (base + pkg = full)
echo   [0] No (base only)
echo ================================
set "ADD="
set /p "ADD=Choose (0/1): "
if not defined ADD goto MENU
if not "!ADD!"=="0" if not "!ADD!"=="1" goto MENU

if "!ADD!"=="1" (
    if not exist "%PKGARCHIVE%" ( echo [ERROR] pkg.7z not found & pause & exit /b 1 )
)

wsl -d %WSLNAME% -e true >nul 2>&1
if errorlevel 1 ( set "NEED_IMPORT=1" ) else if not exist "%TEMPDIR%" ( set "NEED_IMPORT=1" ) else ( set "NEED_IMPORT=0" )

if "!NEED_IMPORT!"=="1" (
    echo [+] Cleaning old instance...
    if exist "%TEMPDIR%" rmdir /s /q "%TEMPDIR%" 2>nul
    if exist "%BASETAR%" del /q "%BASETAR%" 2>nul
    if exist "%PKGTAR%"  del /q "%PKGTAR%"  2>nul

    echo [+] Extracting master.7z...
    "%SEVENZIP%" x "%ARCHIVE%" -o"%ROOT%" -y
    if errorlevel 1 ( echo [ERROR] Extracting master failed & pause & exit /b 1 )

    echo [+] Importing base...
    mkdir "%TEMPDIR%"
    wsl --unregister %WSLNAME% 2>nul
    wsl --import %WSLNAME% "%TEMPDIR%" "%BASETAR%" --version 1
    if errorlevel 1 ( echo [ERROR] Import base failed & pause & exit /b 1 )
    del /q "%BASETAR%"

    if "!ADD!"=="1" (
        echo [+] Extracting pkg.7z...
        "%SEVENZIP%" x "%PKGARCHIVE%" -o"%ROOT%" -y
        if errorlevel 1 ( echo [ERROR] Extracting pkg failed & pause & exit /b 1 )

        echo [+] Overlaying pkg onto base...
        wsl -d %WSLNAME% -u root -e bash -c "cd / && tar -xpf /mnt/c/Users/Giahu/Downloads/DEV/COMPILER/Linux/pkg.tar 2>/dev/null"
        if errorlevel 1 ( echo [ERROR] Overlay pkg failed & pause & exit /b 1 )
        del /q "%PKGTAR%"
    ) else (
        echo [+] Base only, skipping pkg overlay.
    )

    echo [+] Done. Checking environment:
    wsl -d %WSLNAME% -u root -e bash -c "which sudo git gcc python3 cmake htop tmux; dpkg -l | wc -l; date"
) else (
    echo [+] Instance exists, skipping import.
    echo [+] Entering shell: wsl -d %WSLNAME%
)

pause