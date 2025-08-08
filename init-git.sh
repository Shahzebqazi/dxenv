#!/bin/bash

# dxenv Git Initialization Script
# This script initializes a git repository and makes the first commit

set -e

echo "🔧 Initializing git repository for dxenv..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install git first."
    exit 1
fi

# Check if we're already in a git repository
if [ -d ".git" ]; then
    echo "⚠️  Git repository already exists. Skipping initialization."
else
    # Initialize git repository
    echo "📁 Initializing git repository..."
    git init
    
    if [ $? -eq 0 ]; then
        echo "✅ Git repository initialized successfully"
    else
        echo "❌ Failed to initialize git repository"
        exit 1
    fi
fi

# Add all files to git
echo "📝 Adding files to git..."
git add .

# Check if there are files to commit
if git diff --cached --quiet; then
    echo "⚠️  No files to commit. All files may already be committed or ignored."
else
    # Make initial commit
    echo "💾 Making initial commit..."
    git commit -m "Initial commit: dxenv development environment installer

- Complete Swift implementation with all core requirements
- Package installation with security validation
- Backup and restore functionality
- Health checks and testing framework
- Comprehensive logging and error handling
- Command-line interface with subcommands
- Configuration management with Git integration"

    if [ $? -eq 0 ]; then
        echo "✅ Initial commit created successfully"
    else
        echo "❌ Failed to create initial commit"
        exit 1
    fi
fi

# Show git status
echo ""
echo "📊 Git Status:"
echo "=============="
git status

echo ""
echo "🎉 Git repository setup complete!"
echo ""
echo "Next steps:"
echo "1. Add a remote repository: git remote add origin <your-repo-url>"
echo "2. Push to remote: git push -u origin main"
echo "3. Create releases and tags as needed"
echo ""
echo "Available commands:"
echo "  git log --oneline    - View commit history"
echo "  git status           - Check repository status"
echo "  git diff             - View uncommitted changes"
echo "  git branch           - List branches"
