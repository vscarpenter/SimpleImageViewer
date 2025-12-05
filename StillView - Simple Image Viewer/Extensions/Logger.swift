import Foundation
import os.log

/// Centralized logging utility for the application
/// Provides conditional logging based on build configuration
struct Logger {
    
    // MARK: - Log Categories
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.vinny.StillView"
    
    private static let general = OSLog(subsystem: subsystem, category: "General")
    private static let security = OSLog(subsystem: subsystem, category: "Security")
    private static let thumbnails = OSLog(subsystem: subsystem, category: "Thumbnails")
    private static let performance = OSLog(subsystem: subsystem, category: "Performance")
    private static let error = OSLog(subsystem: subsystem, category: "Error")
    private static let ai = OSLog(subsystem: subsystem, category: "AI")
    
    // MARK: - Instance Properties
    
    private let osLog: OSLog
    
    // MARK: - Initialization
    
    init(subsystem: String = Logger.subsystem, category: String) {
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    // MARK: - Instance Methods
    
    /// Log debug information (only in debug builds)
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log(.debug, log: osLog, "%{public}@", logMessage)
        #endif
    }
    
    /// Log general information
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log(.info, log: osLog, "%{public}@", logMessage)
    }
    
    /// Log warnings
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log(.default, log: osLog, "⚠️ %{public}@", logMessage)
    }
    
    /// Log errors
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log(.error, log: osLog, "❌ %{public}@", logMessage)
    }
    
    // MARK: - Static Methods (for backward compatibility)
    
    /// Log debug information (only in debug builds)
    static func debug(_ message: String, category: OSLog = general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log(.debug, log: category, "%{public}@", logMessage)
        #endif
    }
    
    /// Log debug information with context (only in debug builds)
    static func debug(_ message: String, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) [\(context)]: \(message)"
        os_log(.debug, log: general, "%{public}@", logMessage)
        #endif
    }
    
    /// Log general information
    static func info(_ message: String, category: OSLog = general, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log(.info, log: category, "%{public}@", logMessage)
    }
    
    /// Log general information with context
    static func info(_ message: String, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) [\(context)]: \(message)"
        os_log(.info, log: general, "%{public}@", logMessage)
    }
    
    /// Log warnings
    static func warning(_ message: String, category: OSLog = general, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log(.default, log: category, "⚠️ %{public}@", logMessage)
    }
    
    /// Log warnings with context
    static func warning(_ message: String, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) [\(context)]: \(message)"
        os_log(.default, log: general, "⚠️ %{public}@", logMessage)
    }
    
    /// Log errors
    static func error(_ message: String, category: OSLog = error, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log(.error, log: category, "❌ %{public}@", logMessage)
    }
    
    /// Log errors with context
    static func error(_ message: String, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) [\(context)]: \(message)"
        os_log(.error, log: error, "❌ %{public}@", logMessage)
    }
    
    /// Log security-related information
    static func security(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: security, file: file, function: function, line: line)
    }
    
    // Favorites removed
    
    /// Log thumbnail-related information
    static func thumbnails(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: thumbnails, file: file, function: function, line: line)
    }
    
    /// Log performance-related information
    static func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: performance, file: file, function: function, line: line)
    }
    
    /// Log AI analysis-related information
    static func ai(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: ai, file: file, function: function, line: line)
    }
    
    // MARK: - Convenience Methods
    
    /// Log success messages
    static func success(_ message: String, category: OSLog = general, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log(.info, log: category, "✅ %{public}@", logMessage)
    }
    
    /// Log operation start
    static func start(_ operation: String, category: OSLog = general, file: String = #file, function: String = #function, line: Int = #line) {
        debug("🔄 Starting: \(operation)", category: category, file: file, function: function, line: line)
    }
    
    /// Log operation start with context
    static func start(_ operation: String, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug("🔄 Starting: \(operation)", context: context, file: file, function: function, line: line)
    }
    
    /// Log operation completion
    static func complete(_ operation: String, category: OSLog = general, file: String = #file, function: String = #function, line: Int = #line) {
        debug("✅ Completed: \(operation)", category: category, file: file, function: function, line: line)
    }
    
    /// Log operation failure
    static func fail(
        _ operation: String,
        error: Error? = nil,
        category: OSLog = error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let errorMessage = error != nil ? " - Error: \(error!.localizedDescription)" : ""
        let message = "❌ Failed: \(operation)\(errorMessage)"
        Logger.error(message, category: category, file: file, function: function, line: line)
    }
    
    /// Log operation failure with context
    static func fail(
        _ operation: String,
        error: Error? = nil,
        context: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let errorMessage = error != nil ? " - Error: \(error!.localizedDescription)" : ""
        let message = "❌ Failed: \(operation)\(errorMessage)"
        Logger.error(message, context: context, file: file, function: function, line: line)
    }
    
    /// Log success messages with context
    static func success(
        _ message: String,
        context: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function) [\(context)]: \(message)"
        os_log(.info, log: general, "✅ %{public}@", logMessage)
    }
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log with automatic category selection based on context
    static func log(_ message: String, level: OSLogType = .default, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let category: OSLog
        switch context {
        case "security":
            category = security
        // Favorites removed
        case "thumbnails":
            category = thumbnails
        case "performance":
            category = performance
        case "error":
            category = error
        case "ai":
            category = ai
        default:
            category = general
        }
        
        switch level {
        case .debug:
            debug(message, category: category, file: file, function: function, line: line)
        case .info:
            info(message, category: category, file: file, function: function, line: line)
        case .default:
            info(message, category: category, file: file, function: function, line: line)
        case .error:
            error(message, category: category, file: file, function: function, line: line)
        case .fault:
            error(message, category: category, file: file, function: function, line: line)
        default:
            info(message, category: category, file: file, function: function, line: line)
        }
    }
}
