@echo off

if not exist Cargo.toml xcopy /E /I /H /Y "%SRC_DIR%\..\..\..\src_cache\test_extract\zed-%PKG_VERSION%\*" "%SRC_DIR%\"

mkdir "%PREFIX%\Menu"
copy "%RECIPE_DIR%\menu.json" "%PREFIX%\Menu\%PKG_NAME%_menu.json"
copy "crates\zed\resources\app-icon.png" "%PREFIX%\Menu\zed.png"

set CARGO_PROFILE_RELEASE_STRIP=symbols
set ZED_UPDATE_EXPLANATION=Please use your package manager to update zed from conda-forge
REM Reduce parallel jobs to minimize memory usage (was 2, now 1)
set CARGO_BUILD_JOBS=1

REM Fix ssh2 library name mismatch - Rust expects ssh2.lib but conda-forge provides libssh2.lib
copy "%LIBRARY_LIB%\libssh2.lib" "%LIBRARY_LIB%\ssh2.lib"

cargo-bundle-licenses --format yaml --output THIRDPARTY.yml
cargo build --release --locked --package zed --package cli

mkdir "%PREFIX%\bin"
mkdir "%PREFIX%\Library\bin"
mkdir "%PREFIX%\Scripts"
mkdir "%PREFIX%\lib\zed"
copy "%SRC_DIR%\target\release\cli.exe" "%PREFIX%\Library\bin\zed.exe"
copy "%SRC_DIR%\target\release\cli.exe" "%PREFIX%\Scripts\zed.exe"
copy "%SRC_DIR%\target\release\zed.exe" "%PREFIX%\lib\zed\zed-editor.exe"
