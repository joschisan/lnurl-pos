#!/usr/bin/env bash

set -e  # Exit on any error

echo "🧹 Cleaning generated files..."
git clean -fdx

echo "📦 Installing Flutter dependencies..."
flutter pub get

echo "🔄 Generating Flutter Rust Bridge bindings..."
flutter_rust_bridge_codegen generate

echo "🛠️  Building Rust library for Android..."

# Set the root of your Flutter project
ROOT="$(cd "$(dirname "$0")" && pwd)"

# Set your Android NDK path (update if needed)
export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/26.3.11579264

# Set up the Rust project directory (update if needed)
RUST_DIR="$ROOT/rust"

# Set up the output directory for the .so file
JNI_LIBS_DIR="$ROOT/android/app/src/main/jniLibs/arm64-v8a"

# Ensure the output directory exists
mkdir -p "$JNI_LIBS_DIR"

# Set up the cross-compiler environment variables for Apple Silicon (darwin-arm64)
export CC_aarch64_linux_android="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-arm64/bin/aarch64-linux-android21-clang"
export CXX_aarch64_linux_android="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-arm64/bin/aarch64-linux-android21-clang++"

# Build the Rust library for Android ARM64
cd "$RUST_DIR"
cargo ndk -t arm64-v8a -o "$JNI_LIBS_DIR" build --release --target aarch64-linux-android

# Move any .so files from nested subdirectories up to JNI_LIBS_DIR
find "$JNI_LIBS_DIR" -type f -name '*.so' -exec mv {} "$JNI_LIBS_DIR" \;
# Remove any empty nested directories
find "$JNI_LIBS_DIR" -type d -empty -delete

# Copy the C++ shared library required by the Rust library
cp "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-arm64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" "$JNI_LIBS_DIR/" 2>/dev/null || true

echo "✅ Build complete. .so and libc++_shared.so copied to $JNI_LIBS_DIR" 