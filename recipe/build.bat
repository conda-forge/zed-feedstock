@echo off

if not exist Cargo.toml xcopy /E /I /H /Y "%SRC_DIR%\..\..\..\src_cache\test_extract\zed-%PKG_VERSION%\*" "%SRC_DIR%\"

mkdir "%PREFIX%\Menu"
copy "%RECIPE_DIR%\menu.json" "%PREFIX%\Menu\%PKG_NAME%_menu.json"
copy "crates\zed\resources\app-icon.png" "%PREFIX%\Menu\zed.png"

set CARGO_PROFILE_RELEASE_STRIP=symbols
set ZED_UPDATE_EXPLANATION=Please use your package manager to update zed from conda-forge
set CARGO_TARGET_DIR=C:\b

REM Reduce parallel jobs to minimize memory usage (was 2, now 1)
set CARGO_BUILD_JOBS=1

REM Fix Windows long path issues by setting short CARGO_HOME
set CARGO_HOME=C:\c

REM Create cargo config to use short paths and optimize memory usage
if not exist "%SRC_DIR%\.cargo" mkdir "%SRC_DIR%\.cargo"
copy "%RECIPE_DIR%\config.toml" "%SRC_DIR%\.cargo\config.toml"

REM Enable proper Spectre mitigations with /Qspectre, zed uses spectre mitigations so better to compile all their code like this
set CL=/Qspectre %CL%

REM Force static MSVC CRT via Rust flags
set RUSTFLAGS=-Ctarget-feature=+crt-static

cargo-bundle-licenses --format yaml --output THIRDPARTY.yml
cargo build --release --package zed --package cli

mkdir "%PREFIX%\bin"
mkdir "%PREFIX%\Library\bin"
mkdir "%PREFIX%\Scripts"
mkdir "%PREFIX%\lib\zed"
copy "C:\b\release\cli.exe" "%PREFIX%\Library\bin\zed.exe"
copy "C:\b\release\cli.exe" "%PREFIX%\Scripts\zed.exe"
copy "C:\b\release\zed.exe" "%PREFIX%\lib\zed\zed-editor.exe"

rmdir /s /q C:\b
rmdir /s /q C:\c
rmdir /s /q "%SRC_DIR%\.cargo"
