#!/usr/bin/env bash

set -o xtrace -o nounset -o pipefail -o errexit

# Install shell completions
mkdir -p "${PREFIX}/share/bash-completion/completions"
install -m0755 "${RECIPE_DIR}/completions/zed.bash" "${PREFIX}/share/bash-completion/completions/zed"

# Install menuinst
mkdir -p "${PREFIX}/Menu"
if [[ ${OSTYPE} == "darwin"* ]]; then
    sed -e "s/__PKG_VERSION__/${PKG_VERSION}/g" -e "s/__PKG_MAJOR_VER__/${PKG_VERSION%%.*}/g" "${RECIPE_DIR}/menu.json" > "${PREFIX}/Menu/${PKG_NAME}_menu.json"
    install -m0644 "${RECIPE_DIR}/zed.icns" "${PREFIX}/Menu/zed.icns"
else
    install -m0644 "${RECIPE_DIR}/menu.json" "${PREFIX}/Menu/${PKG_NAME}_menu.json"
    install -m0644 "crates/zed/resources/app-icon.png" "${PREFIX}/Menu/zed.png"
fi

if [[ ${target_platform} == "osx-arm64" && "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_PREFIX_PATH=${PREFIX}"
elif [[ ${OSTYPE} == "linux"* && ${build_platform} != ${target_platform} ]]; then
  export PKG_CONFIG_ALLOW_CROSS=1
fi

# Set Cargo build profile
# LTO=thin is already the default, and fat just takes too much memory
export CARGO_PROFILE_RELEASE_STRIP=symbols
export CARGO_INCREMENTAL=0

if [[ ${target_platform} == "osx-arm64" ]]; then
  # Zed's macOS arm64 binary is large enough to hit branch-island issues in
  # the default conda-forge Darwin linker. Use LLD's Mach-O linker instead.
  export CARGO_BUILD_RUSTFLAGS="${CARGO_BUILD_RUSTFLAGS:-} -C link-arg=-fuse-ld=lld"
fi

# Set CFLAGS
export CFLAGS="${CFLAGS} -D_BSD_SOURCE"

# Disable auto updates
export ZED_UPDATE_EXPLANATION='Please use your package manager to update zed from conda-forge'

# Build package
cargo build --release --package zed --package cli --target "${CARGO_BUILD_TARGET}"

# Install package
mkdir -p "${PREFIX}/bin"
mkdir -p "${PREFIX}/lib/zed"
install -m0755 target/${CARGO_BUILD_TARGET}/release/zed "${PREFIX}/lib/zed/zed-editor"
if [[ ${OSTYPE} == "darwin"* ]]; then
    install -m0755 target/${CARGO_BUILD_TARGET}/release/cli "${PREFIX}/lib/zed/zed-cli"
    install -m0755 "${RECIPE_DIR}/zed-cli-osx.sh" "${PREFIX}/bin/zed"
else
    # https://github.com/zed-industries/zed/blob/bdedb18c300e71086a63dae1cacf3fe87c885fcf/crates/cli/src/main.rs#L416-L433
    install -m0755 target/${CARGO_BUILD_TARGET}/release/cli "${PREFIX}/bin/zed"
fi

# Install conda activation scripts to set runtime env vars
mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
install -m0755 "${RECIPE_DIR}/activate.sh" "${PREFIX}/etc/conda/activate.d/zed_activate.sh"
install -m0755 "${RECIPE_DIR}/deactivate.sh" "${PREFIX}/etc/conda/deactivate.d/zed_deactivate.sh"

# Remove target dir to save disk space
rm -rf target

# Check licenses
cargo-bundle-licenses \
    --format yaml \
    --output THIRDPARTY.yml
