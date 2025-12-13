#!/bin/bash
set -e

# Configuration
DISTRO="alpine:latest"
OUTPUT_DIR="../../build/rootfs"
TAR_FILE="../../build/rootfs.tar"

echo "📦 Building RootFS based on $DISTRO..."

# Clean previous build
rm -rf $OUTPUT_DIR $TAR_FILE
mkdir -p $OUTPUT_DIR

# Use Docker to export the base filesystem
# 1. Create a container (but don't run it)
CONTAINER_ID=$(docker create $DISTRO)

# 2. Export the filesystem to a tarball
echo "   Exporting filesystem from container..."
docker export $CONTAINER_ID -o $TAR_FILE

# 3. Cleanup container
docker rm $CONTAINER_ID

# 4. Extract to verify (optional, mostly we need the folder structure for packing into initramfs later)
echo "   Extracting to $OUTPUT_DIR..."
tar -xf $TAR_FILE -C $OUTPUT_DIR

# 5. Inject our custom init
if [ -f "../../build/init" ]; then
    echo "   Injecting custom /init..."
    cp ../../build/init $OUTPUT_DIR/init
    chmod +x $OUTPUT_DIR/init
else
    echo "⚠️  Warning: Custom init not found in ../../build/init. Skipping injection."
fi

# 6. Basic customizations
mkdir -p $OUTPUT_DIR/proc $OUTPUT_DIR/sys $OUTPUT_DIR/dev $OUTPUT_DIR/tmp $OUTPUT_DIR/mnt/nodus
echo "spirit-node-01" > $OUTPUT_DIR/etc/hostname

echo "✅ RootFS created at $OUTPUT_DIR"
