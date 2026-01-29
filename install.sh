#!/bin/bash
set -e

# image-gen install script
# Builds and installs the image-gen binary

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Building image-gen..."
cd "$SCRIPT_DIR"
lake build image-gen

echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp .lake/build/bin/image-gen "$INSTALL_DIR/image-gen"
chmod +x "$INSTALL_DIR/image-gen"

echo ""
echo "Installed image-gen to $INSTALL_DIR/image-gen"

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "NOTE: $INSTALL_DIR is not in your PATH."
    echo "Add it by adding this line to your shell config (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# Check for API key
if [ -z "$OPENROUTER_API_KEY" ]; then
    echo ""
    echo "NOTE: OPENROUTER_API_KEY environment variable is not set."
    echo "Get your API key from https://openrouter.ai/keys and add to your shell config:"
    echo ""
    echo "  export OPENROUTER_API_KEY=\"your-api-key-here\""
    echo ""
fi

echo "Run 'image-gen --help' to get started."
