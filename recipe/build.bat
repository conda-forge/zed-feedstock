@echo off
setlocal enabledelayedexpansion

REM Create Menu directory and copy icons
mkdir "%PREFIX%\Menu" 2>nul
copy "%RECIPE_DIR%\menu.json" "%PREFIX%\Menu\%PKG_NAME%_menu.json"
copy "crates\zed\resources\app-icon.png" "%PREFIX%\Menu\zed.png"

REM Set build environment variables
set ZED_UPDATE_EXPLANATION=Please use your package manager to update zed from conda-forge
set CARGO_PROFILE_RELEASE_DEBUG=false

REM Sanitize toolchain flags to avoid MSVC CRT/linker conflicts
set RUSTFLAGS=
set CARGO_BUILD_RUSTFLAGS=
set CARGO_ENCODED_RUSTFLAGS=
set CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUSTFLAGS=
set CARGO_PROFILE_RELEASE_PANIC=abort
set CARGO_PROFILE_RELEASE_LTO=true
set CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
rem Ensure MSVC/UCRT linkage is consistent for Rust
set RUSTFLAGS=-C panic=abort -C codegen-units=1 -C link-arg=/NODEFAULTLIB:LIBCMT -C link-arg=/DEFAULTLIB:ucrt -C link-arg=/DEFAULTLIB:vcruntime -C link-arg=/DEFAULTLIB:msvcrt -C link-arg=kernel32.lib -C link-arg=advapi32.lib

REM Ensure C/C++ deps use Release and dynamic CRT (/MD)
set CMAKE_BUILD_TYPE=Release
set CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL
set CFLAGS=/O2 /MD /Zc:wchar_t /Zc:inline /permissive- /EHsc
set CXXFLAGS=/O2 /MD /Zc:wchar_t /Zc:inline /permissive- /EHsc

REM Harden CMake/MSVC configuration
set CMAKE_C_STANDARD=11
set CMAKE_C_STANDARD_REQUIRED=ON
set CMAKE_C_EXTENSIONS=OFF
set CMAKE_SYSTEM_NAME=Windows
set CMAKE_SYSTEM_PROCESSOR=x86_64
set CMAKE_GENERATOR=Ninja
set CMAKE_EXPORT_COMPILE_COMMANDS=OFF
set CMAKE_POLICY_DEFAULT_CMP0091=NEW
set CMAKE_MT=mt.exe
set CMAKE_C_COMPILER=cl.exe
set CMAKE_CXX_COMPILER=cl.exe
set CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF
set CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF
set CMAKE_FIND_USE_PACKAGE_REGISTRY=OFF
set CMAKE_PREFIX_PATH=%PREFIX%;%LIBRARY_PREFIX%
set PKG_CONFIG_PATH=%LIBRARY_PREFIX%\lib\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig
set LIB=%LIBRARY_LIB%;%LIB%
set INCLUDE=%LIBRARY_INC%;%INCLUDE%

REM Ensure NASM from conda is used for aws-lc/ring
set "NASM_PREFIX=%PREFIX%"
set PATH=%NASM_PREFIX%\Library\bin;%NASM_PREFIX%\Scripts;%PATH%
set "NASM=%NASM_PREFIX%\Library\bin\nasm.exe"
set CMAKE_ASM_NASM_COMPILER=%NASM%
set ASM_NASM=%NASM%
REM Keep earlier C standard settings consistent (already set to 11 above)
set CMAKE_GENERATOR=Ninja

REM aws-lc-sys: force use of local NASM, not prebuilt
set AWS_LC_SYS_PREBUILT_NASM=0
set AWS_LC_SYS_NO_ASM=
set AWS_LC_SYS_USE_CMAKE=1
set RING_USE_CMAKE=1
set AWS_LC_SYS_NO_VENDOR=1

REM Extra cargo target rustflags sanitization
set CARGO_TARGET_RUSTFLAGS=

REM Use temp directory for build artifacts to avoid path length issues
set "TEMP_BUILD_DIR=%TEMP%\zed-build-%RANDOM%"
set "TEMP_CARGO_HOME=C:\zc%RANDOM%"
set CARGO_TARGET_DIR=%TEMP_BUILD_DIR%
set CARGO_HOME=%TEMP_CARGO_HOME%

REM Create temporary directories
mkdir "%CARGO_TARGET_DIR%" 2>nul
mkdir "%CARGO_HOME%" 2>nul

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

REM Debug: dump key env variables for diagnostics
echo ==== DIAGNOSTICS: CMake/Toolchain Environment ====
echo CMAKE_BUILD_TYPE=%CMAKE_BUILD_TYPE%
echo CMAKE_GENERATOR=%CMAKE_GENERATOR%
echo CMAKE_MSVC_RUNTIME_LIBRARY=%CMAKE_MSVC_RUNTIME_LIBRARY%
echo CMAKE_C_STANDARD=%CMAKE_C_STANDARD%
echo CMAKE_C_STANDARD_REQUIRED=%CMAKE_C_STANDARD_REQUIRED%
echo CMAKE_C_EXTENSIONS=%CMAKE_C_EXTENSIONS%
echo CMAKE_C_COMPILER=%CMAKE_C_COMPILER%
echo CMAKE_CXX_COMPILER=%CMAKE_CXX_COMPILER%
echo CMAKE_ASM_NASM_COMPILER=%CMAKE_ASM_NASM_COMPILER%
echo ASM_NASM=%ASM_NASM%
echo CMAKE_PREFIX_PATH=%CMAKE_PREFIX_PATH%
echo PKG_CONFIG_PATH=%PKG_CONFIG_PATH%
echo LIB=%LIB%
echo INCLUDE=%INCLUDE%
echo NASM=%NASM%
echo AWS_LC_SYS_PREBUILT_NASM=%AWS_LC_SYS_PREBUILT_NASM%
echo AWS_LC_SYS_NO_ASM=%AWS_LC_SYS_NO_ASM%
echo AWS_LC_SYS_USE_CMAKE=%AWS_LC_SYS_USE_CMAKE%
echo RING_USE_CMAKE=%RING_USE_CMAKE%
echo CARGO_FEATURE_PREBUILT_NASM=%CARGO_FEATURE_PREBUILT_NASM%
echo AWS_LC_SYS_PREBUILT_NASM_FEATURE=%AWS_LC_SYS_PREBUILT_NASM_FEATURE%
echo ==== DIAGNOSTICS: Cargo Environment ====
echo CARGO_HOME=%CARGO_HOME%
echo CARGO_TARGET_DIR=%CARGO_TARGET_DIR%
echo CARGO_BUILD_TARGET=%CARGO_BUILD_TARGET%
echo RUSTFLAGS=%RUSTFLAGS%
echo CARGO_BUILD_RUSTFLAGS=%CARGO_BUILD_RUSTFLAGS%
echo CARGO_ENCODED_RUSTFLAGS=%CARGO_ENCODED_RUSTFLAGS%
echo CARGO_TARGET_RUSTFLAGS=%CARGO_TARGET_RUSTFLAGS%
echo CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUSTFLAGS=%CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUSTFLAGS%
echo ==== END DIAGNOSTICS ====

echo ==== DIAGNOSTICS: NASM Version ====
where nasm
nasm -v
echo ==== END NASM DIAGNOSTICS ====

REM Build and install Zed (verbose; upstream default features)
cargo install --verbose --locked --no-track --bins --root "%PREFIX%" --path crates/zed --target %CARGO_BUILD_TARGET%
cargo install --verbose --locked --no-track --bins --root "%PREFIX%" --path crates/cli --target %CARGO_BUILD_TARGET%

REM Cleanup temporary directories
if exist "%CARGO_TARGET_DIR%" rmdir /s /q "%CARGO_TARGET_DIR%" 2>nul
if exist "%CARGO_HOME%" rmdir /s /q "%CARGO_HOME%" 2>nul
