#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

CMAKE_ARGS=(
    -S "$SCRIPT_DIR"
    -B "$BUILD_DIR"
    -DCMAKE_BUILD_TYPE=Release
)

if command -v ninja >/dev/null 2>&1; then
    CMAKE_ARGS+=(-G Ninja)
fi

if [ -n "${REIMAGINED_GOOGLE_CLIENT_ID:-}" ]; then
    CMAKE_ARGS+=("-DREIMAGINED_GOOGLE_CLIENT_ID=${REIMAGINED_GOOGLE_CLIENT_ID}")
fi

if [ -n "${REIMAGINED_GOOGLE_CLIENT_SECRET:-}" ]; then
    CMAKE_ARGS+=("-DREIMAGINED_GOOGLE_CLIENT_SECRET=${REIMAGINED_GOOGLE_CLIENT_SECRET}")
fi

cmake "${CMAKE_ARGS[@]}"
cmake --build "$BUILD_DIR"
cp "$BUILD_DIR/accountctl" "$SCRIPT_DIR/accountctl"
chmod +x "$SCRIPT_DIR/accountctl"
