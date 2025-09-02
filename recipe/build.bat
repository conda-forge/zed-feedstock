@echo off
setlocal enabledelayedexpansion

REM Validate required dependencies
echo Validating build environment...

REM Check for required tools
where cargo >nul 2>&1 || (echo ERROR: cargo not found in PATH && exit /b 1)
where cmake >nul 2>&1 || (echo ERROR: cmake not found in PATH && exit /b 1)

REM Install and set GNU target for Rust
echo Installing Rust GNU target...
rustup target add x86_64-pc-windows-gnu || (
    echo ERROR: Failed to install x86_64-pc-windows-gnu target
    exit /b 1
)

REM MinGW GCC toolchain will be provided by conda environment

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

REM Configure Rust flags for Windows with MinGW GCC
set RUSTFLAGS=%RUSTFLAGS% -C target-feature=+crt-static
set CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc
set CARGO_BUILD_TARGET=x86_64-pc-windows-gnu

REM Create cargo config directory and copy configuration
if not exist "%SRC_DIR%\.cargo" mkdir "%SRC_DIR%\.cargo"
copy "%RECIPE_DIR%\config.toml" "%SRC_DIR%\.cargo\config.toml" || (
    echo ERROR: Failed to copy cargo config
    goto cleanup_and_exit
)

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

REM Build Zed with release configuration using MinGW target
echo Building Zed (this may take a while)...
cargo build --release --locked --target x86_64-pc-windows-gnu --package zed --package cli --jobs 1 || (
    echo ERROR: Build failed
    goto cleanup_and_exit
)

REM Copy build artifacts to target location
echo Copying build artifacts...
if exist "%CARGO_TARGET_DIR%\x86_64-pc-windows-gnu\release\zed.exe" (
    copy "%CARGO_TARGET_DIR%\x86_64-pc-windows-gnu\release\zed.exe" "%PREFIX%\Scripts\zed.exe" || (
        echo ERROR: Failed to copy zed.exe
        goto cleanup_and_exit
    )
) else (
    echo ERROR: zed.exe not found in build output
    goto cleanup_and_exit
)

if exist "%CARGO_TARGET_DIR%\x86_64-pc-windows-gnu\release\cli.exe" (
    copy "%CARGO_TARGET_DIR%\x86_64-pc-windows-gnu\release\cli.exe" "%PREFIX%\Scripts\zed-cli.exe" || (
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
if exist "%SRC_DIR%\.cargo" rmdir /s /q "%SRC_DIR%\.cargo" 2>nul

REM Exit with the appropriate code
if errorlevel 1 exit /b 1
exit /b 0
