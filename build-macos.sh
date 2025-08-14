#!/usr/bin/env bash

set -e  # Exit on any error

echo "🧹 Cleaning generated files..."
git clean -fdx

echo "📦 Installing Flutter dependencies..."
flutter pub get

echo "🔄 Generating Flutter Rust Bridge bindings..."
flutter_rust_bridge_codegen generate

echo "🛠️  Building Rust library for macOS..."

# Set the root of your Flutter project
ROOT="$(cd "$(dirname "$0")" && pwd)"

# Set up the Rust project directory
RUST_DIR="$ROOT/rust"

# Set up output directories
MACOS_LIBS_DIR="$ROOT/macos/Runner/Frameworks"
RUST_TARGET_DIR="$ROOT/rust/target/release"

# Ensure the output directories exist
mkdir -p "$MACOS_LIBS_DIR"
mkdir -p "$RUST_TARGET_DIR"

# Build the Rust library for macOS Apple Silicon
cd "$RUST_DIR"

echo "Building Rust library for macOS Apple Silicon..."
cargo build --release --target aarch64-apple-darwin

# Copy the built dylib to both locations
TARGET_DIR="$RUST_DIR/target/aarch64-apple-darwin/release"
DYLIB_NAME="liblnurl_pos_flutter_bridge.dylib"

if [ -f "$TARGET_DIR/$DYLIB_NAME" ]; then
    # Copy to Frameworks directory for manual loading
    cp "$TARGET_DIR/$DYLIB_NAME" "$MACOS_LIBS_DIR/"
    
    # Copy to rust/target/release for FRB auto-discovery
    cp "$TARGET_DIR/$DYLIB_NAME" "$RUST_TARGET_DIR/"
    
    echo "✅ Build complete. liblnurl_pos_flutter_bridge.dylib copied to:"
    echo "  - $MACOS_LIBS_DIR"
    echo "  - $RUST_TARGET_DIR"
    echo "🎉 macOS build completed successfully!"
else
    echo "❌ Error: $DYLIB_NAME not found in $TARGET_DIR"
    exit 1
fi 