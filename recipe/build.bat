@echo on

pushd zed-%PKG_VERSION%

:: Make sure git can use long paths
:: This is necessary for Windows builds with long paths
git config --global core.longpaths true

:: Set Cargo build profile
:: LTO=thin is already the default, and fat just takes too much memory
set CARGO_PROFILE_RELEASE_STRIP=symbols

:: Check licenses
cargo-bundle-licenses ^
    --format yaml ^
    --output THIRDPARTY.yml

:: Build package
cargo build --release --package zed --package cli

:: Install package
mkdir "%LIBRARY_BIN%"
ren target/release/cli "%LIBRARY_BIN%/zed"
mkdir "%LIBRARY_LIB%/zed"
ren target/release/zed "%LIBRARY_LIB%/zed/zed-editor"
