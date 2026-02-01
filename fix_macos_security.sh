#!/bin/bash
echo "Resolving macOS security warnings for VCPToolBox..."

# Find the node binary and remove the quarantine attribute
TARGET_FILE="rust-vexus-lite/vexus-lite.darwin-arm64.node"

if [ -f "$TARGET_FILE" ]; then
    echo "Removing quarantine attribute from $TARGET_FILE..."
    sudo xattr -rd com.apple.quarantine "$TARGET_FILE"
    echo "Done. You should now be able to run the server."
else
    echo "Error: $TARGET_FILE not found. Please make sure you are in the project root directory."
fi
