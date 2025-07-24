@echo on

pushd zed-%PKG_VERSION%

:: HACK: Paths can be too long for Windows when checking out source 
:: dependencies if they are nested inside the BUILD_PREFIX.
:: Here we set the CARGO_HOME to a shorter path.
set CARGO_HOME=C:\.cargo
md "%CARGO_HOME%"

:: Set Cargo build profile
:: LTO=thin is already the default, and fat just takes too much memory
set CARGO_PROFILE_RELEASE_STRIP=symbols

:: Some libraries require static linking on Windows
set RUSTFLAGS="-C target-feature=+crt-static"

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
