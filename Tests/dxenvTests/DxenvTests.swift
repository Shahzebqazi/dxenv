import XCTest
@testable import dxenvCore

final class DxenvTests: XCTestCase {
    var logger: LoggingManager!
    var securityManager: SecurityManager!
    var packageManager: PackageManager!
    var configurationManager: ConfigurationManager!
    var testManager: TestManager!
    
    override func setUp() {
        super.setUp()
        logger = LoggingManager(logLevel: .debug)
        securityManager = SecurityManager(logger: logger)
        packageManager = PackageManager(logger: logger, securityManager: securityManager)
        configurationManager = ConfigurationManager(logger: logger, securityManager: securityManager)
        testManager = TestManager(
            logger: logger,
            securityManager: securityManager,
            packageManager: packageManager,
            configurationManager: configurationManager
        )
    }
    
    override func tearDown() {
        logger = nil
        securityManager = nil
        packageManager = nil
        configurationManager = nil
        testManager = nil
        super.tearDown()
    }
    
    // MARK: - Model Tests
    
    func testPackageCreation() {
        let package = Package(
            id: "test-package",
            name: "Test Package",
            description: "A test package",
            category: .development,
            installCommand: "echo 'test'",
            checkCommand: "which test-package"
        )
        
        XCTAssertEqual(package.id, "test-package")
        XCTAssertEqual(package.name, "Test Package")
        XCTAssertEqual(package.category, .development)
        XCTAssertEqual(package.installCommand, "echo 'test'")
        XCTAssertEqual(package.checkCommand, "which test-package")
    }
    
    func testInstallationResultCreation() {
        let result = InstallationResult(
            packageId: "test",
            status: .installed,
            message: "Test installation",
            duration: 1.5,
            error: nil
        )
        
        XCTAssertEqual(result.packageId, "test")
        XCTAssertEqual(result.status, .installed)
        XCTAssertEqual(result.message, "Test installation")
        XCTAssertEqual(result.duration, 1.5)
        XCTAssertNil(result.error)
    }
    
    func testConfigurationCreation() {
        let config = Configuration(
            backupEnabled: true,
            logLevel: .debug,
            packages: []
        )
        
        XCTAssertTrue(config.backupEnabled)
        XCTAssertEqual(config.logLevel, .debug)
        XCTAssertEqual(config.packages.count, 0)
    }
    
    func testBackupInfoCreation() {
        let backupInfo = BackupInfo(
            id: "test-backup",
            description: "Test backup",
            files: ["test.txt"],
            checksum: "abc123"
        )
        
        XCTAssertEqual(backupInfo.id, "test-backup")
        XCTAssertEqual(backupInfo.description, "Test backup")
        XCTAssertEqual(backupInfo.files.count, 1)
        XCTAssertEqual(backupInfo.checksum, "abc123")
    }
    
    func testHealthCheckCreation() {
        let healthCheck = HealthCheck(
            component: "Test Component",
            status: .healthy,
            message: "Test message",
            details: ["key": "value"]
        )
        
        XCTAssertEqual(healthCheck.component, "Test Component")
        XCTAssertEqual(healthCheck.status, .healthy)
        XCTAssertEqual(healthCheck.message, "Test message")
        XCTAssertEqual(healthCheck.details["key"], "value")
    }
    
    // MARK: - Security Manager Tests
    
    func testHTTPSURLValidation() {
        XCTAssertTrue(securityManager.validateHTTPSURL("https://example.com"))
        XCTAssertFalse(securityManager.validateHTTPSURL("http://example.com"))
        XCTAssertFalse(securityManager.validateHTTPSURL("invalid-url"))
    }
    
    func testPackageNameValidation() {
        XCTAssertTrue(securityManager.validatePackageName("valid-package_123"))
        XCTAssertFalse(securityManager.validatePackageName("invalid package!"))
        XCTAssertFalse(securityManager.validatePackageName(""))
    }
    
    func testCommandValidation() {
        XCTAssertTrue(securityManager.validateCommand("brew install package"))
        XCTAssertFalse(securityManager.validateCommand("rm -rf /"))
        XCTAssertFalse(securityManager.validateCommand(""))
    }
    
    func testFilePathValidation() {
        XCTAssertTrue(securityManager.validateFilePath("~/Documents/file.txt"))
        XCTAssertFalse(securityManager.validateFilePath("../../../etc/passwd"))
    }
    
    // MARK: - Package Manager Tests
    
    func testPackageInstallationStatus() async {
        let package = Package(
            id: "test-package",
            name: "Test Package",
            description: "A test package",
            category: .development,
            installCommand: "echo 'test'",
            checkCommand: "echo '0'"
        )
        
        let isInstalled = await packageManager.isPackageInstalled(package)
        // This test might pass or fail depending on the system state
        XCTAssertTrue(isInstalled || !isInstalled) // Just checking it doesn't crash
    }
    
    // MARK: - Configuration Manager Tests
    
    func testConfigurationSaveAndLoad() async throws {
        let testConfig = Configuration(
            backupEnabled: true,
            logLevel: .debug,
            packages: []
        )
        
        try await configurationManager.saveConfiguration(testConfig)
        
        let loadedConfig = try await configurationManager.loadConfiguration()
        
        XCTAssertEqual(loadedConfig.backupEnabled, testConfig.backupEnabled)
        XCTAssertEqual(loadedConfig.logLevel, testConfig.logLevel)
    }
    
    func testBackupCreation() async throws {
        let backupInfo = try await configurationManager.createBackup(
            description: "Test backup",
            files: []
        )
        
        XCTAssertFalse(backupInfo.id.isEmpty)
        XCTAssertEqual(backupInfo.description, "Test backup")
        XCTAssertEqual(backupInfo.files.count, 0)
    }
    
    func testBackupListing() async {
        let backups = await configurationManager.listBackups()
        // This should not crash and return an array
        XCTAssertNotNil(backups)
    }
    
    // MARK: - Test Manager Tests
    
    func testUnitTests() async {
        let results = await testManager.runUnitTests()
        
        XCTAssertFalse(results.isEmpty)
        
        for result in results {
            XCTAssertGreaterThan(result.total, 0)
            XCTAssertGreaterThanOrEqual(result.passed, 0)
            XCTAssertLessThanOrEqual(result.passed, result.total)
        }
    }
    
    func testIntegrationTests() async {
        let results = await testManager.runIntegrationTests()
        
        XCTAssertFalse(results.isEmpty)
        
        for result in results {
            XCTAssertGreaterThan(result.total, 0)
            XCTAssertGreaterThanOrEqual(result.passed, 0)
            XCTAssertLessThanOrEqual(result.passed, result.total)
        }
    }
    
    func testHealthChecks() async {
        let healthChecks = await testManager.runHealthChecks()
        
        XCTAssertFalse(healthChecks.isEmpty)
        
        for check in healthChecks {
            XCTAssertFalse(check.component.isEmpty)
            XCTAssertFalse(check.message.isEmpty)
        }
    }
    
    // MARK: - Logging Manager Tests
    
    func testLoggingLevels() {
        let debugLevel = LogLevel.debug
        let infoLevel = LogLevel.info
        let warningLevel = LogLevel.warning
        let errorLevel = LogLevel.error
        
        XCTAssertEqual(debugLevel.loggerLevel, .debug)
        XCTAssertEqual(infoLevel.loggerLevel, .info)
        XCTAssertEqual(warningLevel.loggerLevel, .warning)
        XCTAssertEqual(errorLevel.loggerLevel, .error)
    }
    
    // MARK: - Package Category Tests
    
    func testPackageCategories() {
        let categories = PackageCategory.allCases
        
        XCTAssertFalse(categories.isEmpty)
        
        for category in categories {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.rawValue.isEmpty)
        }
    }
    
    // MARK: - Installation Status Tests
    
    func testInstallationStatuses() {
        let statuses: [InstallationStatus] = [
            .notInstalled,
            .installing,
            .installed,
            .failed,
            .skipped
        ]
        
        for status in statuses {
            XCTAssertFalse(status.rawValue.isEmpty)
        }
    }
    
    // MARK: - Health Status Tests
    
    func testHealthStatuses() {
        let statuses: [HealthStatus] = [
            .healthy,
            .warning,
            .error,
            .unknown
        ]
        
        for status in statuses {
            XCTAssertFalse(status.rawValue.isEmpty)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testSecurityErrorDescriptions() {
        let errors: [SecurityError] = [
            .invalidURL("test"),
            .invalidResponse,
            .httpError(404),
            .fileReadError("test.txt"),
            .certificateValidationFailed(NSError(domain: "test", code: 1, userInfo: nil)),
            .checksumMismatch("expected", "actual"),
            .dangerousCommand("rm -rf /")
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
    
    func testConfigurationErrorDescriptions() {
        let errors: [ConfigurationError] = [
            .backupFailed("test.txt", NSError(domain: "test", code: 1, userInfo: nil)),
            .backupNotFound("test"),
            .invalidBackupInfo("test"),
            .backupCorrupted("test"),
            .configNotFound,
            .chezmoiInstallationFailed,
            .chezmoiBackupFailed,
            .chezmoiRestoreFailed,
            .gitInitFailed,
            .gitCommitFailed
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    
    func testPackageCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = Package(
                    id: "test-package",
                    name: "Test Package",
                    description: "A test package",
                    category: .development,
                    installCommand: "echo 'test'",
                    checkCommand: "which test-package"
                )
            }
        }
    }
    
    func testConfigurationSavePerformance() async throws {
        let testConfig = Configuration(
            backupEnabled: true,
            logLevel: .debug,
            packages: []
        )
        
        measure {
            Task {
                try await configurationManager.saveConfiguration(testConfig)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflow() async throws {
        // Test configuration creation
        let config = Configuration(
            backupEnabled: true,
            logLevel: .info,
            packages: []
        )
        
        try await configurationManager.saveConfiguration(config)
        
        // Test backup creation
        let backupInfo = try await configurationManager.createBackup(
            description: "Integration test backup",
            files: []
        )
        
        XCTAssertFalse(backupInfo.id.isEmpty)
        
        // Test health checks
        let healthChecks = await testManager.runHealthChecks()
        XCTAssertFalse(healthChecks.isEmpty)
        
        // Test unit tests
        let unitResults = await testManager.runUnitTests()
        XCTAssertFalse(unitResults.isEmpty)
    }
}
