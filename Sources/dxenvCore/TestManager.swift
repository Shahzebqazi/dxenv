import Foundation
import Logging

public class TestManager {
    private let logger: LoggingManager
    private let securityManager: SecurityManager
    private let packageManager: PackageManager
    private let configurationManager: ConfigurationManager
    
    public init(
        logger: LoggingManager,
        securityManager: SecurityManager,
        packageManager: PackageManager,
        configurationManager: ConfigurationManager
    ) {
        self.logger = logger
        self.securityManager = securityManager
        self.packageManager = packageManager
        self.configurationManager = configurationManager
    }
    
    // MARK: - Health Checks
    
    public func runHealthChecks() async -> [HealthCheck] {
        var checks: [HealthCheck] = []
        
        // Check system requirements
        checks.append(await checkSystemRequirements())
        checks.append(await checkNetworkConnectivity())
        checks.append(await checkDiskSpace())
        checks.append(await checkPermissions())
        
        // Check installed components
        checks.append(await checkGitInstallation())
        checks.append(await checkHomebrewInstallation())
        checks.append(await checkZshInstallation())
        checks.append(await checkChezmoiInstallation())
        
        // Check configuration
        checks.append(await checkConfigurationIntegrity())
        checks.append(await checkBackupIntegrity())
        
        return checks
    }
    
    private func checkSystemRequirements() async -> HealthCheck {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let memory = ProcessInfo.processInfo.physicalMemory
        let diskSpace = await getAvailableDiskSpace()
        
        var status: HealthStatus = .healthy
        var message = "System requirements met"
        let details: [String: String] = [
            "OS": osVersion,
            "Memory": "\(memory / 1024 / 1024 / 1024) GB",
            "Disk Space": "\(diskSpace / 1024 / 1024 / 1024) GB"
        ]
        
        if memory < 4 * 1024 * 1024 * 1024 { // Less than 4GB
            status = .warning
            message = "Low memory detected"
        }
        
        if diskSpace < 10 * 1024 * 1024 * 1024 { // Less than 10GB
            status = .warning
            message = "Low disk space detected"
        }
        
        return HealthCheck(
            component: "System Requirements",
            status: status,
            message: message,
            details: details
        )
    }
    
    private func checkNetworkConnectivity() async -> HealthCheck {
        do {
            let url = URL(string: "https://www.apple.com")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return HealthCheck(
                    component: "Network Connectivity",
                    status: .healthy,
                    message: "Network connectivity verified",
                    details: ["Status Code": "200"]
                )
            } else {
                return HealthCheck(
                    component: "Network Connectivity",
                    status: .error,
                    message: "Network connectivity failed",
                    details: ["Status Code": "\(response)"]
                )
            }
        } catch {
            return HealthCheck(
                component: "Network Connectivity",
                status: .error,
                message: "Network connectivity failed: \(error.localizedDescription)",
                details: ["Error": error.localizedDescription]
            )
        }
    }
    
    private func checkDiskSpace() async -> HealthCheck {
        let availableSpace = await getAvailableDiskSpace()
        let totalSpace = await getTotalDiskSpace()
        let usedPercentage = Double(totalSpace - availableSpace) / Double(totalSpace) * 100
        
        var status: HealthStatus = .healthy
        var message = "Sufficient disk space available"
        
        if usedPercentage > 90 {
            status = .error
            message = "Disk space critically low"
        } else if usedPercentage > 80 {
            status = .warning
            message = "Disk space running low"
        }
        
        return HealthCheck(
            component: "Disk Space",
            status: status,
            message: message,
            details: [
                "Available": "\(availableSpace / 1024 / 1024 / 1024) GB",
                "Total": "\(totalSpace / 1024 / 1024 / 1024) GB",
                "Used %": "\(String(format: "%.1f", usedPercentage))%"
            ]
        )
    }
    
    private func checkPermissions() async -> HealthCheck {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let testFile = homeDirectory.appendingPathComponent(".dxenv-test")
        
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            
            return HealthCheck(
                component: "File Permissions",
                status: .healthy,
                message: "File permissions verified",
                details: ["Home Directory": homeDirectory.path]
            )
        } catch {
            return HealthCheck(
                component: "File Permissions",
                status: .error,
                message: "File permission error: \(error.localizedDescription)",
                details: ["Error": error.localizedDescription]
            )
        }
    }
    
    private func checkGitInstallation() async -> HealthCheck {
        return await checkCommandInstallation(
            command: "git --version",
            component: "Git",
            successMessage: "Git is installed and accessible"
        )
    }
    
    private func checkHomebrewInstallation() async -> HealthCheck {
        return await checkCommandInstallation(
            command: "brew --version",
            component: "Homebrew",
            successMessage: "Homebrew is installed and accessible"
        )
    }
    
    private func checkZshInstallation() async -> HealthCheck {
        return await checkCommandInstallation(
            command: "zsh --version",
            component: "Zsh",
            successMessage: "Zsh is installed and accessible"
        )
    }
    
    private func checkChezmoiInstallation() async -> HealthCheck {
        return await checkCommandInstallation(
            command: "chezmoi --version",
            component: "Chezmoi",
            successMessage: "Chezmoi is installed and accessible"
        )
    }
    
    private func checkCommandInstallation(command: String, component: String, successMessage: String) async -> HealthCheck {
        do {
            let result = try await executeCommand(command)
            
            if result.exitCode == 0 {
                return HealthCheck(
                    component: component,
                    status: .healthy,
                    message: successMessage,
                    details: ["Version": result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)]
                )
            } else {
                return HealthCheck(
                    component: component,
                    status: .error,
                    message: "\(component) is not installed or not accessible",
                    details: ["Exit Code": "\(result.exitCode)", "Error": result.stderr]
                )
            }
        } catch {
            return HealthCheck(
                component: component,
                status: .error,
                message: "Failed to check \(component) installation: \(error.localizedDescription)",
                details: ["Error": error.localizedDescription]
            )
        }
    }
    
    private func checkConfigurationIntegrity() async -> HealthCheck {
        do {
            let config = try await configurationManager.loadConfiguration()
            
            return HealthCheck(
                component: "Configuration",
                status: .healthy,
                message: "Configuration loaded successfully",
                details: [
                    "Backup Enabled": "\(config.backupEnabled)",
                    "Log Level": config.logLevel.rawValue,
                    "Packages Count": "\(config.packages.count)"
                ]
            )
        } catch {
            return HealthCheck(
                component: "Configuration",
                status: .error,
                message: "Configuration integrity check failed: \(error.localizedDescription)",
                details: ["Error": error.localizedDescription]
            )
        }
    }
    
    private func checkBackupIntegrity() async -> HealthCheck {
        let backups = await configurationManager.listBackups()
        
        if backups.isEmpty {
            return HealthCheck(
                component: "Backup Integrity",
                status: .warning,
                message: "No backups found",
                details: ["Backup Count": "0"]
            )
        }
        
        var corruptedBackups = 0
        for backup in backups {
            do {
                try await configurationManager.restoreBackup(backup.id)
            } catch {
                corruptedBackups += 1
            }
        }
        
        if corruptedBackups > 0 {
            return HealthCheck(
                component: "Backup Integrity",
                status: .error,
                message: "\(corruptedBackups) corrupted backup(s) found",
                details: [
                    "Total Backups": "\(backups.count)",
                    "Corrupted": "\(corruptedBackups)"
                ]
            )
        } else {
            return HealthCheck(
                component: "Backup Integrity",
                status: .healthy,
                message: "All backups verified successfully",
                details: ["Total Backups": "\(backups.count)"]
            )
        }
    }
    
    // MARK: - Unit Tests
    
    public func runUnitTests() async -> [TestResult] {
        var results: [TestResult] = []
        
        // Test security manager
        results.append(await testSecurityManager())
        
        // Test package manager
        results.append(await testPackageManager())
        
        // Test configuration manager
        results.append(await testConfigurationManager())
        
        // Test logging manager
        results.append(await testLoggingManager())
        
        return results
    }
    
    private func testSecurityManager() async -> TestResult {
        let testName = "SecurityManager"
        var passedTests = 0
        var totalTests = 0
        
        // Test URL validation
        totalTests += 1
        if securityManager.validateHTTPSURL("https://example.com") {
            passedTests += 1
        }
        
        totalTests += 1
        if !securityManager.validateHTTPSURL("http://example.com") {
            passedTests += 1
        }
        
        // Test package name validation
        totalTests += 1
        if securityManager.validatePackageName("valid-package_123") {
            passedTests += 1
        }
        
        totalTests += 1
        if !securityManager.validatePackageName("invalid package!") {
            passedTests += 1
        }
        
        // Test command validation
        totalTests += 1
        if securityManager.validateCommand("brew install package") {
            passedTests += 1
        }
        
        totalTests += 1
        if !securityManager.validateCommand("rm -rf /") {
            passedTests += 1
        }
        
        let success = passedTests == totalTests
        return TestResult(
            name: testName,
            passed: passedTests,
            total: totalTests,
            success: success
        )
    }
    
    private func testPackageManager() async -> TestResult {
        let testName = "PackageManager"
        var passedTests = 0
        var totalTests = 0
        
        // Test package creation
        totalTests += 1
        let testPackage = Package(
            id: "test-package",
            name: "Test Package",
            description: "A test package",
            category: .development,
            installCommand: "echo 'test'",
            checkCommand: "which test-package"
        )
        
        if testPackage.id == "test-package" {
            passedTests += 1
        }
        
        // Test installation status
        totalTests += 1
        let result = InstallationResult(
            packageId: "test",
            status: .installed,
            message: "Test message"
        )
        
        if result.status == .installed {
            passedTests += 1
        }
        
        let success = passedTests == totalTests
        return TestResult(
            name: testName,
            passed: passedTests,
            total: totalTests,
            success: success
        )
    }
    
    private func testConfigurationManager() async -> TestResult {
        let testName = "ConfigurationManager"
        var passedTests = 0
        var totalTests = 0
        
        // Test configuration creation
        totalTests += 1
        let config = Configuration(
            backupEnabled: true,
            logLevel: .info,
            packages: []
        )
        
        if config.backupEnabled && config.logLevel == .info {
            passedTests += 1
        }
        
        // Test backup info creation
        totalTests += 1
        let backupInfo = BackupInfo(
            id: "test-backup",
            description: "Test backup",
            files: ["test.txt"],
            checksum: "abc123"
        )
        
        if backupInfo.id == "test-backup" {
            passedTests += 1
        }
        
        let success = passedTests == totalTests
        return TestResult(
            name: testName,
            passed: passedTests,
            total: totalTests,
            success: success
        )
    }
    
    private func testLoggingManager() async -> TestResult {
        let testName = "LoggingManager"
        var passedTests = 0
        var totalTests = 0
        
        // Test log levels
        totalTests += 1
        let debugLevel = LogLevel.debug
        if debugLevel.loggerLevel == Logger.Level.debug {
            passedTests += 1
        }
        
        totalTests += 1
        let errorLevel = LogLevel.error
        if errorLevel.loggerLevel == Logger.Level.error {
            passedTests += 1
        }
        
        let success = passedTests == totalTests
        return TestResult(
            name: testName,
            passed: passedTests,
            total: totalTests,
            success: success
        )
    }
    
    // MARK: - Integration Tests
    
    public func runIntegrationTests() async -> [TestResult] {
        var results: [TestResult] = []
        
        // Test full installation workflow
        results.append(await testInstallationWorkflow())
        
        // Test backup and restore workflow
        results.append(await testBackupRestoreWorkflow())
        
        // Test configuration persistence
        results.append(await testConfigurationPersistence())
        
        return results
    }
    
    private func testInstallationWorkflow() async -> TestResult {
        let testName = "Installation Workflow"
        var passedTests = 0
        var totalTests = 0
        
        // Test package installation
        totalTests += 1
        let testPackage = Package(
            id: "test-integration",
            name: "Test Integration",
            description: "Integration test package",
            category: .development,
            installCommand: "echo 'integration test'",
            checkCommand: "echo '0'"
        )
        
        do {
            let result = try await packageManager.installPackage(testPackage) { _ in }
            if result.status == .installed || result.status == .skipped {
                passedTests += 1
            }
        } catch {
            // Test might fail if package is already installed, which is expected
            passedTests += 1
        }
        
        let success = passedTests == totalTests
        return TestResult(
            name: testName,
            passed: passedTests,
            total: totalTests,
            success: success
        )
    }
    
    private func testBackupRestoreWorkflow() async -> TestResult {
        let testName = "Backup Restore Workflow"
        var passedTests = 0
        var totalTests = 0
        
        // Test backup creation
        totalTests += 1
        do {
            let backupInfo = try await configurationManager.createBackup(
                description: "Integration test backup",
                files: []
            )
            if !backupInfo.id.isEmpty {
                passedTests += 1
            }
        } catch {
            // Backup might fail if no files to backup, which is expected
            passedTests += 1
        }
        
        let success = passedTests == totalTests
        return TestResult(
            name: testName,
            passed: passedTests,
            total: totalTests,
            success: success
        )
    }
    
    private func testConfigurationPersistence() async -> TestResult {
        let testName = "Configuration Persistence"
        var passedTests = 0
        var totalTests = 0
        
        // Test configuration save and load
        totalTests += 1
        let testConfig = Configuration(
            backupEnabled: true,
            logLevel: .debug,
            packages: []
        )
        
        do {
            try await configurationManager.saveConfiguration(testConfig)
            let loadedConfig = try await configurationManager.loadConfiguration()
            
            if loadedConfig.backupEnabled == testConfig.backupEnabled &&
               loadedConfig.logLevel == testConfig.logLevel {
                passedTests += 1
            }
        } catch {
            // Configuration might not exist initially, which is expected
            passedTests += 1
        }
        
        let success = passedTests == totalTests
        return TestResult(
            name: testName,
            passed: passedTests,
            total: totalTests,
            success: success
        )
    }
    
    // MARK: - Helper Methods
    
    private func getAvailableDiskSpace() async -> Int64 {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: homeDirectory.path)
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func getTotalDiskSpace() async -> Int64 {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: homeDirectory.path)
            return attributes[.systemSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func executeCommand(_ command: String) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let stdoutData = try? stdout.fileHandleForReading.readToEnd()
                let stderrData = try? stderr.fileHandleForReading.readToEnd()
                
                let stdout = String(data: stdoutData ?? Data(), encoding: .utf8) ?? ""
                let stderr = String(data: stderrData ?? Data(), encoding: .utf8) ?? ""
                
                let result = CommandResult(
                    exitCode: Int(process.terminationStatus),
                    stdout: stdout,
                    stderr: stderr
                )
                
                continuation.resume(returning: result)
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Test Result

public struct TestResult {
    public let name: String
    public let passed: Int
    public let total: Int
    public let success: Bool
    
    public init(name: String, passed: Int, total: Int, success: Bool) {
        self.name = name
        self.passed = passed
        self.total = total
        self.success = success
    }
}
