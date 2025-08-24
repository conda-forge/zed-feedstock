@echo off

if not exist Cargo.toml xcopy /E /I /H /Y "%SRC_DIR%\..\..\..\src_cache\test_extract\zed-%PKG_VERSION%\*" "%SRC_DIR%\"

mkdir "%PREFIX%\Menu"
copy "%RECIPE_DIR%\menu.json" "%PREFIX%\Menu\%PKG_NAME%_menu.json"
copy "crates\zed\resources\app-icon.png" "%PREFIX%\Menu\zed.png"

set CARGO_PROFILE_RELEASE_STRIP=symbols
set ZED_UPDATE_EXPLANATION=Please use your package manager to update zed from conda-forge
set CARGO_TARGET_DIR=C:\b

REM Enable incremental compilation to reduce memory usage
set CARGO_INCREMENTAL=1

REM Limit parallel jobs to prevent memory exhaustion
set CARGO_BUILD_JOBS=2

REM Fix Windows long path issues by setting short CARGO_HOME
set CARGO_HOME=C:\c

REM Create cargo config to use short paths and optimize memory usage
if not exist "%SRC_DIR%\.cargo" mkdir "%SRC_DIR%\.cargo"
echo [build] > "%SRC_DIR%\.cargo\config.toml"
echo target-dir = "C:\\b" >> "%SRC_DIR%\.cargo\config.toml"
echo jobs = 2 >> "%SRC_DIR%\.cargo\config.toml"
echo incremental = true >> "%SRC_DIR%\.cargo\config.toml"
echo [registries.crates-io] >> "%SRC_DIR%\.cargo\config.toml"
echo protocol = "sparse" >> "%SRC_DIR%\.cargo\config.toml"
echo [net] >> "%SRC_DIR%\.cargo\config.toml"
echo git-fetch-with-cli = true >> "%SRC_DIR%\.cargo\config.toml"

REM Enable Windows long path support
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f >nul 2>&1

REM Configure aws-lc-sys to use dynamic CRT instead of static otherwise we are getting linking errors
set AWS_LC_SYS_STATIC=0

REM Enable proper Spectre mitigations with /Qspectre, zed uses spectre mitigations so better to compile all their code like this
set CL=/Qspectre %CL%

cargo-bundle-licenses --format yaml --output THIRDPARTY.yml
cargo build --release --package zed --package cli --jobs 2

mkdir "%PREFIX%\bin"
mkdir "%PREFIX%\lib\zed"
copy "C:\b\release\cli.exe" "%PREFIX%\bin\zed.exe"
copy "C:\b\release\zed.exe" "%PREFIX%\lib\zed\zed-editor.exe"

rmdir /s /q C:\b
rmdir /s /q C:\c
rmdir /s /q "%SRC_DIR%\.cargo"
