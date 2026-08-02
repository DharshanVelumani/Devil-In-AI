@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo ---------------------------------------------
echo    Devil-In AI - Windows Installer
echo    Downloads llama.cpp for Windows x64 (CPU)
echo ---------------------------------------------
echo.

:: ---------- Check for Visual C++ Runtime (VCRUNTIME140_1.dll) ---------------
if not exist "%SystemRoot%\System32\VCRUNTIME140_1.dll" (
    echo [!] Missing: VCRUNTIME140_1.dll
    echo.
    echo The llama server requires Microsoft Visual C++ Redistributable.
    echo Please download and install it from:
    echo     https://aka.ms/vs/17/release/vc_redist.x64.exe
    echo.
    echo After installation, run this script again.
    pause
    exit /b 1
)

:: ---------- Dependency check -------------------------------------------------
where curl >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] curl not found. Please install curl.
    echo     https://curl.se/windows/
    pause
    exit /b 1
)

where tar >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] tar not found. Windows 10 build 17063+ includes it.
    pause
    exit /b 1
)

:: ---------- Platform definition (Windows x64 CPU only) -----------------------
set "PLATFORM_LABEL=Windows x64 CPU"
set "PLATFORM_ASSET=win-cpu-x64.zip"
set "PLATFORM_BIN_DEST=bin\windows"
set "PLATFORM_BIN_FINAL=llama-server-win.exe"

echo ---------------------------------------------
echo Platform: %PLATFORM_LABEL%
echo ---------------------------------------------
echo.

:: ---------- Fetch latest release from GitHub API -----------------------------
echo [*] Fetching latest llama.cpp release metadata...

set "RELEASE_TAG="
set "RELEASE_INFO_FILE=%TEMP%\llama_release_info_%RANDOM%.json"

powershell -NoProfile -Command ^
    "try { $r = Invoke-RestMethod -Uri 'https://api.github.com/repos/ggml-org/llama.cpp/releases/latest' -Headers @{'Accept'='application/vnd.github+json'; 'User-Agent'='PortableAI-Installer'}; $r | ConvertTo-Json -Depth 5 | Set-Content -Path '%RELEASE_INFO_FILE%' -Encoding UTF8 } catch { exit 1 }" 2>nul

if not exist "%RELEASE_INFO_FILE%" (
    echo [!] Failed to reach GitHub API. Check your internet connection or API rate limit.
    pause
    exit /b 1
)

:: Extract tag and matching asset URL cleanly using PowerShell
set "ASSET_URL="
set "ASSET_FILENAME="

for /f "usebackq tokens=1,* delims==" %%a in (`powershell -NoProfile -Command ^
    "$json = Get-Content '%RELEASE_INFO_FILE%' | ConvertFrom-Json; Write-Output ('TAG=' + $json.tag_name); $asset = $json.assets | Where-Object name -like '*win-cpu-x64.zip*' | Where-Object name -notmatch 'cuda|vulkan|rocm|kompute|sycl|opencl|mpi|openvino' | Select-Object -First 1; if ($asset) { Write-Output ('URL=' + $asset.browser_download_url); Write-Output ('NAME=' + $asset.name) }"`) do (
    if "%%a"=="TAG" set "RELEASE_TAG=%%b"
    if "%%a"=="URL" set "ASSET_URL=%%b"
    if "%%a"=="NAME" set "ASSET_FILENAME=%%b"
)

del "%RELEASE_INFO_FILE%" 2>nul

if not defined RELEASE_TAG (
    echo [!] Could not parse release tag from GitHub API response.
    pause
    exit /b 1
)
echo [OK] Latest release: %RELEASE_TAG%
echo.

if not defined ASSET_URL (
    echo [!] Matching release asset (%PLATFORM_ASSET%) not found in release %RELEASE_TAG%.
    pause
    exit /b 1
)

if not exist "models" mkdir "models"
if not exist "ui"     mkdir "ui"

:: ---------- Download to TEMP -------------------------------------------------
set "TMP_DOWNLOAD=%TEMP%\%ASSET_FILENAME%"
set "TMP_EXTRACT=%TEMP%\llama_extract_win_%RANDOM%"

if exist "%TMP_EXTRACT%" rmdir /s /q "%TMP_EXTRACT%"
mkdir "%TMP_EXTRACT%"

echo [*] Downloading %ASSET_FILENAME%...
curl -L --progress-bar -o "%TMP_DOWNLOAD%" "%ASSET_URL%"
if %ERRORLEVEL% NEQ 0 (
    echo [!] Download failed.
    goto CLEANUP_FAIL
)
echo.

:: ---------- Extract into TEMP ------------------------------------------------
echo [*] Extracting package...

powershell -NoProfile -Command "Expand-Archive -Path '%TMP_DOWNLOAD%' -DestinationPath '%TMP_EXTRACT%' -Force" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] Zip extraction failed.
    goto CLEANUP_FAIL
)

:: Flatten directory structure if llama-server.exe is inside a subdirectory
powershell -NoProfile -Command ^
    "$serverFile = Get-ChildItem -Path '%TMP_EXTRACT%' -Recurse -Filter 'llama-server.exe' | Select-Object -First 1; if ($serverFile -and $serverFile.DirectoryName -ne '%TMP_EXTRACT%') { Get-ChildItem -Path $serverFile.DirectoryName -Recurse | Copy-Item -Destination '%TMP_EXTRACT%' -Force }" 2>nul

:: Resolve symlinks for filesystem portability
echo [*] Processing files for portability...
powershell -NoProfile -Command ^
    "Get-ChildItem '%TMP_EXTRACT%' -Recurse -Force | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint } | ForEach-Object { try { $link = $_.FullName; $target = $_.Target; if (-not [System.IO.Path]::IsPathRooted($target)) { $target = Join-Path $_.DirectoryName $target }; if (Test-Path $target -PathType Leaf) { $bytes = [System.IO.File]::ReadAllBytes($target); [System.IO.File]::WriteAllBytes($link, $bytes) } } catch {} }" 2>nul

:: ---------- Copy selective files to destination ------------------------------
if not exist "%PLATFORM_BIN_DEST%" mkdir "%PLATFORM_BIN_DEST%"

echo [*] Copying server binaries and required libraries...
powershell -NoProfile -Command ^
    "$keep = @('llama-server.exe','llama-server-impl.dll','llama.dll','llama-common.dll','ggml.dll','ggml-base.dll','mtmd.dll','libomp140.x86_64.dll'); " ^
    "$src = '%TMP_EXTRACT%'; " ^
    "$dest = '%~dp0%PLATFORM_BIN_DEST%'; " ^
    "if (-not (Test-Path -Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }; " ^
    "$copied = 0; $skipped = 0; " ^
    "Get-ChildItem -Path $src -Recurse -File | ForEach-Object { " ^
    "    if ($keep -contains $_.Name -or $_.Name -like 'ggml-cpu-*.dll') { " ^
    "        Copy-Item -Path $_.FullName -Destination (Join-Path $dest $_.Name) -Force; " ^
    "        Write-Host ('    [+] Kept: ' + $_.Name); " ^
    "        $copied++; " ^
    "    } else { " ^
    "        $skipped++; " ^
    "    } " ^
    "}; " ^
    "Write-Host ('[*] Filtering complete: ' + $copied + ' file(s) copied, ' + $skipped + ' file(s) skipped.')"


:: Rename / duplicate llama-server.exe to llama-server-win.exe
if exist "%~dp0%PLATFORM_BIN_DEST%\llama-server.exe" (
    copy /y "%~dp0%PLATFORM_BIN_DEST%\llama-server.exe" "%~dp0%PLATFORM_BIN_DEST%\%PLATFORM_BIN_FINAL%" >nul
    echo [OK] Configured executable -> %PLATFORM_BIN_FINAL%
) else (
    echo [!] llama-server binary not found in extracted archive.
    goto CLEANUP_FAIL
)

del "%TMP_DOWNLOAD%" 2>nul
rmdir /s /q "%TMP_EXTRACT%" 2>nul
echo.

:: ---------- Final summary ----------------------------------------------------
echo ---------------------------------------------
echo    Installation Complete!
echo ---------------------------------------------
echo.
echo   Release: %RELEASE_TAG%
echo.
if exist "%~dp0%PLATFORM_BIN_DEST%\%PLATFORM_BIN_FINAL%" (
    echo    [OK] %PLATFORM_LABEL% installed successfully to %PLATFORM_BIN_DEST%\%PLATFORM_BIN_FINAL%
) else (
    echo    [FAIL] Installation failed.
)

echo.
echo Next steps:
echo    1. Place a .gguf model into the models\ folder
echo    2. Run start.bat
echo.
pause
exit /b 0

:CLEANUP_FAIL
if exist "%TMP_DOWNLOAD%" del "%TMP_DOWNLOAD%" 2>nul
if exist "%TMP_EXTRACT%" rmdir /s /q "%TMP_EXTRACT%" 2>nul
echo.
echo Installation failed.
pause
exit /b 1