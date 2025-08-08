#!/bin/bash

# dxenv Demo Script
# This script demonstrates the key features of dxenv

set -e

echo "🚀 dxenv Demo"
echo "=============="
echo ""

# Check if dxenv is installed
if ! command -v dxenv &> /dev/null; then
    echo "❌ dxenv is not installed. Please run './build.sh' first."
    exit 1
fi

echo "📋 Available Commands:"
echo "======================"
dxenv --help

echo ""
echo "🏥 Health Check Demo:"
echo "===================="
echo "Running health checks to verify system status..."
dxenv health

echo ""
echo "📦 Installation Demo:"
echo "===================="
echo "Note: This will install development tools. Run with --test-mode for safe testing."
echo "To install all packages: dxenv install"
echo "To install in test mode: dxenv install --test-mode"

echo ""
echo "💾 Backup Demo:"
echo "=============="
echo "To create a backup: dxenv backup --description 'Demo backup'"
echo "To restore from backup: dxenv restore <backup-id>"

echo ""
echo "🧪 Testing Demo:"
echo "==============="
echo "To run all tests: dxenv test"
echo "To run specific tests: dxenv test --unit --integration --health"

echo ""
echo "⚙️  Configuration Demo:"
echo "======================"
echo "To show current config: dxenv config --show"
echo "To initialize git repo: dxenv config --init-git"
echo "To commit changes: dxenv config --commit 'Updated configuration'"

echo ""
echo "📊 Log Files:"
echo "============="
echo "Logs are stored in: ~/.dxenv/logs/dxenv.log"
echo "Configuration is stored in: ~/.dxenv/config/dxenv-config.json"
echo "Backups are stored in: ~/.dxenv/backups/"

echo ""
echo "🎯 Key Features Demonstrated:"
echo "============================"
echo "✅ Command-line interface with subcommands"
echo "✅ Health checks for system components"
echo "✅ Package installation with progress tracking"
echo "✅ Backup and restore functionality"
echo "✅ Configuration management"
echo "✅ Comprehensive logging"
echo "✅ Security validation"
echo "✅ Error handling and reporting"

echo ""
echo "🔧 Next Steps:"
echo "=============="
echo "1. Run 'dxenv install' to install development tools"
echo "2. Run 'dxenv health' to check system status"
echo "3. Run 'dxenv backup' to create a backup"
echo "4. Check logs in ~/.dxenv/logs/ for detailed information"
echo ""
echo "For more information, see the README.md file."
