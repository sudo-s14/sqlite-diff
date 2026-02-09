#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CRATE_DIR="$SCRIPT_DIR/sqlcipher_native"

echo "Building sqlcipher_native (Rust cdylib)..."
cd "$CRATE_DIR"
cargo build --release

DYLIB_PATH="$CRATE_DIR/target/release/libsqlcipher_native.dylib"

if [ ! -f "$DYLIB_PATH" ]; then
    echo "ERROR: Failed to build libsqlcipher_native.dylib"
    exit 1
fi

echo "Built: $DYLIB_PATH"

# Verify sqlite3 symbols are exported
if nm -gU "$DYLIB_PATH" | grep -q "_sqlite3_open"; then
    echo "OK: sqlite3_open symbol found"
else
    echo "ERROR: sqlite3_open symbol not found in dylib"
    exit 1
fi

if nm -gU "$DYLIB_PATH" | grep -q "_sqlite3_key"; then
    echo "OK: sqlite3_key symbol found (SQLCipher encryption active)"
else
    echo "ERROR: sqlite3_key symbol not found — SQLCipher may not be compiled in"
    exit 1
fi

echo "Build complete."
