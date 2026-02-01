#!/bin/bash
echo "Resolving macOS security warnings for VCPToolBox..."

# List of known binary files that might be blocked
BINARY_FILES=(
    "rust-vexus-lite/vexus-lite.darwin-arm64.node"
    "Plugin/MIDITranslator/midi_quantizer.node"
)

for TARGET_FILE in "${BINARY_FILES[@]}"; do
    if [ -f "$TARGET_FILE" ]; then
        echo "Removing quarantine attribute from $TARGET_FILE..."
        sudo xattr -rd com.apple.quarantine "$TARGET_FILE" 2>/dev/null || xattr -rd com.apple.quarantine "$TARGET_FILE"
    else
        echo "Note: $TARGET_FILE not found, skipping."
    fi
done

echo "Done. You should now be able to run the server."
