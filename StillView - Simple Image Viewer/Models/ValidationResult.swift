import Foundation

/// Result of a validation operation with severity and user feedback
struct ValidationResult {
    
    // MARK: - Properties
    
    /// Whether the validation passed
    let isValid: Bool
    
    /// User-friendly message describing the validation result
    let message: String?
    
    /// Severity level of the validation result
    let severity: ValidationSeverity
    
    /// Optional suggestion for fixing validation issues
    let suggestion: String?
    
    // MARK: - Initialization
    
    init(
        isValid: Bool,
        message: String? = nil,
        severity: ValidationSeverity = .info,
        suggestion: String? = nil
    ) {
        self.isValid = isValid
        self.message = message
        self.severity = severity
        self.suggestion = suggestion
    }
    
    // MARK: - Convenience Initializers
    
    /// Create a successful validation result
    static func success(message: String? = nil) -> ValidationResult {
        return ValidationResult(isValid: true, message: message, severity: .info)
    }
    
    /// Create a warning validation result
    static func warning(_ message: String, suggestion: String? = nil) -> ValidationResult {
        return ValidationResult(isValid: true, message: message, severity: .warning, suggestion: suggestion)
    }
    
    /// Create an error validation result
    static func error(_ message: String, suggestion: String? = nil) -> ValidationResult {
        return ValidationResult(isValid: false, message: message, severity: .error, suggestion: suggestion)
    }
    
    /// Create an info validation result
    static func info(_ message: String) -> ValidationResult {
        return ValidationResult(isValid: true, message: message, severity: .info)
    }
}

/// Severity levels for validation results
enum ValidationSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    /// Color associated with the severity level
    var color: Color {
        switch self {
        case .info:
            return .appInfo
        case .warning:
            return .appWarning
        case .error:
            return .appError
        }
    }
    
    /// Icon associated with the severity level
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        }
    }
    
    /// Icon name for the severity level (alias for icon)
    var iconName: String {
        return icon
    }
    
    /// Accessibility prefix for screen readers
    var accessibilityPrefix: String {
        switch self {
        case .info:
            return "Information"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
    }
    
    /// Accessibility label for screen readers
    var accessibilityLabel: String {
        return accessibilityPrefix
    }
}

// MARK: - Import SwiftUI for Color references

import SwiftUI