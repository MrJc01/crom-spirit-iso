#!/bin/bash
set -e

# Configuration
APP_NAME="init"
OUTPUT_DIR="../../build"
SRC_DIR="../cmd/init"

echo "🔨 Building $APP_NAME for Linux/AMD64..."

# Ensure output directory exists
mkdir -p $OUTPUT_DIR

# Build statically linked binary
# CGO_ENABLED=0 ensures no dependency on glibc (unless we need C libraries later)
# -ldflags "-s -w" strips debug info for smaller size
env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags "-s -w -extldflags '-static'" \
    -o $OUTPUT_DIR/$APP_NAME \
    $SRC_DIR

echo "✅ Build success: $OUTPUT_DIR/$APP_NAME"
ls -lh $OUTPUT_DIR/$APP_NAME
