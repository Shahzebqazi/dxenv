import Foundation
import Crypto
import Logging

// MARK: - Core Models

public struct Package: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let category: PackageCategory
    public let installCommand: String
    public let checkCommand: String
    public let downloadURL: String?
    public let checksum: String?
    public let dependencies: [String]
    public let postInstallCommands: [String]
    
    public init(
        id: String,
        name: String,
        description: String,
        category: PackageCategory,
        installCommand: String,
        checkCommand: String,
        downloadURL: String? = nil,
        checksum: String? = nil,
        dependencies: [String] = [],
        postInstallCommands: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.installCommand = installCommand
        self.checkCommand = checkCommand
        self.downloadURL = downloadURL
        self.checksum = checksum
        self.dependencies = dependencies
        self.postInstallCommands = postInstallCommands
    }
}

public enum PackageCategory: String, Codable, CaseIterable {
    case shell = "Shell"
    case packageManager = "Package Manager"
    case versionControl = "Version Control"
    case editor = "Editor"
    case development = "Development"
    case containerization = "Containerization"
    
    public var displayName: String {
        return rawValue
    }
}

public enum InstallationStatus: String, Codable {
    case notInstalled = "Not Installed"
    case installing = "Installing"
    case installed = "Installed"
    case failed = "Failed"
    case skipped = "Skipped"
}

public struct InstallationResult: Codable {
    public let packageId: String
    public let status: InstallationStatus
    public let message: String
    public let timestamp: Date
    public let duration: TimeInterval?
    public let error: String?
    
    public init(
        packageId: String,
        status: InstallationStatus,
        message: String,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        error: String? = nil
    ) {
        self.packageId = packageId
        self.status = status
        self.message = message
        self.timestamp = timestamp
        self.duration = duration
        self.error = error
    }
}

public struct Configuration: Codable {
    public let backupEnabled: Bool
    public let backupPath: String
    public let logLevel: LogLevel
    public let logPath: String
    public let testMode: Bool
    public let packages: [Package]
    
    public init(
        backupEnabled: Bool = true,
        backupPath: String = "~/.dxenv/backups",
        logLevel: LogLevel = .info,
        logPath: String = "~/.dxenv/logs",
        testMode: Bool = false,
        packages: [Package] = []
    ) {
        self.backupEnabled = backupEnabled
        self.backupPath = backupPath
        self.logLevel = logLevel
        self.logPath = logPath
        self.testMode = testMode
        self.packages = packages
    }
}

public enum LogLevel: String, Codable, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    public var loggerLevel: Logger.Level {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
}

public struct BackupInfo: Codable {
    public let id: String
    public let timestamp: Date
    public let description: String
    public let files: [String]
    public let checksum: String
    
    public init(
        id: String,
        timestamp: Date = Date(),
        description: String,
        files: [String],
        checksum: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.files = files
        self.checksum = checksum
    }
}

public struct HealthCheck: Codable {
    public let component: String
    public let status: HealthStatus
    public let message: String
    public let timestamp: Date
    public let details: [String: String]
    
    public init(
        component: String,
        status: HealthStatus,
        message: String,
        timestamp: Date = Date(),
        details: [String: String] = [:]
    ) {
        self.component = component
        self.status = status
        self.message = message
        self.timestamp = timestamp
        self.details = details
    }
}

public enum HealthStatus: String, Codable {
    case healthy = "Healthy"
    case warning = "Warning"
    case error = "Error"
    case unknown = "Unknown"
}
