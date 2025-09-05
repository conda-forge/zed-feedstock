@echo off
setlocal enabledelayedexpansion

REM Extract source if needed
if not exist Cargo.toml (
    echo Extracting source files...
    xcopy /E /I /H /Y "%SRC_DIR%\..\..\..\src_cache\test_extract\zed-%PKG_VERSION%\*" "%SRC_DIR%\" || (
        echo ERROR: Failed to extract source files
        exit /b 1
    )
)

REM Create Menu directory and copy icons
mkdir "%PREFIX%\Menu" 2>nul
copy "%RECIPE_DIR%\menu.json" "%PREFIX%\Menu\%PKG_NAME%_menu.json" || (
    echo ERROR: Failed to copy menu.json
    exit /b 1
)
copy "crates\zed\resources\app-icon.png" "%PREFIX%\Menu\zed.png" || (
    echo ERROR: Failed to copy app icon
    exit /b 1
)

REM Set build environment variables
set ZED_UPDATE_EXPLANATION=Please use your package manager to update zed from conda-forge
set CARGO_PROFILE_RELEASE_DEBUG=false
set RUSTFLAGS=-C linker=lld-link.exe

REM Detect Spectre-mitigated MSVC libraries and configure accordingly
set "SPECTRE_ENABLED="
set "_VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

REM Allow user/CI to provide explicit spectre libs dir
if not "%SPECTRE_LIBS_DIR%"=="" (
    if exist "%SPECTRE_LIBS_DIR%" (
        set "LIB=%SPECTRE_LIBS_DIR%;%LIB%"
        set "SPECTRE_ENABLED=1"
    )
)

REM Auto-detect spectre libs via vswhere if not provided
if "%SPECTRE_ENABLED%"=="" if exist "%_VSWHERE%" (
    for /f "usebackq tokens=*" %%I in (`"%_VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "_VS=%%I"
    if not "%_VS%"=="" (
        for /f "usebackq tokens=*" %%V in (`dir /b /ad "%_VS%\VC\Tools\MSVC"`) do set "_MSVCVER=%%V"
        if exist "%_VS%\VC\Tools\MSVC\%_MSVCVER%\lib\x64\spectre" (
            set "LIB=%_VS%\VC\Tools\MSVC\%_MSVCVER%\lib\x64\spectre;%LIB%"
            set "SPECTRE_ENABLED=1"
        )
    )
)

REM If Spectre libs are present, ensure C/C++ builds use /Qspectre
if "%SPECTRE_ENABLED%"=="1" (
    echo Using Spectre-mitigated MSVC libraries
    set "CFLAGS_x86_64-pc-windows-msvc=/Qspectre %CFLAGS_x86_64-pc-windows-msvc%"
    set "CXXFLAGS_x86_64-pc-windows-msvc=/Qspectre %CXXFLAGS_x86_64-pc-windows-msvc%"
) else (
    echo Spectre-mitigated libs not found; scrubbing /Qspectre from build scripts
    REM Best-effort removal of /Qspectre from any build.rs files to avoid LNK2038 mismatches
    for /f "delims=" %%F in ('powershell -NoProfile -Command "Get-ChildItem -Recurse -Filter build.rs -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }"') do (
        powershell -NoProfile -Command "(Get-Content -Raw '%%F') -replace '/Qspectre','' | Set-Content -NoNewline '%%F'" 2>nul
    )

    REM Patch msvc_spectre_libs crate to disable hard error when spectre libs are missing
    set "_ROOT=%CD%"
    set "_CRATE_NAME=msvc_spectre_libs"
    set "_CRATE_VER="
    if exist "%_ROOT%\Cargo.lock" (
        for /f "usebackq tokens=1,3" %%A in (`powershell -NoProfile -Command "Select-String -Path '%_ROOT%\Cargo.lock' -Pattern '^name = \"%_CRATE_NAME%\"$' -Context 0,2 | ForEach-Object { $_.Context.PostContext | Where-Object { $_ -match '^version = ' } } | ForEach-Object { $_.ToString().Trim() }"`) do (
            set "_CRATE_VER=%%B"
        )
        if not "%_CRATE_VER%"=="" (
            set "_CRATE_VER=%_CRATE_VER:version = \"=%"
            set "_CRATE_VER=%_CRATE_VER:\"=%"
        )
    )
    if "%_CRATE_VER%"=="" set "_CRATE_VER=0.1.3"

    echo Will vendor %_CRATE_NAME% v%_CRATE_VER% to disable panic
    set "_VENDOR_DIR=%_ROOT%\vendor\%_CRATE_NAME%-%_CRATE_VER%"
    if not exist "%_ROOT%\vendor" mkdir "%_ROOT%\vendor" 2>nul
    powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; Remove-Item -Recurse -Force '%_VENDOR_DIR%' 2>$null" >nul 2>&1
    powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $n='%_CRATE_NAME%'; $v='%_CRATE_VER%'; $u=\"https://crates.io/api/v1/crates/$n/$v/download\"; $dst=Join-Path $env:TEMP \"$n-$v.crate\"; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $dst; New-Item -ItemType Directory -Force -Path '%_VENDOR_DIR%' | Out-Null; tar -xf $dst -C '%_VENDOR_DIR%'"
    if exist "%_VENDOR_DIR%\build.rs" (
        powershell -NoProfile -Command "(Get-Content -Raw '%_VENDOR_DIR%\build.rs') -replace '\#\[cfg\(feature = \"error\"\)\]', '#[cfg(any())]' | Set-Content -NoNewline '%_VENDOR_DIR%\build.rs'"
    )
    if exist "%_ROOT%\Cargo.toml" (
        powershell -NoProfile -Command "$p='[patch.crates-io]\n%_CRATE_NAME% = { path = \"vendor/%_CRATE_NAME%-%_CRATE_VER%\" }\n'; $f='%_ROOT%\Cargo.toml'; $t=Get-Content -Raw $f; if ($t -notmatch '\n\[patch\\.crates-io\]') { Add-Content -Path $f -Value "`n$p" } else { if ($t -notmatch '%_CRATE_NAME%\s*=\s*\{[^{]*vendor/%_CRATE_NAME%-%_CRATE_VER%') { Add-Content -Path $f -Value "`n$p" } }"
    )
)

REM Use temp directory for build artifacts to avoid path length issues
set "TEMP_BUILD_DIR=%TEMP%\zed-build-%RANDOM%"
set "TEMP_CARGO_HOME=C:\zc%RANDOM%"
set CARGO_TARGET_DIR=%TEMP_BUILD_DIR%
set CARGO_HOME=%TEMP_CARGO_HOME%

echo Using temporary build directory: %CARGO_TARGET_DIR%
echo Using temporary cargo home: %CARGO_HOME%

REM Create temporary directories
mkdir "%CARGO_TARGET_DIR%" 2>nul
mkdir "%CARGO_HOME%" 2>nul

REM Check if libssh2.lib exists before copying
if exist "%LIBRARY_LIB%\libssh2.lib" (
    echo Fixing ssh2 library name mismatch...
    copy "%LIBRARY_LIB%\libssh2.lib" "%LIBRARY_LIB%\ssh2.lib" || (
        echo WARNING: Failed to copy libssh2.lib to ssh2.lib
    )
) else (
    echo WARNING: libssh2.lib not found at %LIBRARY_LIB%\libssh2.lib
)

REM Generate third-party licenses
echo Generating third-party licenses...
cargo-bundle-licenses --format yaml --output THIRDPARTY.yml || (
    echo ERROR: Failed to generate third-party licenses
    goto cleanup_and_exit
)

REM Build Zed with release configuration (per official Windows development guide)
echo Building Zed (this may take a while)...
cargo build --release --locked --jobs 1 --package zed --package cli || (
    echo ERROR: Build failed
    goto cleanup_and_exit
)

REM Copy build artifacts to target location
echo Copying build artifacts...
if exist "%CARGO_TARGET_DIR%\release\zed.exe" (
    copy "%CARGO_TARGET_DIR%\release\zed.exe" "%PREFIX%\Scripts\zed.exe" || (
        echo ERROR: Failed to copy zed.exe
        goto cleanup_and_exit
    )
) else (
    echo ERROR: zed.exe not found in build output
    goto cleanup_and_exit
)

if exist "%CARGO_TARGET_DIR%\release\cli.exe" (
    copy "%CARGO_TARGET_DIR%\release\cli.exe" "%PREFIX%\Scripts\zed-cli.exe" || (
        echo ERROR: Failed to copy cli.exe
        goto cleanup_and_exit
    )
) else (
    echo WARNING: cli.exe not found in build output
)

echo Build completed successfully!
goto cleanup_and_exit

:cleanup_and_exit
REM Cleanup temporary directories
echo Cleaning up temporary files...
if exist "%CARGO_TARGET_DIR%" rmdir /s /q "%CARGO_TARGET_DIR%" 2>nul
if exist "%CARGO_HOME%" rmdir /s /q "%CARGO_HOME%" 2>nul

REM Exit with the appropriate code
if errorlevel 1 exit /b 1
exit /b 0
