import Foundation
import Logging

public class LoggingManager {
    private let logger: Logger
    private let logFileURL: URL
    private let maxLogFileSize: Int64 = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles = 5
    
    public init(logLevel: LogLevel = .info, logPath: String = "~/.dxenv/logs") {
        let expandedPath = (logPath as NSString).expandingTildeInPath
        let logDirectory = URL(fileURLWithPath: expandedPath)
        
        // Create log directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: logDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        self.logFileURL = logDirectory.appendingPathComponent("dxenv.log")
        self.logger = Logger(label: "dxenv")
        
        // Configure logging
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = logLevel.loggerLevel
            return handler
        }
        
        // Rotate logs if needed
        rotateLogsIfNeeded()
    }
    
    public func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        switch level {
        case .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        }
        
        // Write to file
        writeToFile(level: level, message: logMessage)
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
    
    public func logInstallationStart(package: Package) {
        info("Starting installation of \(package.name) (\(package.id))")
    }
    
    public func logInstallationSuccess(package: Package, duration: TimeInterval) {
        info("Successfully installed \(package.name) in \(String(format: "%.2f", duration))s")
    }
    
    public func logInstallationFailure(package: Package, error: String) {
        self.error("Failed to install \(package.name): \(error)")
    }
    
    public func logBackupCreated(path: String, files: [String]) {
        info("Created backup at \(path) with \(files.count) files")
    }
    
    public func logBackupRestored(path: String) {
        info("Restored backup from \(path)")
    }
    
    public func logHealthCheck(component: String, status: HealthStatus, message: String) {
        let level: LogLevel = status == .error ? .error : (status == .warning ? .warning : .info)
        log(level, "Health check for \(component): \(message)")
    }
    
    private func writeToFile(level: LogLevel, message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue.uppercased())] \(message)\n"
        
        do {
            if let data = logEntry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFileURL.path) {
                    let handle = try FileHandle(forWritingTo: logFileURL)
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    try data.write(to: logFileURL)
                }
            }
        } catch {
            // Fallback to console if file writing fails
            print("Failed to write to log file: \(error)")
        }
    }
    
    private func rotateLogsIfNeeded() {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else { return }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize > maxLogFileSize {
                rotateLogs()
            }
        } catch {
            self.error("Failed to check log file size: \(error)")
        }
    }
    
    private func rotateLogs() {
        let logDirectory = logFileURL.deletingLastPathComponent()
        
        // Remove oldest log file if we have too many
        for i in stride(from: maxLogFiles - 1, through: 1, by: -1) {
            let oldFile = logDirectory.appendingPathComponent("dxenv.log.\(i)")
            let newFile = logDirectory.appendingPathComponent("dxenv.log.\(i + 1)")
            
            if FileManager.default.fileExists(atPath: oldFile.path) {
                try? FileManager.default.moveItem(at: oldFile, to: newFile)
            }
        }
        
        // Move current log to .1
        let rotatedFile = logDirectory.appendingPathComponent("dxenv.log.1")
        try? FileManager.default.moveItem(at: logFileURL, to: rotatedFile)
    }
    
    public func getLogContents(limit: Int = 100) -> [String] {
        do {
            let contents = try String(contentsOf: logFileURL)
            let lines = contents.components(separatedBy: .newlines)
            return Array(lines.suffix(limit))
        } catch {
            return []
        }
    }
    
    public func clearLogs() {
        try? FileManager.default.removeItem(at: logFileURL)
    }
}
