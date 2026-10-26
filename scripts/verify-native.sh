#!/usr/bin/env bash
set -euo pipefail
: "${QT_HOST_PATH:?set native Qt 6.8.3 kit path}"
root="$(cd "$(dirname "$0")/.." && pwd)"
build="${BUILD_DIR:-$root/build-native}"
cmake="${CMAKE:-cmake}"
ctest="${CTEST:-ctest}"
export LANG=C.UTF-8
export LD_LIBRARY_PATH="$QT_HOST_PATH/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
"$cmake" -S "$root" -B "$build" -DCMAKE_PREFIX_PATH="$QT_HOST_PATH" -DCMAKE_BUILD_TYPE=Release
"$cmake" --build "$build" --parallel 4
"$ctest" --test-dir "$build" --output-on-failure
profile="$(mktemp -d)"
trap 'rm -rf "$profile"' EXIT
XDG_CONFIG_HOME="$profile" "$build/bin/CClicker" --capture "$build/qa-previews" --capture-slow
