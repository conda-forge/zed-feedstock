@echo off
setlocal enabledelayedexpansion

REM Create Menu directory and copy icons
mkdir "%PREFIX%\Menu" 2>nul
copy "%RECIPE_DIR%\menu.json" "%PREFIX%\Menu\%PKG_NAME%_menu.json"
copy "crates\zed\resources\app-icon.png" "%PREFIX%\Menu\zed.png"

REM Set build environment variables
set ZED_UPDATE_EXPLANATION=Please use your package manager to update zed from conda-forge
set CARGO_PROFILE_RELEASE_DEBUG=false
set CARGO_PROFILE_RELEASE_STRIP=symbols
set CARGO_PROFILE_RELEASE_LTO=thin
set CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1

REM Use temp directory for build artifacts to avoid path length issues
set "TEMP_BUILD_DIR=%TEMP%\zed-build-%RANDOM%"
set "TEMP_CARGO_HOME=C:\zc%RANDOM%"
set CARGO_TARGET_DIR=%TEMP_BUILD_DIR%
set CARGO_HOME=%TEMP_CARGO_HOME%

REM Place recipe cargo config in the workspace so Cargo resolves it.
if not exist ".cargo" mkdir ".cargo" 2>nul
copy /Y "%RECIPE_DIR%\config.toml" ".cargo\config.toml"

REM Keep RUSTFLAGS empty so cargo target config controls CRT mode.
set RUSTFLAGS=

REM Match aws-lc-sys CMake runtime with static CRT linkage.
set AWS_LC_SYS_USE_CMAKE=1
set AWS_LC_SYS_CMAKE_VARIABLES=CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded;BUILD_SHARED_LIBS=OFF
set RING_USE_CMAKE=1

REM Check if libssh2.lib exists before copying
if exist "%LIBRARY_LIB%\libssh2.lib" (
    copy "%LIBRARY_LIB%\libssh2.lib" "%LIBRARY_LIB%\ssh2.lib"
)

set "BUILD_EXIT=0"
cargo-bundle-licenses --format yaml --output THIRDPARTY.yml
if errorlevel 1 (
    set "BUILD_EXIT=!errorlevel!"
    goto :cleanup
)

cargo install --root "%PREFIX%" --path crates/zed --locked --no-default-features --features "" --profile release
if errorlevel 1 (
    set "BUILD_EXIT=!errorlevel!"
    goto :cleanup
)

if not exist "%PREFIX%\bin\zed.exe" (
    echo ERROR: cargo install completed but "%PREFIX%\bin\zed.exe" was not produced.
    set "BUILD_EXIT=1"
)

:cleanup
REM Cleanup temporary directories
if exist "%CARGO_TARGET_DIR%" rmdir /s /q "%CARGO_TARGET_DIR%" 2>nul
if exist "%CARGO_HOME%" rmdir /s /q "%CARGO_HOME%" 2>nul
exit /b %BUILD_EXIT%
