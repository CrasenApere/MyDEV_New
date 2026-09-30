@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
set "ARCHIVE=%ROOT%master.7z"
set "TEMPDIR=%ROOT%.env"
set "BUNDIR=%TEMPDIR%\bun"
set "BUNARCHIVE=%ROOT%..\Bun\master.7z"
set "MANIFEST=%TEMPDIR%\.manifest"
set "SEVENZIP=C:\Program Files\7-Zip\7z.exe"
set "PSF=%TEMP%\_m%RANDOM%.ps1"
set "PSC=%TEMP%\_c%RANDOM%.ps1"

if not exist "%ARCHIVE%" (
    echo [ERROR] %ARCHIVE% not found!
    pause & exit /b 1
)

if not exist "%BUNARCHIVE%" (
    echo [ERROR] Bun archive not found at %BUNARCHIVE%
    echo         Ensure the Bun directory is placed alongside Svelte
    pause & exit /b 1
)

> "%PSF%" echo param($R,$M)
>> "%PSF%" echo $R=$R.TrimEnd('\')
>> "%PSF%" echo $LP='\\?\'+$R
>> "%PSF%" echo $L=$R.Length+1
>> "%PSF%" echo $O=New-Object System.Collections.ArrayList
>> "%PSF%" echo foreach($f in [System.IO.Directory]::EnumerateFiles($LP,'*',[System.IO.SearchOption]::AllDirectories)){
>> "%PSF%" echo   if($f.Substring(4) -eq $M){continue}
>> "%PSF%" echo   $fi=New-Object System.IO.FileInfo $f
>> "%PSF%" echo   $s=$fi.Length.ToString()
>> "%PSF%" echo   $t=$fi.LastWriteTime.ToString('yyyyMMddHHmmss')
>> "%PSF%" echo   $r=$f.Substring(4+$L)
>> "%PSF%" echo   if($r -like 'bun\*'){continue}
>> "%PSF%" echo   [void]$O.Add($s+'^|'+$t+'^|'+$r)
>> "%PSF%" echo }
>> "%PSF%" echo [System.IO.File]::WriteAllLines($M,[string[]]$O)
>> "%PSF%" echo Write-Host "Manifest: $($O.Count) entries"

> "%PSC%" echo param($R,$M)
>> "%PSC%" echo $R=$R.TrimEnd('\')
>> "%PSC%" echo $LP='\\?\'+$R
>> "%PSC%" echo $Mfull=$M
>> "%PSC%" echo if(-not [System.IO.File]::Exists($Mfull)){Write-Host "No manifest found";exit}
>> "%PSC%" echo $L=$R.Length+1
>> "%PSC%" echo $T=New-Object 'System.Collections.Generic.Dictionary[string,object]' ^([System.StringComparer]::OrdinalIgnoreCase^)
>> "%PSC%" echo Get-Content -LiteralPath $Mfull -E UTF8 ^| ForEach-Object {
>> "%PSC%" echo   $line=$_.TrimStart([char]0xFEFF)
>> "%PSC%" echo   $p=$line -split '\^|',3
>> "%PSC%" echo   if($p.Length -eq 3 -and $p[0] -match '^\d+$'){$T[$p[2]]=@([long]$p[0],$p[1])}
>> "%PSC%" echo }
>> "%PSC%" echo Write-Host "Manifest: $($T.Count) entries"
>> "%PSC%" echo $delCount=0;$keepCount=0;$failCount=0
>> "%PSC%" echo foreach($f in [System.IO.Directory]::EnumerateFiles($LP,'*',[System.IO.SearchOption]::AllDirectories)){
>> "%PSC%" echo   if($f.Substring(4) -eq $Mfull){continue}
>> "%PSC%" echo   $rel=$f.Substring(4+$L)
>> "%PSC%" echo   if($rel -like 'bun\*'){continue}
>> "%PSC%" echo   if(-not $T.ContainsKey($rel)){$keepCount++;continue}
>> "%PSC%" echo   $o=$T[$rel]
>> "%PSC%" echo   $fi=New-Object System.IO.FileInfo $f
>> "%PSC%" echo   if($fi.Length -ne $o[0]){$keepCount++;continue}
>> "%PSC%" echo   if($fi.LastWriteTime.ToString('yyyyMMddHHmmss') -ne $o[1]){$keepCount++;continue}
>> "%PSC%" echo   try{[System.IO.File]::Delete($f);$delCount++}catch{$failCount++}
>> "%PSC%" echo }
>> "%PSC%" echo Write-Host "Deleted files: $delCount / Kept: $keepCount / Failed: $failCount"
>> "%PSC%" echo $emptyCount=0
>> "%PSC%" echo foreach($d in ([System.IO.Directory]::EnumerateDirectories($LP,'*',[System.IO.SearchOption]::AllDirectories) ^| Sort-Object Length -Descending)){
>> "%PSC%" echo   $rel=$d.Substring(4+$L)
>> "%PSC%" echo   if($rel -like 'bun*'){continue}
>> "%PSC%" echo   try{
>> "%PSC%" echo     $c=[System.IO.Directory]::GetFileSystemEntries($d)
>> "%PSC%" echo     if($c.Count -eq 0){[System.IO.Directory]::Delete($d);$emptyCount++}
>> "%PSC%" echo   }catch{}
>> "%PSC%" echo }
>> "%PSC%" echo Write-Host "Deleted empty folders: $emptyCount"
>> "%PSC%" echo try{[System.IO.File]::Delete($Mfull);Write-Host "Manifest deleted"}catch{Write-Host "Could not delete manifest: $($_.Exception.Message)"}

if not exist "%TEMPDIR%\package.json" (
    echo [+] Svelte project missing, extracting...
    if exist "%TEMPDIR%" rmdir /s /q "%TEMPDIR%" 2>nul
    mkdir "%TEMPDIR%"
    "%SEVENZIP%" x "%ARCHIVE%" -o"%TEMPDIR%" -y >nul

    echo [+] Creating manifest...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PSF%" "%TEMPDIR%" "%MANIFEST%"
) else (
    echo [+] Svelte project found, skipping extraction.
)

if not exist "%BUNDIR%\bun.exe" (
    echo [+] Extracting Bun from Bun\master.7z...
    if exist "%BUNDIR%" rmdir /s /q "%BUNDIR%" 2>nul
    mkdir "%BUNDIR%"
    "%SEVENZIP%" x "%BUNARCHIVE%" -o"%BUNDIR%" -y >nul
) else (
    echo [+] bun.exe found, skipping extraction.
)

set "BUN_INSTALL=%BUNDIR%"
set "PATH=%BUNDIR%;%BUNDIR%\bin;%TEMPDIR%\node_modules\.bin;%PATH%"

cls
echo ====================================
echo  Svelte ready (Bun runtime)
echo  bun --version
echo  bunx vite
echo  Type 'exit' to exit
echo ====================================
cmd /k

:CLEANUP_MENU
cls
echo ====================================
echo  [0] Keep
echo  [1] Delete origin (keep changes)
echo  [2] Delete all
echo  [3] Save to archive + Delete
echo ====================================
set "C="
set /p "C=Choose (0-3): "
if not defined C goto CLEANUP_MENU

if "!C!"=="0" goto END

if "!C!"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PSC%" "%TEMPDIR%" "%MANIFEST%"
    if exist "%BUNDIR%" rmdir /s /q "%BUNDIR%" 2>nul
    goto END
)

if "!C!"=="2" (
    if exist "%TEMPDIR%" rmdir /s /q "%TEMPDIR%" 2>nul
    goto END
)

if "!C!"=="3" (
    if exist "%MANIFEST%" del /q "%MANIFEST%" 2>nul
    if exist "%BUNDIR%" rmdir /s /q "%BUNDIR%" 2>nul
    cd /d "%TEMPDIR%"
    del /q "%ARCHIVE%" 2>nul
    "%SEVENZIP%" a -t7z -mx=9 "%ARCHIVE%" "node_modules" "package.json" "bun.lock" "vite.config.js" "tsconfig.json" "index.ts" >nul
    cd /d "%ROOT%"
    rmdir /s /q "%TEMPDIR%" 2>nul
    goto END
)

echo Invalid choice!
pause >nul & cls & goto CLEANUP_MENU

:END
del "%PSF%" 2>nul
del "%PSC%" 2>nul
pause