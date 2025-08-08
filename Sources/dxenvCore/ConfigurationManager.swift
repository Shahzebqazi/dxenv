import Foundation
import Crypto

public class ConfigurationManager {
    private let logger: LoggingManager
    private let securityManager: SecurityManager
    private let backupPath: String
    private let configPath: String
    
    public init(logger: LoggingManager, securityManager: SecurityManager, backupPath: String = "~/.dxenv/backups", configPath: String = "~/.dxenv/config") {
        self.logger = logger
        self.securityManager = securityManager
        self.backupPath = backupPath
        self.configPath = configPath
        setupDirectories()
    }
    
    // MARK: - Directory Setup
    
    private func setupDirectories() {
        let expandedBackupPath = (backupPath as NSString).expandingTildeInPath
        let expandedConfigPath = (configPath as NSString).expandingTildeInPath
        
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: expandedBackupPath),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: expandedConfigPath),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    // MARK: - Backup Management
    
    public func createBackup(description: String, files: [String]) async throws -> BackupInfo {
        let backupId = UUID().uuidString
        let timestamp = Date()
        let backupDirectory = URL(fileURLWithPath: (backupPath as NSString).expandingTildeInPath)
            .appendingPathComponent(backupId)
        
        try FileManager.default.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        var backedUpFiles: [String] = []
        var allChecksums: [String] = []
        
        for filePath in files {
            let expandedPath = (filePath as NSString).expandingTildeInPath
            
            guard FileManager.default.fileExists(atPath: expandedPath) else {
                logger.warning("File does not exist, skipping: \(filePath)")
                continue
            }
            
            do {
                let checksum = try securityManager.calculateFileChecksum(filePath: expandedPath)
                allChecksums.append(checksum)
                
                let fileName = URL(fileURLWithPath: expandedPath).lastPathComponent
                let backupFileURL = backupDirectory.appendingPathComponent(fileName)
                
                try FileManager.default.copyItem(
                    at: URL(fileURLWithPath: expandedPath),
                    to: backupFileURL
                )
                
                backedUpFiles.append(fileName)
                logger.debug("Backed up file: \(filePath) -> \(backupFileURL.path)")
                
            } catch {
                logger.error("Failed to backup file \(filePath): \(error)")
                throw ConfigurationError.backupFailed(filePath, error)
            }
        }
        
        // Create backup metadata
        let backupInfo = BackupInfo(
            id: backupId,
            timestamp: timestamp,
            description: description,
            files: backedUpFiles,
            checksum: SHA256.hash(data: allChecksums.joined().data(using: .utf8) ?? Data())
                .compactMap { String(format: "%02x", $0) }.joined()
        )
        
        // Save backup info
        let backupInfoURL = backupDirectory.appendingPathComponent("backup-info.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let backupData = try encoder.encode(backupInfo)
        try backupData.write(to: backupInfoURL)
        
        logger.logBackupCreated(path: backupDirectory.path, files: backedUpFiles)
        
        return backupInfo
    }
    
    public func restoreBackup(_ backupId: String) async throws {
        let backupDirectory = URL(fileURLWithPath: (backupPath as NSString).expandingTildeInPath)
            .appendingPathComponent(backupId)
        
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else {
            throw ConfigurationError.backupNotFound(backupId)
        }
        
        let backupInfoURL = backupDirectory.appendingPathComponent("backup-info.json")
        guard let backupData = try? Data(contentsOf: backupInfoURL),
              let backupInfo = try? JSONDecoder().decode(BackupInfo.self, from: backupData) else {
            throw ConfigurationError.invalidBackupInfo(backupId)
        }
        
        // Verify backup integrity
        var allChecksums: [String] = []
        for fileName in backupInfo.files {
            let backupFileURL = backupDirectory.appendingPathComponent(fileName)
            let checksum = try securityManager.calculateFileChecksum(filePath: backupFileURL.path)
            allChecksums.append(checksum)
        }
        
        let calculatedChecksum = SHA256.hash(data: allChecksums.joined().data(using: .utf8) ?? Data())
            .compactMap { String(format: "%02x", $0) }.joined()
        
        guard calculatedChecksum == backupInfo.checksum else {
            throw ConfigurationError.backupCorrupted(backupId)
        }
        
        // Restore files
        for fileName in backupInfo.files {
            let backupFileURL = backupDirectory.appendingPathComponent(fileName)
            let targetPath = "~/\(fileName)" // This is simplified - in practice, you'd need to map file locations
            
            let expandedTargetPath = (targetPath as NSString).expandingTildeInPath
            let targetURL = URL(fileURLWithPath: expandedTargetPath)
            
            // Create target directory if needed
            try? FileManager.default.createDirectory(
                at: targetURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            try FileManager.default.copyItem(
                at: backupFileURL,
                to: targetURL
            )
            
            logger.debug("Restored file: \(fileName) -> \(targetURL.path)")
        }
        
        logger.logBackupRestored(path: backupDirectory.path)
    }
    
    public func listBackups() async -> [BackupInfo] {
        let backupDirectory = URL(fileURLWithPath: (backupPath as NSString).expandingTildeInPath)
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        
        var backups: [BackupInfo] = []
        
        for backupFolder in contents {
            let backupInfoURL = backupFolder.appendingPathComponent("backup-info.json")
            
            if let backupData = try? Data(contentsOf: backupInfoURL),
               let backupInfo = try? JSONDecoder().decode(BackupInfo.self, from: backupData) {
                backups.append(backupInfo)
            }
        }
        
        return backups.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func deleteBackup(_ backupId: String) async throws {
        let backupDirectory = URL(fileURLWithPath: (backupPath as NSString).expandingTildeInPath)
            .appendingPathComponent(backupId)
        
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else {
            throw ConfigurationError.backupNotFound(backupId)
        }
        
        try FileManager.default.removeItem(at: backupDirectory)
        logger.info("Deleted backup: \(backupId)")
    }
    
    // MARK: - Configuration Management
    
    public func saveConfiguration(_ config: Configuration) async throws {
        let configURL = URL(fileURLWithPath: (configPath as NSString).expandingTildeInPath)
            .appendingPathComponent("dxenv-config.json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let configData = try encoder.encode(config)
        try configData.write(to: configURL)
        
        logger.info("Configuration saved to: \(configURL.path)")
    }
    
    public func loadConfiguration() async throws -> Configuration {
        let configURL = URL(fileURLWithPath: (configPath as NSString).expandingTildeInPath)
            .appendingPathComponent("dxenv-config.json")
        
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw ConfigurationError.configNotFound
        }
        
        let configData = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(Configuration.self, from: configData)
        
        logger.info("Configuration loaded from: \(configURL.path)")
        return config
    }
    
    // MARK: - Chezmoi Integration
    
    public func setupChezmoi() async throws {
        // Check if chezmoi is installed
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/chezmoi")
        process.arguments = ["--version"]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                logger.info("Chezmoi is already installed")
                return
            }
        } catch {
            logger.info("Chezmoi not found, installing...")
        }
        
        // Install chezmoi
        let installProcess = Process()
        installProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        installProcess.arguments = ["-c", "sh -c \"$(curl -fsLS get.chezmoi.io)\" -- -b /usr/local/bin"]
        
        try installProcess.run()
        installProcess.waitUntilExit()
        
        if installProcess.terminationStatus != 0 {
            throw ConfigurationError.chezmoiInstallationFailed
        }
        
        logger.info("Chezmoi installed successfully")
    }
    
    public func backupWithChezmoi(description: String) async throws -> BackupInfo {
        try await setupChezmoi()
        
        let backupId = UUID().uuidString
        let timestamp = Date()
        
        // Create chezmoi backup
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/chezmoi")
        process.arguments = ["backup", "--output-dir", "~/.dxenv/backups/\(backupId)"]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ConfigurationError.chezmoiBackupFailed
        }
        
        // Create backup info
        let backupInfo = BackupInfo(
            id: backupId,
            timestamp: timestamp,
            description: description,
            files: ["chezmoi-backup"],
            checksum: SHA256.hash(data: backupId.data(using: .utf8) ?? Data())
                .compactMap { String(format: "%02x", $0) }.joined()
        )
        
        logger.logBackupCreated(path: "~/.dxenv/backups/\(backupId)", files: ["chezmoi-backup"])
        
        return backupInfo
    }
    
    public func restoreWithChezmoi(_ backupId: String) async throws {
        try await setupChezmoi()
        
        let backupPath = "~/.dxenv/backups/\(backupId)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/chezmoi")
        process.arguments = ["restore", "--source", backupPath]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ConfigurationError.chezmoiRestoreFailed
        }
        
        logger.logBackupRestored(path: backupPath)
    }
    
    // MARK: - Version Control
    
    public func initializeGitRepository() async throws {
        let configDirectory = URL(fileURLWithPath: (configPath as NSString).expandingTildeInPath)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = configDirectory
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ConfigurationError.gitInitFailed
        }
        
        logger.info("Git repository initialized in: \(configDirectory.path)")
    }
    
    public func commitConfiguration(description: String) async throws {
        let configDirectory = URL(fileURLWithPath: (configPath as NSString).expandingTildeInPath)
        
        // Add all files
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["add", "."]
        addProcess.currentDirectoryURL = configDirectory
        
        try addProcess.run()
        addProcess.waitUntilExit()
        
        // Commit
        let commitProcess = Process()
        commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        commitProcess.arguments = ["commit", "-m", description]
        commitProcess.currentDirectoryURL = configDirectory
        
        try commitProcess.run()
        commitProcess.waitUntilExit()
        
        if commitProcess.terminationStatus != 0 {
            throw ConfigurationError.gitCommitFailed
        }
        
        logger.info("Configuration committed: \(description)")
    }
}

// MARK: - Configuration Errors

public enum ConfigurationError: Error, LocalizedError {
    case backupFailed(String, Error)
    case backupNotFound(String)
    case invalidBackupInfo(String)
    case backupCorrupted(String)
    case configNotFound
    case chezmoiInstallationFailed
    case chezmoiBackupFailed
    case chezmoiRestoreFailed
    case gitInitFailed
    case gitCommitFailed
    
    public var errorDescription: String? {
        switch self {
        case .backupFailed(let file, let error):
            return "Failed to backup file \(file): \(error.localizedDescription)"
        case .backupNotFound(let id):
            return "Backup not found: \(id)"
        case .invalidBackupInfo(let id):
            return "Invalid backup info for: \(id)"
        case .backupCorrupted(let id):
            return "Backup is corrupted: \(id)"
        case .configNotFound:
            return "Configuration file not found"
        case .chezmoiInstallationFailed:
            return "Failed to install chezmoi"
        case .chezmoiBackupFailed:
            return "Failed to create chezmoi backup"
        case .chezmoiRestoreFailed:
            return "Failed to restore chezmoi backup"
        case .gitInitFailed:
            return "Failed to initialize git repository"
        case .gitCommitFailed:
            return "Failed to commit configuration"
        }
    }
}
