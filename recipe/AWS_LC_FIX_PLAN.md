# Windows Linking Fix (Zed + aws-lc-sys)

## What’s Going Wrong

- Mixed MSVC runtimes: `MSVCRTD` (debug, dynamic) is being linked together with `libcmt` (release, static). This mismatch leads to LNK4098 diagnostics and ultimately `link.exe` exit code 1120 (unresolved externals).
- The log shows `/defaultlib:libcmt` on the link line and warnings about symbols from `libucrt.lib` being imported by `aws_lc_sys` objects. That’s a classic sign that something in your build is forcing the static CRT while other parts (Rust std/proc-macro host) are using the default dynamic CRT.
- `sqlx-macros` is a proc-macro crate; it builds a DLL on Windows and pulls in networking/TLS deps at build time. Any CRT mismatch in that dependency graph will blow up here.

## Fix Fast (Recommended)

Goal: Put everything back on the default dynamic MSVC runtime (/MD or /MDd), which is what Rust uses by default on MSVC.

1) Remove forced CRT/link args

- Check and delete any `-C link-arg=/MT`, `-C link-arg=/NODEFAULTLIB:*`, or `-C target-feature=+crt-static` you added.
- Look in all of these places and remove overrides if present:
  - `%CD%\.cargo\config.toml`
  - `%USERPROFILE%\.cargo\config.toml`
  - System/User env vars: `RUSTFLAGS`, `CFLAGS`, `CXXFLAGS`

2) Explicitly disable static CRT if needed (defensive)

- If you suspect a global `+crt-static` somewhere, add this in your project to force dynamic:

  ```toml
  # .cargo/config.toml (project local)
  [target.x86_64-pc-windows-msvc]
  rustflags = ["-C", "target-feature=-crt-static"]
  ```

3) Clean all build caches

- `cargo clean -p aws-lc-sys -p ring`
- Delete Zed’s temp build dir(s): `%LOCALAPPDATA%\Temp\zed-build-*`

4) Verify toolchain and deps

- Install/ensure: Visual Studio C++ Build Tools, Windows 10/11 SDK, CMake, NASM.
- If you don’t want to install NASM now, set `AWS_LC_SYS_PREBUILT_NASM=1` before building so `aws-lc-sys` uses its prebuilt NASM.

5) Rebuild from a regular terminal first

- In a Developer Command Prompt (x64): `cargo build --release`
- If this succeeds, try the same project in Zed again.

## Zed-Specific Tips

- Prefer running `cargo` as a task instead of the background builder for initial troubleshooting.
- Ensure Zed inherits your VS environment: start Zed from a Developer Command Prompt (so `link.exe`, SDK libs, etc. are on PATH/LIB/INCLUDE).
- If you must set env for Zed tasks, add a `.zed/tasks.json` that passes only what’s needed (avoid `RUSTFLAGS` that force CRT):

  ```json
  {
    "tasks": [
      {
        "label": "cargo build (release)",
        "command": "cmd",
        "args": ["/c", "cargo build --release"],
        "env": {
          "AWS_LC_SYS_PREBUILT_NASM": "1"
        }
      }
    ]
  }
  ```

## If You Really Need Static CRT (/MT)

- You must make it 100% consistent across the entire build (including proc-macros):
  - Enable static CRT at the Rust level: `RUSTFLAGS=-C target-feature=+crt-static` (or via project `.cargo/config.toml`).
  - Ensure any custom link args are mutually consistent (no `MSVCRTD` in a release build; use `/MTd` for debug-only if you truly need static in debug).
  - Confirm `aws-lc-sys` picks up the setting: it respects the `crt-static` target feature and will set CMake’s `CMAKE_MSVC_RUNTIME_LIBRARY` accordingly.
- Caveat: Static CRT for proc-macro DLLs is brittle and often unnecessary; prefer the dynamic CRT path unless you have a strong reason.

## Quick Checks/Commands

- Show cargo config(s): `type %CD%\.cargo\config.toml` and `type %USERPROFILE%\.cargo\config.toml`
- Show env overrides: `reg query HKCU\Environment /v RUSTFLAGS` and `reg query HKCU\Environment /v CFLAGS`
- Full verbose build to capture the real link line: `cargo build -vv`

## Why This Works

- `aws-lc-sys`’s build uses CMake and selects the MSVC runtime based on the `crt-static` target feature. If you remove custom CRT/link flags, it defaults to the dynamic runtime, matching Rust’s defaults for MSVC. That eliminates the `MSVCRTD` vs `libcmt` mismatch that’s triggering your LNK4098 → LNK1120 failure chain.

## Still Stuck?

- Paste the full linker line from `cargo build -vv` and any lingering `LNK2019/LNK2001` messages. Those lines will identify the exact missing symbols and which lib requested them.
