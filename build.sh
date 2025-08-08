#!/bin/bash

# dxenv Build Script
# This script builds and installs the dxenv development environment installer

set -e

echo "🔨 Building dxenv..."

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed. Please install Xcode Command Line Tools first."
    echo "   Run: xcode-select --install"
    exit 1
fi

# Check Swift version
SWIFT_VERSION=$(swift --version | head -n 1 | cut -d' ' -f4)
echo "📦 Swift version: $SWIFT_VERSION"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf .build

# Build the project
echo "🔨 Building project..."
swift build -c release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Install the binary
echo "📦 Installing dxenv..."
sudo cp .build/release/dxenv /usr/local/bin/

if [ $? -eq 0 ]; then
    echo "✅ dxenv installed successfully!"
    echo "🚀 You can now use 'dxenv --help' to see available commands"
else
    echo "❌ Installation failed!"
    exit 1
fi

# Test the installation
echo "🧪 Testing installation..."
if command -v dxenv &> /dev/null; then
    echo "✅ dxenv is available in PATH"
    dxenv --version
else
    echo "❌ dxenv is not available in PATH"
    exit 1
fi

echo ""
echo "🎉 dxenv installation complete!"
echo ""
echo "Available commands:"
echo "  dxenv install     - Install development environment packages"
echo "  dxenv backup      - Create backup of current configuration"
echo "  dxenv restore     - Restore from backup"
echo "  dxenv test        - Run tests and health checks"
echo "  dxenv health      - Run health checks"
echo "  dxenv config      - Manage configuration"
echo ""
echo "For more information, run: dxenv --help"
