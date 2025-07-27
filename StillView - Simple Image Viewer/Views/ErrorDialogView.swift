import SwiftUI

/// A view that displays error messages in a user-friendly dialog
struct ErrorDialogView: View {
    let error: ImageViewerError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    init(error: ImageViewerError, onDismiss: @escaping () -> Void, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: errorIcon)
                .font(.system(size: 48))
                .foregroundColor(.red)
                .accessibilityLabel("Error")
            
            // Error title
            Text(errorTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Error message
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Action buttons
            HStack(spacing: 12) {
                if let onRetry = onRetry {
                    Button("Try Again") {
                        onRetry()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                
                Button("OK") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    private var errorIcon: String {
        switch error {
        case .folderAccessDenied:
            return "lock.fill"
        case .bookmarkResolutionFailed:
            return "key.fill"
        case .noImagesFound:
            return "photo.on.rectangle"
        case .imageLoadingFailed, .corruptedImage:
            return "exclamationmark.triangle.fill"
        case .insufficientMemory:
            return "memorychip.fill"
        case .unsupportedImageFormat:
            return "doc.questionmark.fill"
        case .fileSystemError, .scanningFailed, .folderScanningFailed:
            return "folder.fill.badge.questionmark"
        case .folderNotFound:
            return "folder.badge.minus"
        }
    }
    
    private var errorTitle: String {
        switch error {
        case .folderAccessDenied:
            return "Access Denied"
        case .bookmarkResolutionFailed:
            return "Access Expired"
        case .noImagesFound:
            return "No Images Found"
        case .imageLoadingFailed:
            return "Failed to Load Image"
        case .corruptedImage:
            return "Corrupted Image"
        case .insufficientMemory:
            return "Memory Error"
        case .unsupportedImageFormat:
            return "Unsupported Format"
        case .fileSystemError:
            return "File System Error"
        case .scanningFailed, .folderScanningFailed:
            return "Scanning Failed"
        case .folderNotFound:
            return "Folder Not Found"
        }
    }
}

#Preview {
    ErrorDialogView(
        error: .noImagesFound,
        onDismiss: {},
        onRetry: {}
    )
    .frame(width: 500, height: 300)
}