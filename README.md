# dxenv - Simple Development Environment Installer

A comprehensive Swift-based development environment installer for macOS that automates the setup of essential development tools and configurations.

## Features

### 🔧 Core Installation
- **zsh** - Enhanced shell
- **homebrew** - Package manager for macOS
- **git** - Version control system
- **chezmoi** - Dotfile management
- **cursor** - AI-powered code editor
- **nvim** - Modern Vim editor
- **xcode** - Development tools
- **swift** - Programming language
- **docker** - Containerization platform

### 🛡️ Security Features
- HTTPS downloads with certificate validation
- SHA256 checksum verification for critical downloads
- Input validation for user-provided data
- Command safety checks

### 📊 Monitoring & Progress
- Real-time progress bars
- Detailed installation status
- Comprehensive error reporting
- Installation summaries

### 🔄 Configuration Management
- Automatic backup of existing configurations
- Version control integration with Git
- Rollback capabilities for failed installations
- Chezmoi integration for dotfile management

### 🧪 Testing & Health Checks
- Unit tests for core functions
- Integration tests for package managers
- System health checks
- Component verification

### 📝 Logging
- Structured logging with multiple levels
- Log file generation and rotation
- Error correlation for troubleshooting

## Installation

### Prerequisites
- macOS 13.0 or later
- Xcode Command Line Tools
- Swift 5.9 or later

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/dxenv.git
cd dxenv

# Build the project
swift build -c release

# Install the binary
sudo cp .build/release/dxenv /usr/local/bin/
```

### Using Swift Package Manager

```bash
# Add to your project
swift package add https://github.com/yourusername/dxenv.git
```

## Usage

### Basic Installation

```bash
# Install all default packages
dxenv install

# Install with custom log level
dxenv install --log-level debug

# Install without backup
dxenv install --skip-backup

# Install in test mode
dxenv install --test-mode
```

### Backup and Restore

```bash
# Create a backup
dxenv backup --description "Pre-update backup"

# Create backup of specific files
dxenv backup ~/.zshrc ~/.gitconfig

# Restore from backup
dxenv restore <backup-id>

# List available backups
dxenv backup --list
```

### Testing and Health Checks

```bash
# Run health checks
dxenv health

# Run all tests
dxenv test

# Run specific test types
dxenv test --unit
dxenv test --integration
dxenv test --health
```

### Configuration Management

```bash
# Show current configuration
dxenv config --show

# Initialize git repository for configuration
dxenv config --init-git

# Commit configuration changes
dxenv config --commit "Updated package list"
```

## Architecture

### Core Components

1. **PackageManager** - Handles package installation with dependency resolution
2. **SecurityManager** - Validates URLs, commands, and file integrity
3. **ConfigurationManager** - Manages backups, configuration persistence, and chezmoi integration
4. **LoggingManager** - Provides structured logging with file rotation
5. **TestManager** - Runs health checks, unit tests, and integration tests

### Swift Features Used

- **Async/Await** - Non-blocking installation processes
- **SwiftUI** - Clean, modern interface (future enhancement)
- **CryptoKit** - SHA256 checksum verification
- **FileManager** - Atomic file operations
- **Process** - System command execution

## Package Categories

- **Shell** - Terminal and shell tools
- **Package Manager** - Package management tools
- **Version Control** - Git and related tools
- **Editor** - Code editors and IDEs
- **Development** - Development tools and SDKs
- **Containerization** - Docker and container tools

## Configuration

The system stores configuration in `~/.dxenv/config/dxenv-config.json`:

```json
{
  "backupEnabled": true,
  "backupPath": "~/.dxenv/backups",
  "logLevel": "info",
  "logPath": "~/.dxenv/logs",
  "testMode": false,
  "packages": []
}
```

## Logging

Logs are stored in `~/.dxenv/logs/dxenv.log` with automatic rotation:

- **Debug** - Detailed debugging information
- **Info** - General information and progress
- **Warning** - Non-critical issues
- **Error** - Critical errors and failures

## Security

### HTTPS Validation
All downloads use HTTPS with certificate validation to ensure secure downloads.

### Checksum Verification
Critical downloads are verified using SHA256 checksums to prevent tampering.

### Command Validation
All commands are validated to prevent execution of dangerous operations.

### Input Sanitization
User inputs are validated and sanitized to prevent injection attacks.

## Testing

### Unit Tests
```bash
swift test
```

### Integration Tests
The system includes integration tests for:
- Package installation workflows
- Backup and restore operations
- Configuration persistence
- Health check systems

### Health Checks
Automatic health checks verify:
- System requirements
- Network connectivity
- Disk space availability
- File permissions
- Installed components
- Configuration integrity

## Development

### Project Structure
```
dxenv/
├── Package.swift
├── Sources/
│   ├── dxenv/
│   │   └── main.swift
│   └── dxenvCore/
│       ├── Models.swift
│       ├── LoggingManager.swift
│       ├── SecurityManager.swift
│       ├── PackageManager.swift
│       ├── ConfigurationManager.swift
│       └── TestManager.swift
└── Tests/
    └── dxenvTests/
        └── DxenvTests.swift
```

### Adding New Packages

To add a new package, define it in the `getDefaultPackages()` function:

```swift
Package(
    id: "new-package",
    name: "New Package",
    description: "Description of the package",
    category: .development,
    installCommand: "brew install new-package",
    checkCommand: "new-package --version",
    dependencies: ["homebrew"]
)
```

### Custom Installation Commands

You can customize installation commands for specific packages:

```swift
Package(
    id: "custom-package",
    name: "Custom Package",
    description: "Custom installation",
    category: .development,
    installCommand: "curl -fsSL https://example.com/install.sh | bash",
    checkCommand: "which custom-package",
    downloadURL: "https://example.com/package.tar.gz",
    checksum: "sha256-checksum-here"
)
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure you have write permissions to `~/.dxenv`
   - Run with appropriate permissions for system-wide installations

2. **Network Issues**
   - Check your internet connection
   - Verify firewall settings
   - Try using a different DNS server

3. **Package Installation Failures**
   - Check the logs in `~/.dxenv/logs/dxenv.log`
   - Verify package dependencies are installed
   - Ensure sufficient disk space

4. **Backup/Restore Issues**
   - Verify backup integrity with health checks
   - Check file permissions for backup directories
   - Ensure sufficient disk space for backups

### Debug Mode

Run with debug logging for detailed information:

```bash
dxenv install --log-level debug
```

### Health Check

Run health checks to diagnose issues:

```bash
dxenv health
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue on GitHub
- Check the documentation
- Review the logs in `~/.dxenv/logs/`

## Roadmap

- [ ] SwiftUI GUI interface
- [ ] Plugin system for custom packages
- [ ] Cloud backup integration
- [ ] Multi-platform support
- [ ] Automated updates
- [ ] Package repository integration
