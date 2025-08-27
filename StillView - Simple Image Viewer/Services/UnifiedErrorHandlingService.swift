import Foundation
import SwiftUI
import Combine

/// Unified error handling service that standardizes error handling across all services
/// Provides consistent error categorization, user feedback, and recovery suggestions
@MainActor
final class UnifiedErrorHandlingService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = UnifiedErrorHandlingService()
    
    // MARK: - Published Properties
    
    /// Current active errors that need user attention
    @Published private(set) var activeErrors: [UnifiedError] = []
    
    /// Error history for debugging and analytics
    @Published private(set) var errorHistory: [ErrorRecord] = []
    
    /// Whether error recovery is in progress
    @Published private(set) var isRecovering: Bool = false
    
    // MARK: - Private Properties
    
    private let maxActiveErrors = 3
    private let maxErrorHistory = 100
    private var cancellables = Set<AnyCancellable>()
    private let errorQueue = DispatchQueue(label: "com.vinny.error-handling", qos: .utility)
    
    // MARK: - Error Categories
    
    enum ErrorCategory: String, CaseIterable {
        case fileSystem = "File System"
        case network = "Network"
        case security = "Security"
        case memory = "Memory"
        case validation = "Validation"
        case userInterface = "User Interface"
        case system = "System"
        case unknown = "Unknown"
        
        var icon: String {
            switch self {
            case .fileSystem: return "📁"
            case .network: return "🌐"
            case .security: return "🔒"
            case .memory: return "💾"
            case .validation: return "✅"
            case .userInterface: return "🖥️"
            case .system: return "⚙️"
            case .unknown: return "❓"
            }
        }
        
        var color: Color {
            switch self {
            case .fileSystem: return .blue
            case .network: return .orange
            case .security: return .red
            case .memory: return .purple
            case .validation: return .green
            case .userInterface: return .indigo
            case .system: return .gray
            case .unknown: return .secondary
            }
        }
    }
    
    enum ErrorSeverity: String, CaseIterable, Comparable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var priority: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .critical: return 4
            }
        }
        
        static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
            return lhs.priority < rhs.priority
        }
        
        var icon: String {
            switch self {
            case .low: return "ℹ️"
            case .medium: return "⚠️"
            case .high: return "🚨"
            case .critical: return "💥"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupErrorHandling()
    }
    
    // MARK: - Public Methods
    
    /// Handle an error with unified categorization and user feedback
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Additional context about where the error occurred
    ///   - severity: The severity level of the error
    ///   - category: The category of the error
    func handleError(
        _ error: Error,
        context: String? = nil,
        severity: ErrorSeverity = .medium,
        category: ErrorCategory = .unknown
    ) {
        let unifiedError = UnifiedError(
            error: error,
            context: context,
            severity: severity,
            category: category,
            timestamp: Date()
        )
        
        // Log the error
        Logger.error("Error handled: \(unifiedError.description)")
        
        // Add to history
        addToHistory(unifiedError)
        
        // Handle based on severity
        switch severity {
        case .low:
            handleLowSeverityError(unifiedError)
        case .medium:
            handleMediumSeverityError(unifiedError)
        case .high:
            handleHighSeverityError(unifiedError)
        case .critical:
            handleCriticalError(unifiedError)
        }
        
        // Attempt automatic recovery
        attemptAutomaticRecovery(for: unifiedError)
    }
    
    /// Handle ImageViewerError with automatic categorization
    /// - Parameter error: The ImageViewerError to handle
    func handleImageViewerError(_ error: ImageViewerError) {
        let (category, severity) = categorizeImageViewerError(error)
        handleError(error, severity: severity, category: category)
    }
    
    /// Handle system errors with automatic categorization
    /// - Parameter error: The system error to handle
    func handleSystemError(_ error: Error) {
        let (category, severity) = categorizeSystemError(error)
        handleError(error, severity: severity, category: category)
    }
    
    /// Clear all active errors
    func clearAllErrors() {
        activeErrors.removeAll()
        Logger.info("All active errors cleared")
    }
    
    /// Clear errors of a specific category
    /// - Parameter category: The category of errors to clear
    func clearErrors(of category: ErrorCategory) {
        let beforeCount = activeErrors.count
        activeErrors.removeAll { $0.category == category }
        let afterCount = activeErrors.count
        
        if beforeCount != afterCount {
            Logger.info("Cleared \(beforeCount - afterCount) errors of category: \(category.rawValue)")
        }
    }
    
    /// Get error statistics
    /// - Returns: Error statistics for analytics
    func getErrorStatistics() -> ErrorStatistics {
        let totalErrors = errorHistory.count
        let errorsByCategory = Dictionary(grouping: errorHistory) { $0.error.category }
        let errorsBySeverity = Dictionary(grouping: errorHistory) { $0.error.severity }
        
        return ErrorStatistics(
            totalErrors: totalErrors,
            errorsByCategory: errorsByCategory.mapValues { $0.count },
            errorsBySeverity: errorsBySeverity.mapValues { $0.count },
            recentErrors: Array(errorHistory.suffix(10))
        )
    }
    
    // MARK: - Private Methods
    
    private func setupErrorHandling() {
        // Observe memory pressure notifications
        NotificationCenter.default.publisher(for: .memoryPressureDetected)
            .sink { [weak self] notification in
                if let pressureLevel = notification.object as? MemoryManagementService.MemoryPressureLevel {
                    self?.handleMemoryPressure(pressureLevel)
                }
            }
            .store(in: &cancellables)
        
        // Observe system notifications
        NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.handleSystemWake()
            }
            .store(in: &cancellables)
    }
    
    private func addToHistory(_ error: UnifiedError) {
        let record = ErrorRecord(error: error, timestamp: Date())
        errorHistory.append(record)
        
        // Maintain history size
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst()
        }
    }
    
    private func handleLowSeverityError(_ error: UnifiedError) {
        // Log only, no user notification needed
        Logger.info("Low severity error: \(error.description)")
    }
    
    private func handleMediumSeverityError(_ error: UnifiedError) {
        // Show user notification
        ErrorHandlingService.shared.showNotification(
            error.userMessage,
            type: .warning
        )
        
        // Add to active errors if space available
        if activeErrors.count < maxActiveErrors {
            activeErrors.append(error)
        }
    }
    
    private func handleHighSeverityError(_ error: UnifiedError) {
        // Show user notification
        ErrorHandlingService.shared.showNotification(
            error.userMessage,
            type: .error
        )
        
        // Add to active errors (replace lowest priority if needed)
        if activeErrors.count >= maxActiveErrors {
            if let lowestPriorityIndex = activeErrors.enumerated().min(by: { $0.element.severity < $1.element.severity })?.offset {
                activeErrors[lowestPriorityIndex] = error
            }
        } else {
            activeErrors.append(error)
        }
        
        // Show modal error if critical
        if error.severity == .critical {
            ErrorHandlingService.shared.showModalError(error.error, title: error.title)
        }
    }
    
    private func handleCriticalError(_ error: UnifiedError) {
        // Always show modal error for critical errors
        ErrorHandlingService.shared.showModalError(error.error, title: error.title)
        
        // Add to active errors (replace any existing)
        if !activeErrors.contains(where: { $0.id == error.id }) {
            if activeErrors.count >= maxActiveErrors {
                activeErrors.removeFirst()
            }
            activeErrors.append(error)
        }
        
        // Log critical error
        Logger.error("Critical error occurred: \(error.description)")
    }
    
    private func attemptAutomaticRecovery(for error: UnifiedError) {
        // Attempt automatic recovery based on error type
        switch error.category {
        case .memory:
            Task {
                await MemoryManagementService.shared.optimizeMemory(aggressive: false)
            }
        case .fileSystem:
            // Attempt to refresh file system state
            NotificationCenter.default.post(name: .fileSystemRefreshRequested, object: nil)
        case .security:
            // Attempt to refresh security-scoped access
            NotificationCenter.default.post(name: .securityAccessRefreshRequested, object: nil)
        default:
            break
        }
    }
    
    private func categorizeImageViewerError(_ error: ImageViewerError) -> (ErrorCategory, ErrorSeverity) {
        switch error {
        case .folderAccessDenied:
            return (.security, .high)
        case .folderNotFound:
            return (.fileSystem, .medium)
        case .noImagesFound:
            return (.validation, .low)
        case .folderScanningFailed:
            return (.fileSystem, .medium)
        case .unsupportedImageFormat:
            return (.validation, .medium)
        case .corruptedImage:
            return (.fileSystem, .medium)
        case .fileSystemError:
            return (.fileSystem, .high)
        case .insufficientMemory:
            return (.memory, .high)
        case .scanningFailed:
            return (.fileSystem, .medium)
        case .folderNotFound:
            return (.fileSystem, .medium)
        case .folderScanningFailed:
            return (.fileSystem, .medium)
        case .bookmarkResolutionFailed:
            return (.security, .high)
        case .imageLoadingFailed:
            return (.fileSystem, .medium)
        default:
            return (.unknown, .medium)
        }
    }
    
    private func categorizeSystemError(_ error: Error) -> (ErrorCategory, ErrorSeverity) {
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSCocoaErrorDomain:
            switch nsError.code {
            case NSFileReadNoPermissionError:
                return (.security, .high)
            case NSFileReadNoSuchFileError:
                return (.fileSystem, .medium)
            case 260:
                return (.fileSystem, .medium)
            default:
                return (.fileSystem, .medium)
            }
        case NSURLErrorDomain:
            return (.network, .medium)
        case NSOSStatusErrorDomain:
            return (.system, .medium)
        default:
            return (.unknown, .medium)
        }
    }
    
    private func handleMemoryPressure(_ pressureLevel: MemoryManagementService.MemoryPressureLevel) {
        let error = UnifiedError(
            error: NSError(domain: "MemoryPressure", code: -1, userInfo: [NSLocalizedDescriptionKey: "System memory pressure detected"]),
            context: "System memory pressure",
            severity: pressureLevel == .critical ? .critical : .high,
            category: .memory,
            timestamp: Date()
        )
        
        handleError(error.error, context: error.context, severity: error.severity, category: error.category)
    }
    
    private func handleSystemWake() {
        // Handle system wake events
        Logger.info("System wake detected, refreshing error state")
        
        // Clear stale errors
        let staleThreshold = Date().timeIntervalSince1970 - 300 // 5 minutes
        activeErrors.removeAll { $0.timestamp.timeIntervalSince1970 < staleThreshold }
    }
}

// MARK: - Supporting Types

/// Unified error representation
struct UnifiedError: Identifiable, Equatable {
    let id = UUID()
    let error: Error
    let context: String?
    let severity: UnifiedErrorHandlingService.ErrorSeverity
    let category: UnifiedErrorHandlingService.ErrorCategory
    let timestamp: Date
    
    // Custom Equatable implementation since Error doesn't conform to Equatable
    static func == (lhs: UnifiedError, rhs: UnifiedError) -> Bool {
        return lhs.id == rhs.id &&
               lhs.context == rhs.context &&
               lhs.severity == rhs.severity &&
               lhs.category == rhs.category &&
               lhs.timestamp == rhs.timestamp &&
               lhs.error.localizedDescription == rhs.error.localizedDescription
    }
    
    var title: String {
        return "\(category.icon) \(category.rawValue) Error"
    }
    
    var userMessage: String {
        if let context = context {
            return "\(context): \(error.localizedDescription)"
        } else {
            return error.localizedDescription
        }
    }
    
    var description: String {
        return "\(severity.icon) \(category.rawValue) - \(userMessage)"
    }
    
    var recoverySuggestion: String? {
        return (error as? LocalizedError)?.recoverySuggestion
    }
}

/// Error record for history tracking
struct ErrorRecord: Identifiable {
    let id = UUID()
    let error: UnifiedError
    let timestamp: Date
}

/// Error statistics for analytics
struct ErrorStatistics {
    let totalErrors: Int
    let errorsByCategory: [UnifiedErrorHandlingService.ErrorCategory: Int]
    let errorsBySeverity: [UnifiedErrorHandlingService.ErrorSeverity: Int]
    let recentErrors: [ErrorRecord]
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let fileSystemRefreshRequested = Notification.Name("fileSystemRefreshRequested")
    static let securityAccessRefreshRequested = Notification.Name("securityAccessRefreshRequested")
}

// MARK: - Service Integration

extension ErrorHandlingService {
    /// Handle error through unified error handling service
    /// - Parameter error: The error to handle
    @MainActor
    func handleErrorThroughUnifiedService(_ error: Error) {
        UnifiedErrorHandlingService.shared.handleError(error)
    }
}
