@echo off
setlocal enabledelayedexpansion

REM Create Menu directory and copy icons
mkdir "%PREFIX%\Menu" 2>nul
copy "%RECIPE_DIR%\menu.json" "%PREFIX%\Menu\%PKG_NAME%_menu.json"
copy "crates\zed\resources\app-icon.png" "%PREFIX%\Menu\zed.png"

REM Set build environment variables
set ZED_UPDATE_EXPLANATION=Please use your package manager to update zed from conda-forge
set CARGO_PROFILE_RELEASE_DEBUG=false

REM Use temp directory for build artifacts to avoid path length issues
set "TEMP_BUILD_DIR=%TEMP%\zed-build-%RANDOM%"
set "TEMP_CARGO_HOME=C:\zc%RANDOM%"
set CARGO_TARGET_DIR=%TEMP_BUILD_DIR%
set CARGO_HOME=%TEMP_CARGO_HOME%

REM Copy config.toml to CARGO_HOME for cargo to use
copy "%RECIPE_DIR%\config.toml" "%CARGO_HOME%\config.toml"

REM Explicitly set target to MSVC if not provided
if "%CARGO_BUILD_TARGET%"=="" set CARGO_BUILD_TARGET=x86_64-pc-windows-msvc

REM Check if libssh2.lib exists before copying
if exist "%LIBRARY_LIB%\libssh2.lib" (
    copy "%LIBRARY_LIB%\libssh2.lib" "%LIBRARY_LIB%\ssh2.lib"
)

REM Generate third-party licenses
cargo-bundle-licenses --format yaml --output THIRDPARTY.yml

REM Build and install Zed (verbose; upstream default features)
cargo install --verbose --locked --no-track --bins --root "%PREFIX%" --path crates/zed --target %CARGO_BUILD_TARGET%
cargo install --verbose --locked --no-track --bins --root "%PREFIX%" --path crates/cli --target %CARGO_BUILD_TARGET%

REM Cleanup temporary directories
if exist "%CARGO_TARGET_DIR%" rmdir /s /q "%CARGO_TARGET_DIR%" 2>nul
if exist "%CARGO_HOME%" rmdir /s /q "%CARGO_HOME%" 2>nul
