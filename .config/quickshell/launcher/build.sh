#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

if ! command -v cmake >/dev/null 2>&1; then
    mkdir -p "$BUILD_DIR"
    g++ -std=c++20 -O2 -pipe -fPIC \
        "$SCRIPT_DIR"/src/*.cpp \
        -o "$SCRIPT_DIR/appctl" \
        $(pkg-config --cflags --libs Qt6Core)
    chmod +x "$SCRIPT_DIR/appctl"
    exit 0
fi

CMAKE_ARGS=(
    -S "$SCRIPT_DIR"
    -B "$BUILD_DIR"
    -DCMAKE_BUILD_TYPE=Release
)

if command -v ninja >/dev/null 2>&1; then
    CMAKE_ARGS+=(-G Ninja)
fi

cmake "${CMAKE_ARGS[@]}"
cmake --build "$BUILD_DIR"
cp "$BUILD_DIR/appctl" "$SCRIPT_DIR/appctl"
chmod +x "$SCRIPT_DIR/appctl"
