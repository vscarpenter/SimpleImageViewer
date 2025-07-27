import Foundation

/// Errors that can occur in the Image Viewer application
enum ImageViewerError: LocalizedError, Equatable {
    case folderAccessDenied
    case noImagesFound
    case imageLoadingFailed(URL)
    case corruptedImage(URL)
    case insufficientMemory
    case unsupportedImageFormat(String)
    case fileSystemError(Error)
    case scanningFailed(Error)
    case folderNotFound(URL)
    case folderScanningFailed(Error)
    
    /// Localized error description for user display
    var errorDescription: String? {
        switch self {
        case .folderAccessDenied:
            return NSLocalizedString(
                "Unable to access the selected folder. Please check permissions and try again.",
                comment: "Error message when folder access is denied"
            )
        case .noImagesFound:
            return NSLocalizedString(
                "No supported images found in the selected folder. Please select a different folder.",
                comment: "Error message when no images are found in folder"
            )
        case .imageLoadingFailed(let url):
            return String(format: NSLocalizedString(
                "Failed to load image: %@",
                comment: "Error message when image loading fails"
            ), url.lastPathComponent)
        case .corruptedImage(let url):
            return String(format: NSLocalizedString(
                "Image appears to be corrupted: %@",
                comment: "Error message when image is corrupted"
            ), url.lastPathComponent)
        case .insufficientMemory:
            return NSLocalizedString(
                "Not enough memory to load this image. Try closing other applications.",
                comment: "Error message when there's insufficient memory"
            )
        case .unsupportedImageFormat(let format):
            return String(format: NSLocalizedString(
                "Unsupported image format: %@",
                comment: "Error message for unsupported image format"
            ), format)
        case .fileSystemError(let error):
            return String(format: NSLocalizedString(
                "File system error: %@",
                comment: "Error message for file system errors"
            ), error.localizedDescription)
        case .scanningFailed(let error):
            return String(format: NSLocalizedString(
                "Failed to scan folder: %@",
                comment: "Error message when folder scanning fails"
            ), error.localizedDescription)
        case .folderNotFound(let url):
            return String(format: NSLocalizedString(
                "Folder not found: %@",
                comment: "Error message when folder is not found"
            ), url.lastPathComponent)
        case .folderScanningFailed(let error):
            return String(format: NSLocalizedString(
                "Failed to scan folder: %@",
                comment: "Error message when folder scanning fails"
            ), error.localizedDescription)
        }
    }
    
    /// Failure reason for debugging
    var failureReason: String? {
        switch self {
        case .folderAccessDenied:
            return "The application does not have permission to access the selected folder."
        case .noImagesFound:
            return "The selected folder does not contain any supported image files."
        case .imageLoadingFailed(let url):
            return "Failed to load image from URL: \(url.absoluteString)"
        case .corruptedImage(let url):
            return "Image file is corrupted or unreadable: \(url.absoluteString)"
        case .insufficientMemory:
            return "System is low on memory and cannot load the requested image."
        case .unsupportedImageFormat(let format):
            return "Image format '\(format)' is not supported by this application."
        case .fileSystemError(let error):
            return "Underlying file system error: \(error.localizedDescription)"
        case .scanningFailed(let error):
            return "Folder scanning operation failed: \(error.localizedDescription)"
        case .folderNotFound(let url):
            return "Folder no longer exists at path: \(url.path)"
        case .folderScanningFailed(let error):
            return "Folder scanning operation failed: \(error.localizedDescription)"
        }
    }
    
    /// Recovery suggestion for the user
    var recoverySuggestion: String? {
        switch self {
        case .folderAccessDenied:
            return NSLocalizedString(
                "Try selecting a different folder or check the folder permissions in Finder.",
                comment: "Recovery suggestion for folder access denied"
            )
        case .noImagesFound:
            return NSLocalizedString(
                "Select a folder that contains JPEG, PNG, GIF, HEIF, or other supported image files.",
                comment: "Recovery suggestion when no images found"
            )
        case .imageLoadingFailed:
            return NSLocalizedString(
                "Try navigating to a different image or restart the application.",
                comment: "Recovery suggestion for image loading failure"
            )
        case .corruptedImage:
            return NSLocalizedString(
                "Skip this image and try viewing others in the folder.",
                comment: "Recovery suggestion for corrupted image"
            )
        case .insufficientMemory:
            return NSLocalizedString(
                "Close other applications to free up memory, or try viewing smaller images.",
                comment: "Recovery suggestion for insufficient memory"
            )
        case .unsupportedImageFormat:
            return NSLocalizedString(
                "Convert the image to a supported format (JPEG, PNG, GIF, etc.) or use a different image.",
                comment: "Recovery suggestion for unsupported format"
            )
        case .fileSystemError, .scanningFailed:
            return NSLocalizedString(
                "Try selecting a different folder or restart the application.",
                comment: "Recovery suggestion for file system errors"
            )
        case .folderNotFound:
            return NSLocalizedString(
                "The folder may have been moved or deleted. Please select a different folder.",
                comment: "Recovery suggestion when folder is not found"
            )
        case .folderScanningFailed:
            return NSLocalizedString(
                "Try selecting a different folder or restart the application.",
                comment: "Recovery suggestion for folder scanning failure"
            )
        }
    }
    
    // MARK: - Equatable Implementation
    static func == (lhs: ImageViewerError, rhs: ImageViewerError) -> Bool {
        switch (lhs, rhs) {
        case (.folderAccessDenied, .folderAccessDenied),
             (.noImagesFound, .noImagesFound),
             (.insufficientMemory, .insufficientMemory):
            return true
        case (.imageLoadingFailed(let lhsURL), .imageLoadingFailed(let rhsURL)):
            return lhsURL == rhsURL
        case (.corruptedImage(let lhsURL), .corruptedImage(let rhsURL)):
            return lhsURL == rhsURL
        case (.unsupportedImageFormat(let lhsFormat), .unsupportedImageFormat(let rhsFormat)):
            return lhsFormat == rhsFormat
        case (.folderNotFound(let lhsURL), .folderNotFound(let rhsURL)):
            return lhsURL == rhsURL
        case (.fileSystemError(let lhsError), .fileSystemError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.scanningFailed(let lhsError), .scanningFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.folderScanningFailed(let lhsError), .folderScanningFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

