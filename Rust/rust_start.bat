@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
set "ARCHIVE=%ROOT%master.7z"
set "TEMPDIR=%ROOT%.env"
set "GCCDIR=%TEMPDIR%\_gcc"
set "GCCARCHIVE=%ROOT%..\W64DevKit\master.7z"
set "MANIFEST=%TEMPDIR%\.manifest"
set "SEVENZIP=C:\Program Files\7-Zip\7z.exe"
set "PSF=%TEMP%\_m%RANDOM%.ps1"
set "PSC=%TEMP%\_c%RANDOM%.ps1"

set "HEAVY_EXCLUDE=-xr!rustc_driver-*.dll -xr!rust-lld.exe -xr!rust-objcopy.exe -xr!libcore-*.rmeta -xr!cargo.exe"

if not exist "%ARCHIVE%" (
    echo [ERROR] %ARCHIVE% not found!
    pause & exit /b 1
)

if not exist "%GCCARCHIVE%" (
    echo [ERROR] w64devkit not found at %GCCARCHIVE%
    pause & exit /b 1
)

> "%PSF%" echo param($R,$M)
>> "%PSF%" echo $R=$R.TrimEnd('\')
>> "%PSF%" echo $LP='\\?\'+$R
>> "%PSF%" echo $L=$R.Length+1
>> "%PSF%" echo $O=New-Object System.Collections.ArrayList
>> "%PSF%" echo foreach($f in [System.IO.Directory]::EnumerateFiles($LP,'*',[System.IO.SearchOption]::AllDirectories)){
>> "%PSF%" echo    if($f.Substring(4) -eq $M){continue}
>> "%PSF%" echo    $fi=New-Object System.IO.FileInfo $f
>> "%PSF%" echo    $s=$fi.Length.ToString()
>> "%PSF%" echo    $t=$fi.LastWriteTime.ToString('yyyyMMddHHmmss')
>> "%PSF%" echo    $r=$f.Substring(4+$L)
>> "%PSF%" echo    if($r -like '_gcc\*'){continue}
>> "%PSF%" echo    $h=''
>> "%PSF%" echo    if($fi.Length -lt 10485760){$h=(Get-FileHash $f -A MD5 -EA 0).Hash}
>> "%PSF%" echo    [void]$O.Add($s+'^|'+$t+'^|'+$h+'^|'+$r)
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
>> "%PSC%" echo    $line=$_.TrimStart([char]0xFEFF)
>> "%PSC%" echo    $p=$line -split '\^|',4
>> "%PSC%" echo    if($p.Length -eq 4 -and $p[0] -match '^\d+$'){$T[$p[3]]=@([long]$p[0],$p[1],$p[2])}
>> "%PSC%" echo }
>> "%PSC%" echo Write-Host "Manifest: $($T.Count) entries"
>> "%PSC%" echo $delCount=0;$keepCount=0;$failCount=0
>> "%PSC%" echo foreach($f in [System.IO.Directory]::EnumerateFiles($LP,'*',[System.IO.SearchOption]::AllDirectories)){
>> "%PSC%" echo    if($f.Substring(4) -eq $Mfull){continue}
>> "%PSC%" echo    $rel=$f.Substring(4+$L)
>> "%PSC%" echo    if($rel -like '_gcc\*'){continue}
>> "%PSC%" echo    if(-not $T.ContainsKey($rel)){$keepCount++;continue}
>> "%PSC%" echo    $o=$T[$rel]
>> "%PSC%" echo    $fi=New-Object System.IO.FileInfo $f
>> "%PSC%" echo    if($fi.Length -ne $o[0]){$keepCount++;continue}
>> "%PSC%" echo    if([string]::IsNullOrEmpty($o[2])){
>> "%PSC%" echo      try{[System.IO.File]::Delete($f);$delCount++}catch{$failCount++}
>> "%PSC%" echo      continue
>> "%PSC%" echo    }
>> "%PSC%" echo    if($fi.LastWriteTime.ToString('yyyyMMddHHmmss') -ne $o[1]){$keepCount++;continue}
>> "%PSC%" echo    $h=(Get-FileHash $f -A MD5 -EA 0).Hash
>> "%PSC%" echo    if($h -ne $o[2]){$keepCount++;continue}
>> "%PSC%" echo    try{[System.IO.File]::Delete($f);$delCount++}catch{$failCount++}
>> "%PSC%" echo }
>> "%PSC%" echo Write-Host "Deleted files: $delCount / Kept: $keepCount / Failed: $failCount"
>> "%PSC%" echo $emptyCount=0
>> "%PSC%" echo foreach($d in ([System.IO.Directory]::EnumerateDirectories($LP,'*',[System.IO.SearchOption]::AllDirectories) ^| Sort-Object Length -Descending)){
>> "%PSC%" echo    $rel=$d.Substring(4+$L)
>> "%PSC%" echo    if($rel -like '_gcc*'){continue}
>> "%PSC%" echo    try{
>> "%PSC%" echo      $c=[System.IO.Directory]::GetFileSystemEntries($d)
>> "%PSC%" echo      if($c.Count -eq 0){[System.IO.Directory]::Delete($d);$emptyCount++}
>> "%PSC%" echo    }catch{}
>> "%PSC%" echo }
>> "%PSC%" echo Write-Host "Deleted empty folders: $emptyCount"
>> "%PSC%" echo try{[System.IO.File]::Delete($Mfull);Write-Host "Manifest deleted"}catch{Write-Host "Could not delete manifest: $($_.Exception.Message)"}

if not exist "%TEMPDIR%\.cargo\bin\cargo.exe" (
    echo [+] cargo.exe missing, extracting Rust...
    if exist "%TEMPDIR%" rmdir /s /q "%TEMPDIR%" 2>nul
    mkdir "%TEMPDIR%"
    "%SEVENZIP%" x "%ARCHIVE%" -o"%TEMPDIR%" -y >nul

    mkdir "%TEMPDIR%\home" 2>nul

    echo [+] Creating manifest...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PSF%" "%TEMPDIR%" "%MANIFEST%"

    if exist "%MANIFEST%" (
        for %%A in ("%MANIFEST%") do echo [+] Manifest OK: %%~za bytes
    ) else (
        echo [!] Manifest creation failed!
        pause
    )
) else (
    echo [+] cargo.exe found, skipping Rust extraction.
)

if not exist "%GCCDIR%\bin\gcc.exe" (
    echo [+] Extracting W64DevKit from W64DevKit\master.7z...
    if exist "%GCCDIR%" rmdir /s /q "%GCCDIR%" 2>nul
    mkdir "%GCCDIR%"
    "%SEVENZIP%" x "%GCCARCHIVE%" -o"%GCCDIR%" -y >nul

    echo [+] Stripping w64devkit ^(keeping required Rust components only^)...

    del /q "%GCCDIR%\bin\g++.exe" 2>nul
    del /q "%GCCDIR%\bin\c++.exe" 2>nul
    del /q "%GCCDIR%\bin\cpp.exe" 2>nul
    del /q "%GCCDIR%\bin\x86_64-w64-mingw32-g++.exe" 2>nul
    del /q "%GCCDIR%\bin\x86_64-w64-mingw32-c++.exe" 2>nul
    del /q "%GCCDIR%\libexec\gcc\x86_64-w64-mingw32\16.2.0\cc1plus.exe" 2>nul

    rmdir /s /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\include\c++" 2>nul
    del /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\libstdc++*" 2>nul
    del /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\libsupc++*" 2>nul

    del /q "%GCCDIR%\bin\gfortran.exe" 2>nul
    del /q "%GCCDIR%\libexec\gcc\x86_64-w64-mingw32\16.2.0\f951.exe" 2>nul
    del /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\libgfortran*" 2>nul
    del /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\libgomp*" 2>nul
    del /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\libgcov*" 2>nul
    del /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\libcaf_*" 2>nul
    rmdir /s /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\finclude" 2>nul

    rmdir /s /q "%GCCDIR%\include" 2>nul
    rmdir /s /q "%GCCDIR%\x86_64-w64-mingw32\include" 2>nul

    del /q "%GCCDIR%\bin\gdb.exe" 2>nul
    del /q "%GCCDIR%\bin\gcov.exe" 2>nul
    del /q "%GCCDIR%\bin\gcov-tool.exe" 2>nul
    del /q "%GCCDIR%\bin\gprof.exe" 2>nul
    del /q "%GCCDIR%\bin\ctags.exe" 2>nul
    del /q "%GCCDIR%\bin\quilt.exe" 2>nul
    del /q "%GCCDIR%\bin\aas-sign.exe" 2>nul
    del /q "%GCCDIR%\bin\ccache.exe" 2>nul

    rmdir /s /q "%GCCDIR%\share" 2>nul
    rmdir /s /q "%GCCDIR%\src" 2>nul
    rmdir /s /q "%GCCDIR%\etc" 2>nul
    rmdir /s /q "%GCCDIR%\lib32" 2>nul
    rmdir /s /q "%GCCDIR%\lib\ccache" 2>nul
    rmdir /s /q "%GCCDIR%\lib\bfd-plugins" 2>nul
    rmdir /s /q "%GCCDIR%\lib\pkgconfig" 2>nul
    rmdir /s /q "%GCCDIR%\libexec\gcc\x86_64-w64-mingw32\16.2.0\install-tools" 2>nul
    rmdir /s /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\include-fixed" 2>nul
    del /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\*.la" 2>nul
    del /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\*.modules.json" 2>nul
    del /q "%GCCDIR%\lib\gcc\x86_64-w64-mingw32\16.2.0\libstdc++.a-gdb.py" 2>nul

    echo [+] Stripping complete.
) else (
    echo [+] gcc.exe found inside _gcc, skipping w64devkit extraction.
)

set "RUSTUP_HOME=%TEMPDIR%\.rustup"
set "CARGO_HOME=%TEMPDIR%\.cargo"
set "HOME=%TEMPDIR%\home"
set "CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=gcc"
set "PATH=%TEMPDIR%\.cargo\bin;%GCCDIR%\bin;%PATH%"

cls
echo ====================================
echo  Rust ready (GNU toolchain)
echo  cargo --version
echo  rustc --version
echo  gcc --version
echo  HOME = %HOME%
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
    echo [+] Comparing size + mtime + hash...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PSC%" "%TEMPDIR%" "%MANIFEST%"
    echo [+] Deleting _gcc...
    if exist "%GCCDIR%" rmdir /s /q "%GCCDIR%" 2>nul
    goto END
)

if "!C!"=="2" (
    if exist "%TEMPDIR%" rmdir /s /q "%TEMPDIR%" 2>nul
    goto END
)

if "!C!"=="3" (
    if exist "%MANIFEST%" del /q "%MANIFEST%" 2>nul
    if exist "%TEMPDIR%\home\.cargo" rmdir /s /q "%TEMPDIR%\home\.cargo" 2>nul
    if exist "%TEMPDIR%\.rustup\downloads" rmdir /s /q "%TEMPDIR%\.rustup\downloads" 2>nul
    if exist "%TEMPDIR%\.rustup\tmp" rmdir /s /q "%TEMPDIR%\.rustup\tmp" 2>nul
    if exist "%GCCDIR%" rmdir /s /q "%GCCDIR%" 2>nul
    cd /d "%TEMPDIR%"
    if exist "%ARCHIVE%" (
        echo [+] Updating master.7z ^(keeping heavy files, updating light files only^)...
        "%SEVENZIP%" u -t7z -mx=9 "%ARCHIVE%" ".rustup" ".cargo" "home" !HEAVY_EXCLUDE!
    ) else (
        echo [+] Creating new master.7z...
        "%SEVENZIP%" a -t7z -mx=9 "%ARCHIVE%" ".rustup" ".cargo" "home"
    )
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