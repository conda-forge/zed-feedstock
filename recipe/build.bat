@echo off

if not exist Cargo.toml xcopy /E /I /H /Y "%SRC_DIR%\..\..\..\src_cache\test_extract\zed-%PKG_VERSION%\*" "%SRC_DIR%\"

mkdir "%PREFIX%\Menu"
copy "%RECIPE_DIR%\menu.json" "%PREFIX%\Menu\%PKG_NAME%_menu.json"
copy "crates\zed\resources\app-icon.png" "%PREFIX%\Menu\zed.png"

set ZED_UPDATE_EXPLANATION=Please use your package manager to update zed from conda-forge
set CARGO_TARGET_DIR=C:\b

REM Fix Windows long path issues by setting short CARGO_HOME
set CARGO_HOME=C:\c

REM Configure aws_lc_sys for static linking compatibility  
set AWS_LC_SYS_STATIC=1
set AWS_LC_SYS_PREBUILT_NASM=1
set AWS_LC_SYS_CMAKE_BUILDER=1

REM Create cargo config to use short paths and optimize memory usage
if not exist "%SRC_DIR%\.cargo" mkdir "%SRC_DIR%\.cargo"
copy "%RECIPE_DIR%\config.toml" "%SRC_DIR%\.cargo\config.toml"

REM Fix ssh2 library name mismatch - Rust expects ssh2.lib but conda-forge provides libssh2.lib
copy "%LIBRARY_LIB%\libssh2.lib" "%LIBRARY_LIB%\ssh2.lib"

cargo-bundle-licenses --format yaml --output THIRDPARTY.yml
cargo build --release --locked --package zed --package cli

rmdir /s /q C:\b
rmdir /s /q C:\c
rmdir /s /q "%SRC_DIR%\.cargo"
