#!/usr/bin/env bash
set -euo pipefail
# Pass matching Linux-host Qt and Windows-MinGW Qt kit paths.
: "${QT_HOST_PATH:?set Linux Qt 6.8.3 kit}"
: "${QT_WIN_PATH:?set Windows Qt 6.8.3 mingw_64 kit}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cmake -S "$root" -B "$root/build-cross" -DCMAKE_TOOLCHAIN_FILE="$root/cmake/mingw-linux.cmake" -DCMAKE_PREFIX_PATH="$QT_WIN_PATH" -DQT_HOST_PATH="$QT_HOST_PATH" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build "$root/build-cross" --parallel 4
printf 'Main binary: %s\n' "$root/build-cross/bin/CClicker.exe"
printf 'Package with scripts/package-windows.py and matching MinGW runtime DLLs.\n'
