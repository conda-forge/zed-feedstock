#!/usr/bin/env bash

set -o xtrace -o nounset -o pipefail -o errexit
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Install menuinst
mkdir -p "${PREFIX}/Menu"
install -m0644 "${RECIPE_DIR}/menu.json" "${PREFIX}/Menu/${PKG_NAME}_menu.json"

if [[ $OSTYPE == "darwin"* ]]; then
    install -m0644 "${RECIPE_DIR}/zed.icns" "${PREFIX}/Menu/zed.icns"
else
    install -m0644 "crates/zed/resources/app-icon.png" "$PREFIX/Menu/zed.png"
fi

if [[ "$target_platform" == "osx-arm64" && "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_PREFIX_PATH=${PREFIX}"
fi

# Set Cargo build profile
# LTO=thin is already the default, and fat just takes too much memory
export CARGO_PROFILE_RELEASE_STRIP=symbols

# Check licenses
cargo-bundle-licenses \
    --format yaml \
    --output THIRDPARTY.yml
export CFLAGS="$CFLAGS -D_BSD_SOURCE"

# Disable auto updates
export ZED_UPDATE_EXPLANATION='Please use your package manager to update zed from conda-forge'

# Build package
cargo build --release --package zed --package cli --target "${CARGO_BUILD_TARGET}"

# Install package
mkdir -p "$PREFIX/bin"
install -m0755 target/${CARGO_BUILD_TARGET}/release/cli "$PREFIX/bin/zed"
mkdir -p "$PREFIX/lib/zed"
install -m0755 target/${CARGO_BUILD_TARGET}/release/zed "$PREFIX/lib/zed/zed-editor"
