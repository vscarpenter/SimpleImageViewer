import Foundation

/// Errors that can occur during AI image analysis
enum AIAnalysisError: LocalizedError, Equatable {
    case featureNotAvailable
    case invalidImage
    case modelLoadingFailed(String)
    case analysisTimeout
    case insufficientMemory
    case networkError(Error)
    case coreMLError(Error)
    case visionError(Error)
    case unsupportedImageFormat
    case analysisInterrupted
    case preferenceSyncFailed
    case notificationSystemFailed
    case systemResourcesUnavailable
    
    var errorDescription: String? {
        switch self {
        case .featureNotAvailable:
            return "AI analysis is not available on this system"
        case .invalidImage:
            return "The image format is not supported for AI analysis"
        case .modelLoadingFailed(let model):
            return "Failed to load AI model: \(model)"
        case .analysisTimeout:
            return "AI analysis timed out"
        case .insufficientMemory:
            return "Not enough memory available for AI analysis"
        case .networkError:
            return "Network error during AI analysis"
        case .coreMLError(let error):
            return "Core ML error: \(error.localizedDescription)"
        case .visionError(let error):
            return "Vision framework error: \(error.localizedDescription)"
        case .unsupportedImageFormat:
            return "Image format not supported for AI analysis"
        case .analysisInterrupted:
            return "AI analysis was interrupted"
        case .preferenceSyncFailed:
            return "Failed to synchronize AI preferences"
        case .notificationSystemFailed:
            return "AI notification system failed"
        case .systemResourcesUnavailable:
            return "System resources required for AI analysis are unavailable"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .featureNotAvailable:
            return "AI analysis requires macOS 26 or later. Please update your system to use this feature."
        case .invalidImage:
            return "Try selecting a different image in a supported format (JPEG, PNG, HEIF)."
        case .modelLoadingFailed:
            return "Restart the application or check if AI models are properly installed."
        case .analysisTimeout:
            return "Try analyzing a smaller image or restart the application."
        case .insufficientMemory:
            return "Close other applications to free up memory, or try analyzing smaller images."
        case .networkError:
            return "Check your internet connection and try again."
        case .coreMLError, .visionError:
            return "Restart the application or try analyzing a different image."
        case .unsupportedImageFormat:
            return "Convert the image to a supported format (JPEG, PNG, HEIF) and try again."
        case .analysisInterrupted:
            return "Try the analysis again."
        case .preferenceSyncFailed:
            return "Check your preferences settings and try enabling AI analysis again."
        case .notificationSystemFailed:
            return "Restart the application to restore AI notifications."
        case .systemResourcesUnavailable:
            return "Restart the application or check system resources."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .featureNotAvailable:
            return "The system does not support AI image analysis features."
        case .invalidImage:
            return "The image could not be processed by the AI analysis engine."
        case .modelLoadingFailed:
            return "Required AI models could not be loaded."
        case .analysisTimeout:
            return "The analysis took too long to complete."
        case .insufficientMemory:
            return "The system ran out of memory during analysis."
        case .networkError:
            return "A network connection is required for this AI feature."
        case .coreMLError:
            return "The Core ML framework encountered an error."
        case .visionError:
            return "The Vision framework encountered an error."
        case .unsupportedImageFormat:
            return "The image format is not compatible with AI analysis."
        case .analysisInterrupted:
            return "The analysis process was stopped before completion."
        case .preferenceSyncFailed:
            return "AI preference changes could not be applied."
        case .notificationSystemFailed:
            return "The AI notification system is not functioning properly."
        case .systemResourcesUnavailable:
            return "Required system resources for AI analysis are not available."
        }
    }
    
    /// Whether this error should be retryable
    var isRetryable: Bool {
        switch self {
        case .featureNotAvailable, .invalidImage, .unsupportedImageFormat:
            return false
        case .modelLoadingFailed, .analysisTimeout, .insufficientMemory, .networkError, 
             .coreMLError, .visionError, .analysisInterrupted, .preferenceSyncFailed, 
             .notificationSystemFailed, .systemResourcesUnavailable:
            return true
        }
    }
    
    /// Whether this error should be shown to the user
    var shouldDisplayToUser: Bool {
        switch self {
        case .analysisInterrupted:
            return false // Don't show interruption errors as they're usually intentional
        default:
            return true
        }
    }
    
    static func == (lhs: AIAnalysisError, rhs: AIAnalysisError) -> Bool {
        switch (lhs, rhs) {
        case (.featureNotAvailable, .featureNotAvailable),
             (.invalidImage, .invalidImage),
             (.analysisTimeout, .analysisTimeout),
             (.insufficientMemory, .insufficientMemory),
             (.unsupportedImageFormat, .unsupportedImageFormat),
             (.analysisInterrupted, .analysisInterrupted),
             (.preferenceSyncFailed, .preferenceSyncFailed),
             (.notificationSystemFailed, .notificationSystemFailed),
             (.systemResourcesUnavailable, .systemResourcesUnavailable):
            return true
        case (.modelLoadingFailed(let lhsModel), .modelLoadingFailed(let rhsModel)):
            return lhsModel == rhsModel
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.coreMLError(let lhsError), .coreMLError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.visionError(let lhsError), .visionError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}