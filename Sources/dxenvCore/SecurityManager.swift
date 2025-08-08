import Foundation
import Crypto

public class SecurityManager {
    private let logger: LoggingManager
    
    public init(logger: LoggingManager) {
        self.logger = logger
    }
    
    // MARK: - HTTPS Validation
    
    public func validateHTTPSURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL format: \(urlString)")
            return false
        }
        
        guard url.scheme?.lowercased() == "https" else {
            logger.error("URL must use HTTPS: \(urlString)")
            return false
        }
        
        logger.debug("HTTPS URL validation passed: \(urlString)")
        return true
    }
    
    public func downloadWithValidation(from urlString: String) async throws -> Data {
        guard validateHTTPSURL(urlString) else {
            throw SecurityError.invalidURL(urlString)
        }
        
        guard let url = URL(string: urlString) else {
            throw SecurityError.invalidURL(urlString)
        }
        
        logger.info("Downloading file from: \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SecurityError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SecurityError.httpError(httpResponse.statusCode)
        }
        
        logger.info("Successfully downloaded \(data.count) bytes from \(urlString)")
        return data
    }
    
    // MARK: - Checksum Verification
    
    public func verifySHA256Checksum(data: Data, expectedChecksum: String) -> Bool {
        let calculatedChecksum = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        let isValid = calculatedChecksum.lowercased() == expectedChecksum.lowercased()
        
        if isValid {
            logger.info("SHA256 checksum verification passed")
        } else {
            logger.error("SHA256 checksum verification failed. Expected: \(expectedChecksum), Got: \(calculatedChecksum)")
        }
        
        return isValid
    }
    
    public func verifyFileChecksum(filePath: String, expectedChecksum: String) async throws -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            throw SecurityError.fileReadError(filePath)
        }
        
        return verifySHA256Checksum(data: data, expectedChecksum: expectedChecksum)
    }
    
    // MARK: - Input Validation
    
    public func validatePackageName(_ name: String) -> Bool {
        let pattern = "^[a-zA-Z0-9_-]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: name.utf16.count)
        let isValid = regex?.firstMatch(in: name, range: range) != nil
        
        if !isValid {
            logger.warning("Invalid package name format: \(name)")
        }
        
        return isValid
    }
    
    public func validateCommand(_ command: String) -> Bool {
        // Basic validation - command should not be empty and should not contain dangerous patterns
        let dangerousPatterns = [
            "rm -rf /",
            "sudo rm",
            "format",
            "dd if=",
            "mkfs"
        ]
        
        let lowercasedCommand = command.lowercased()
        
        for pattern in dangerousPatterns {
            if lowercasedCommand.contains(pattern) {
                logger.error("Dangerous command pattern detected: \(pattern)")
                return false
            }
        }
        
        return !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public func validateFilePath(_ path: String) -> Bool {
        // Check for path traversal attempts
        let dangerousComponents = ["..", "~", "/etc", "/var", "/usr"]
        let pathComponents = path.components(separatedBy: "/")
        
        for component in pathComponents {
            if dangerousComponents.contains(component) {
                logger.warning("Potentially dangerous path component: \(component)")
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Certificate Validation
    
    public func validateCertificate(for urlString: String) async throws -> Bool {
        guard let url = URL(string: urlString) else {
            throw SecurityError.invalidURL(urlString)
        }
        
        let session = URLSession(configuration: .default)
        
        do {
            let (_, response) = try await session.data(from: url)
            
            if response is HTTPURLResponse {
                logger.info("Certificate validation passed for \(urlString)")
                return true
            }
            
            return false
        } catch {
            logger.error("Certificate validation failed for \(urlString): \(error)")
            throw SecurityError.certificateValidationFailed(error)
        }
    }
    
    // MARK: - File Integrity
    
    public func calculateFileChecksum(filePath: String) throws -> String {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            throw SecurityError.fileReadError(filePath)
        }
        
        let checksum = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        logger.debug("Calculated checksum for \(filePath): \(checksum)")
        return checksum
    }
    
    public func verifyFileIntegrity(filePath: String, expectedChecksum: String) async throws -> Bool {
        let actualChecksum = try calculateFileChecksum(filePath: filePath)
        let isValid = actualChecksum.lowercased() == expectedChecksum.lowercased()
        
        if isValid {
            logger.info("File integrity verification passed for \(filePath)")
        } else {
            logger.error("File integrity verification failed for \(filePath)")
        }
        
        return isValid
    }
}

// MARK: - Security Errors

public enum SecurityError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case fileReadError(String)
    case certificateValidationFailed(Error)
    case checksumMismatch(String, String)
    case dangerousCommand(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid HTTP response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .fileReadError(let path):
            return "Failed to read file: \(path)"
        case .certificateValidationFailed(let error):
            return "Certificate validation failed: \(error.localizedDescription)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch. Expected: \(expected), Got: \(actual)"
        case .dangerousCommand(let command):
            return "Dangerous command detected: \(command)"
        }
    }
}
