import Foundation
import ArgumentParser
import dxenvCore

@main
struct DxenvCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dxenv",
        abstract: "Simple Development Environment Installer",
        version: "1.0.0",
        subcommands: [
            InstallCommand.self,
            BackupCommand.self,
            RestoreCommand.self,
            TestCommand.self,
            HealthCommand.self,
            ConfigCommand.self
        ]
    )
}

struct InstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install development environment packages"
    )
    
    @Flag(name: .long, help: "Run in test mode")
    var testMode: Bool = false
    
    @Flag(name: .long, help: "Skip backup before installation")
    var skipBackup: Bool = false
    
    @Option(name: .long, help: "Log level (debug, info, warning, error)")
    var logLevel: String = "info"
    
    func run() async throws {
        let logger = LoggingManager(logLevel: LogLevel(rawValue: logLevel) ?? .info)
        let securityManager = SecurityManager(logger: logger)
        let packageManager = PackageManager(logger: logger, securityManager: securityManager)
        let configurationManager = ConfigurationManager(logger: logger, securityManager: securityManager)
        
        logger.info("Starting dxenv installation")
        
        // Load or create configuration
        let config: Configuration
        do {
            config = try await configurationManager.loadConfiguration()
        } catch {
            logger.info("No existing configuration found, creating default configuration")
            config = createDefaultConfiguration()
            try await configurationManager.saveConfiguration(config)
        }
        
        // Create backup if enabled
        if !skipBackup && config.backupEnabled {
            logger.info("Creating backup before installation")
            do {
                let backupInfo = try await configurationManager.createBackup(
                    description: "Pre-installation backup",
                    files: ["~/.zshrc", "~/.bash_profile", "~/.gitconfig"]
                )
                logger.info("Backup created: \(backupInfo.id)")
            } catch {
                logger.warning("Failed to create backup: \(error.localizedDescription)")
            }
        }
        
        // Install packages
        let packages = getDefaultPackages()
        var results: [InstallationResult] = []
        
        for package in packages {
            do {
                let result = try await packageManager.installPackage(package) { progress in
                    let percentage = Int(progress * 100)
                    print("Installing \(package.name): \(percentage)%")
                }
                results.append(result)
                
                switch result.status {
                case .installed:
                    print("✅ \(package.name) installed successfully")
                case .skipped:
                    print("⏭️  \(package.name) already installed")
                case .failed:
                    print("❌ \(package.name) installation failed: \(result.message)")
                default:
                    break
                }
            } catch {
                let errorResult = InstallationResult(
                    packageId: package.id,
                    status: .failed,
                    message: error.localizedDescription,
                    error: error.localizedDescription
                )
                results.append(errorResult)
                print("❌ \(package.name) installation failed: \(error.localizedDescription)")
            }
        }
        
        // Print summary
        printInstallationSummary(results)
        
        // Run health checks
        if !testMode {
            print("\nRunning health checks...")
            let testManager = TestManager(
                logger: logger,
                securityManager: securityManager,
                packageManager: packageManager,
                configurationManager: configurationManager
            )
            
            let healthChecks = await testManager.runHealthChecks()
            printHealthChecks(healthChecks)
        }
    }
    
    private func createDefaultConfiguration() -> Configuration {
        return Configuration(
            backupEnabled: true,
            logLevel: LogLevel(rawValue: logLevel) ?? .info,
            packages: getDefaultPackages()
        )
    }
    
    private func getDefaultPackages() -> [Package] {
        return [
            Package(
                id: "zsh",
                name: "Zsh",
                description: "Z shell - enhanced shell",
                category: .shell,
                installCommand: "echo 'Zsh is typically pre-installed on macOS'",
                checkCommand: "zsh --version"
            ),
            Package(
                id: "homebrew",
                name: "Homebrew",
                description: "Package manager for macOS",
                category: .packageManager,
                installCommand: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
                checkCommand: "brew --version"
            ),
            Package(
                id: "git",
                name: "Git",
                description: "Version control system",
                category: .versionControl,
                installCommand: "brew install git",
                checkCommand: "git --version",
                dependencies: ["homebrew"]
            ),
            Package(
                id: "chezmoi",
                name: "Chezmoi",
                description: "Dotfile manager",
                category: .packageManager,
                installCommand: "sh -c \"$(curl -fsLS get.chezmoi.io)\" -- -b /usr/local/bin",
                checkCommand: "chezmoi --version"
            ),
            Package(
                id: "cursor",
                name: "Cursor",
                description: "AI-powered code editor",
                category: .editor,
                installCommand: "brew install --cask cursor",
                checkCommand: "cursor --version",
                dependencies: ["homebrew"]
            ),
            Package(
                id: "nvim",
                name: "Neovim",
                description: "Modern Vim editor",
                category: .editor,
                installCommand: "brew install neovim",
                checkCommand: "nvim --version",
                dependencies: ["homebrew"]
            ),
            Package(
                id: "xcode",
                name: "Xcode Command Line Tools",
                description: "Development tools for macOS",
                category: .development,
                installCommand: "xcode-select --install",
                checkCommand: "xcode-select --print-path"
            ),
            Package(
                id: "swift",
                name: "Swift",
                description: "Swift programming language",
                category: .development,
                installCommand: "echo 'Swift is included with Xcode Command Line Tools'",
                checkCommand: "swift --version",
                dependencies: ["xcode"]
            ),
            Package(
                id: "docker",
                name: "Docker Desktop",
                description: "Containerization platform",
                category: .containerization,
                installCommand: "brew install --cask docker",
                checkCommand: "docker --version",
                dependencies: ["homebrew"]
            )
        ]
    }
    
    private func printInstallationSummary(_ results: [InstallationResult]) {
        print("\n📊 Installation Summary:")
        print("=" * 50)
        
        let installed = results.filter { $0.status == .installed }.count
        let skipped = results.filter { $0.status == .skipped }.count
        let failed = results.filter { $0.status == .failed }.count
        
        print("✅ Installed: \(installed)")
        print("⏭️  Skipped: \(skipped)")
        print("❌ Failed: \(failed)")
        
        if failed > 0 {
            print("\nFailed installations:")
            for result in results where result.status == .failed {
                print("  - \(result.packageId): \(result.message)")
            }
        }
    }
    
    private func printHealthChecks(_ checks: [HealthCheck]) {
        print("\n🏥 Health Check Results:")
        print("=" * 50)
        
        for check in checks {
            let statusIcon = check.status == .healthy ? "✅" : (check.status == .warning ? "⚠️" : "❌")
            print("\(statusIcon) \(check.component): \(check.message)")
            
            if !check.details.isEmpty {
                for (key, value) in check.details {
                    print("    \(key): \(value)")
                }
            }
        }
    }
}

struct BackupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backup",
        abstract: "Create backup of current configuration"
    )
    
    @Option(name: .long, help: "Backup description")
    var description: String = "Manual backup"
    
    @Argument(help: "Files to backup")
    var files: [String] = []
    
    func run() async throws {
        let logger = LoggingManager()
        let securityManager = SecurityManager(logger: logger)
        let configurationManager = ConfigurationManager(logger: logger, securityManager: securityManager)
        
        let filesToBackup = files.isEmpty ? ["~/.zshrc", "~/.bash_profile", "~/.gitconfig"] : files
        
        do {
            let backupInfo = try await configurationManager.createBackup(
                description: description,
                files: filesToBackup
            )
            
            print("✅ Backup created successfully")
            print("ID: \(backupInfo.id)")
            print("Description: \(backupInfo.description)")
            print("Files: \(backupInfo.files.joined(separator: ", "))")
            print("Timestamp: \(backupInfo.timestamp)")
            
        } catch {
            print("❌ Backup failed: \(error.localizedDescription)")
            throw error
        }
    }
}

struct RestoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restore",
        abstract: "Restore from backup"
    )
    
    @Argument(help: "Backup ID to restore")
    var backupId: String
    
    func run() async throws {
        let logger = LoggingManager()
        let securityManager = SecurityManager(logger: logger)
        let configurationManager = ConfigurationManager(logger: logger, securityManager: securityManager)
        
        do {
            try await configurationManager.restoreBackup(backupId)
            print("✅ Backup restored successfully")
        } catch {
            print("❌ Restore failed: \(error.localizedDescription)")
            throw error
        }
    }
}

struct TestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run tests and health checks"
    )
    
    @Flag(name: .long, help: "Run unit tests")
    var unit: Bool = false
    
    @Flag(name: .long, help: "Run integration tests")
    var integration: Bool = false
    
    @Flag(name: .long, help: "Run health checks")
    var health: Bool = true
    
    func run() async throws {
        let logger = LoggingManager()
        let securityManager = SecurityManager(logger: logger)
        let packageManager = PackageManager(logger: logger, securityManager: securityManager)
        let configurationManager = ConfigurationManager(logger: logger, securityManager: securityManager)
        let testManager = TestManager(
            logger: logger,
            securityManager: securityManager,
            packageManager: packageManager,
            configurationManager: configurationManager
        )
        
        if unit {
            print("🧪 Running unit tests...")
            let unitResults = await testManager.runUnitTests()
            printTestResults(unitResults, "Unit Tests")
        }
        
        if integration {
            print("🔗 Running integration tests...")
            let integrationResults = await testManager.runIntegrationTests()
            printTestResults(integrationResults, "Integration Tests")
        }
        
        if health {
            print("🏥 Running health checks...")
            let healthChecks = await testManager.runHealthChecks()
            printHealthChecks(healthChecks)
        }
    }
    
    private func printTestResults(_ results: [TestResult], _ title: String) {
        print("\n📊 \(title) Results:")
        print("=" * 50)
        
        var totalPassed = 0
        var totalTests = 0
        
        for result in results {
            let statusIcon = result.success ? "✅" : "❌"
            print("\(statusIcon) \(result.name): \(result.passed)/\(result.total) passed")
            totalPassed += result.passed
            totalTests += result.total
        }
        
        print("\nTotal: \(totalPassed)/\(totalTests) tests passed")
    }
    
    private func printHealthChecks(_ checks: [HealthCheck]) {
        print("\n🏥 Health Check Results:")
        print("=" * 50)
        
        for check in checks {
            let statusIcon = check.status == .healthy ? "✅" : (check.status == .warning ? "⚠️" : "❌")
            print("\(statusIcon) \(check.component): \(check.message)")
            
            if !check.details.isEmpty {
                for (key, value) in check.details {
                    print("    \(key): \(value)")
                }
            }
        }
    }
}

struct HealthCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "health",
        abstract: "Run health checks"
    )
    
    func run() async throws {
        let logger = LoggingManager()
        let securityManager = SecurityManager(logger: logger)
        let packageManager = PackageManager(logger: logger, securityManager: securityManager)
        let configurationManager = ConfigurationManager(logger: logger, securityManager: securityManager)
        let testManager = TestManager(
            logger: logger,
            securityManager: securityManager,
            packageManager: packageManager,
            configurationManager: configurationManager
        )
        
        print("🏥 Running health checks...")
        let healthChecks = await testManager.runHealthChecks()
        
        for check in healthChecks {
            let statusIcon = check.status == .healthy ? "✅" : (check.status == .warning ? "⚠️" : "❌")
            print("\(statusIcon) \(check.component): \(check.message)")
            
            if !check.details.isEmpty {
                for (key, value) in check.details {
                    print("    \(key): \(value)")
                }
            }
        }
    }
}

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage configuration"
    )
    
    @Flag(name: .long, help: "Show current configuration")
    var show: Bool = false
    
    @Flag(name: .long, help: "Initialize git repository")
    var initGit: Bool = false
    
    @Option(name: .long, help: "Commit message")
    var commit: String?
    
    func run() async throws {
        let logger = LoggingManager()
        let securityManager = SecurityManager(logger: logger)
        let configurationManager = ConfigurationManager(logger: logger, securityManager: securityManager)
        
        if show {
            do {
                let config = try await configurationManager.loadConfiguration()
                print("📋 Current Configuration:")
                print("=" * 50)
                print("Backup Enabled: \(config.backupEnabled)")
                print("Log Level: \(config.logLevel.rawValue)")
                print("Log Path: \(config.logPath)")
                print("Backup Path: \(config.backupPath)")
                print("Test Mode: \(config.testMode)")
                print("Packages: \(config.packages.count)")
            } catch {
                print("❌ Failed to load configuration: \(error.localizedDescription)")
            }
        }
        
        if initGit {
            do {
                try await configurationManager.initializeGitRepository()
                print("✅ Git repository initialized")
            } catch {
                print("❌ Failed to initialize git repository: \(error.localizedDescription)")
            }
        }
        
        if let commitMessage = commit {
            do {
                try await configurationManager.commitConfiguration(description: commitMessage)
                print("✅ Configuration committed: \(commitMessage)")
            } catch {
                print("❌ Failed to commit configuration: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - String Extension for Repeat

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
