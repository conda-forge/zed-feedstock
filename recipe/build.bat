@echo off
setlocal enabledelayedexpansion

REM Create Menu directory and copy icons
mkdir "%PREFIX%\Menu" 2>nul
copy "%RECIPE_DIR%\menu.json" "%PREFIX%\Menu\%PKG_NAME%_menu.json"
copy "crates\zed\resources\app-icon.png" "%PREFIX%\Menu\zed.png"

REM Set build environment variables
set ZED_UPDATE_EXPLANATION=Please use your package manager to update zed from conda-forge
set CARGO_PROFILE_RELEASE_DEBUG=false

REM Use temp directory for build artifacts to avoid path length issues
set "TEMP_BUILD_DIR=%TEMP%\zed-build-%RANDOM%"
set "TEMP_CARGO_HOME=C:\zc%RANDOM%"
set CARGO_TARGET_DIR=%TEMP_BUILD_DIR%
set CARGO_HOME=%TEMP_CARGO_HOME%

REM Copy config.toml to CARGO_HOME\.cargo for cargo to use
if not exist "%CARGO_HOME%\.cargo" mkdir "%CARGO_HOME%\.cargo" 2>nul
copy "%RECIPE_DIR%\config.toml" "%CARGO_HOME%\.cargo\config.toml"

REM Ensure MSVC toolchain and dynamic CRT across C tool deps
set RUSTFLAGS=-C debuginfo=0

REM Align aws-lc-sys CMake build with MultiThreadedDLL (MD)
set AWS_LC_SYS_USE_CMAKE=1
set AWS_LC_SYS_CMAKE_VARIABLES=CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL;BUILD_SHARED_LIBS=OFF
set RING_USE_CMAKE=1

REM Patch Zed livekit_client to disable LiveKit/WebRTC on all Windows targets
REM This avoids linking prebuilt /MT WebRTC with our /MD runtime
for %%F in ("crates\livekit_client\Cargo.toml","zed\crates\livekit_client\Cargo.toml") do (
  if exist %%F (
    powershell -NoLogo -NoProfile -Command ^
      "$p='%%F'; if (Test-Path $p) { $t=Get-Content -Raw -LiteralPath $p; $n=$t -replace 'all\(target_os\s*=\s*\"windows\"\s*,\s*target_env\s*=\s*\"gnu\"\)','target_os = \"windows\"'; if ($n -ne $t) { Set-Content -LiteralPath $p -Value $n -Encoding UTF8 -NoNewline; Write-Host 'Patched LiveKit cfg in ' $p } else { Write-Host 'Pattern not found in ' $p } }"
  )
)

REM Make the livekit_client crate a no-op on Windows by gating the entire crate
for %%F in ("crates\livekit_client\src\lib.rs","zed\crates\livekit_client\src\lib.rs") do (
  if exist %%F (
    powershell -NoLogo -NoProfile -Command ^
      "$p='%%F'; $t=Get-Content -Raw -LiteralPath $p; if ($t -notmatch '\#\!\[cfg\(not\(target_os\s*=\s*\"windows\"\)\)\]') { $n='#![cfg(not(target_os = \"windows\"))]' + "`r`n" + $t; Set-Content -LiteralPath $p -Value $n -Encoding UTF8 -NoNewline; Write-Host 'Added crate-level cfg gate to ' $p } else { Write-Host 'Crate already gated in ' $p }"
  )
)

REM Check if libssh2.lib exists before copying
if exist "%LIBRARY_LIB%\libssh2.lib" (
    copy "%LIBRARY_LIB%\libssh2.lib" "%LIBRARY_LIB%\ssh2.lib"
)

cargo-bundle-licenses --format yaml --output THIRDPARTY.yml
cargo install --root "%PREFIX%" --path crates/zed --locked --no-default-features --features "" --profile release

REM Cleanup temporary directories
if exist "%CARGO_TARGET_DIR%" rmdir /s /q "%CARGO_TARGET_DIR%" 2>nul
if exist "%CARGO_HOME%" rmdir /s /q "%CARGO_HOME%" 2>nul
