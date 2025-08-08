import Foundation

public class PackageManager {
    private let logger: LoggingManager
    private let securityManager: SecurityManager
    
    public init(logger: LoggingManager, securityManager: SecurityManager) {
        self.logger = logger
        self.securityManager = securityManager
    }
    
    // MARK: - Package Installation
    
    public func installPackage(_ package: Package, progressHandler: @escaping (Double) -> Void) async throws -> InstallationResult {
        let startTime = Date()
        
        logger.logInstallationStart(package: package)
        
        // Validate package
        guard securityManager.validatePackageName(package.id) else {
            let error = "Invalid package name: \(package.id)"
            logger.error(error)
            return InstallationResult(
                packageId: package.id,
                status: .failed,
                message: error,
                duration: Date().timeIntervalSince(startTime),
                error: error
            )
        }
        
        // Check if already installed
        if await isPackageInstalled(package) {
            logger.info("Package \(package.name) is already installed")
            return InstallationResult(
                packageId: package.id,
                status: .skipped,
                message: "Package already installed",
                duration: Date().timeIntervalSince(startTime)
            )
        }
        
        // Install dependencies first
        for dependencyId in package.dependencies {
            guard let dependency = await findPackage(by: dependencyId) else {
                let error = "Dependency not found: \(dependencyId)"
                logger.error(error)
                return InstallationResult(
                    packageId: package.id,
                    status: .failed,
                    message: error,
                    duration: Date().timeIntervalSince(startTime),
                    error: error
                )
            }
            
            do {
                let dependencyResult = try await installPackage(dependency, progressHandler: progressHandler)
                if dependencyResult.status == .failed {
                    return InstallationResult(
                        packageId: package.id,
                        status: .failed,
                        message: "Dependency installation failed: \(dependencyId)",
                        duration: Date().timeIntervalSince(startTime),
                        error: dependencyResult.error
                    )
                }
            } catch {
                return InstallationResult(
                    packageId: package.id,
                    status: .failed,
                    message: "Failed to install dependency: \(dependencyId)",
                    duration: Date().timeIntervalSince(startTime),
                    error: error.localizedDescription
                )
            }
        }
        
        // Download if needed
        if let downloadURL = package.downloadURL {
            do {
                let data = try await securityManager.downloadWithValidation(from: downloadURL)
                
                // Verify checksum if provided
                if let checksum = package.checksum {
                    guard securityManager.verifySHA256Checksum(data: data, expectedChecksum: checksum) else {
                        let error = "Checksum verification failed"
                        logger.error(error)
                        return InstallationResult(
                            packageId: package.id,
                            status: .failed,
                            message: error,
                            duration: Date().timeIntervalSince(startTime),
                            error: error
                        )
                    }
                }
                
                // Save downloaded file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(package.id).download")
                try data.write(to: tempURL)
                
                progressHandler(0.5)
                
            } catch {
                return InstallationResult(
                    packageId: package.id,
                    status: .failed,
                    message: "Download failed: \(error.localizedDescription)",
                    duration: Date().timeIntervalSince(startTime),
                    error: error.localizedDescription
                )
            }
        }
        
        // Execute installation command
        do {
            guard securityManager.validateCommand(package.installCommand) else {
                let error = "Invalid installation command: \(package.installCommand)"
                logger.error(error)
                return InstallationResult(
                    packageId: package.id,
                    status: .failed,
                    message: error,
                    duration: Date().timeIntervalSince(startTime),
                    error: error
                )
            }
            
            let result = try await executeCommand(package.installCommand)
            
            if result.exitCode != 0 {
                let error = "Installation command failed: \(result.stderr)"
                logger.error(error)
                return InstallationResult(
                    packageId: package.id,
                    status: .failed,
                    message: error,
                    duration: Date().timeIntervalSince(startTime),
                    error: error
                )
            }
            
            progressHandler(0.8)
            
            // Execute post-install commands
            for command in package.postInstallCommands {
                guard securityManager.validateCommand(command) else {
                    logger.warning("Skipping invalid post-install command: \(command)")
                    continue
                }
                
                do {
                    let postResult = try await executeCommand(command)
                    if postResult.exitCode != 0 {
                        logger.warning("Post-install command failed: \(command) - \(postResult.stderr)")
                    }
                } catch {
                    logger.warning("Post-install command error: \(command) - \(error)")
                }
            }
            
            progressHandler(1.0)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logInstallationSuccess(package: package, duration: duration)
            
            return InstallationResult(
                packageId: package.id,
                status: .installed,
                message: "Successfully installed \(package.name)",
                duration: duration
            )
            
        } catch {
            let error = "Installation failed: \(error.localizedDescription)"
            logger.logInstallationFailure(package: package, error: error)
            return InstallationResult(
                packageId: package.id,
                status: .failed,
                message: error,
                duration: Date().timeIntervalSince(startTime),
                error: error
            )
        }
    }
    
    // MARK: - Package Detection
    
    public func isPackageInstalled(_ package: Package) async -> Bool {
        do {
            let result = try await executeCommand(package.checkCommand)
            return result.exitCode == 0
        } catch {
            return false
        }
    }
    
    public func getInstalledPackages() async -> [Package] {
        // This would typically read from a configuration file
        // For now, return an empty array
        return []
    }
    
    public func findPackage(by id: String) async -> Package? {
        // This would typically search through available packages
        // For now, return nil
        return nil
    }
    
    // MARK: - Command Execution
    
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
    
    // MARK: - Batch Installation
    
    public func installPackages(_ packages: [Package], progressHandler: @escaping (String, Double) -> Void) async -> [InstallationResult] {
        var results: [InstallationResult] = []
        
        for (index, package) in packages.enumerated() {
            let progress = Double(index) / Double(packages.count)
            progressHandler(package.name, progress)
            
            do {
                let result = try await installPackage(package) { _ in
                    // Individual package progress could be handled here
                }
                results.append(result)
            } catch {
                let errorResult = InstallationResult(
                    packageId: package.id,
                    status: .failed,
                    message: error.localizedDescription,
                    error: error.localizedDescription
                )
                results.append(errorResult)
            }
        }
        
        progressHandler("Complete", 1.0)
        return results
    }
}

// MARK: - Command Result

public struct CommandResult {
    public let exitCode: Int
    public let stdout: String
    public let stderr: String
    
    public init(exitCode: Int, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}
