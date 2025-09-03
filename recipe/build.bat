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
cargo build --verbose --release --locked --jobs 1 --package zed --package cli || (
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
