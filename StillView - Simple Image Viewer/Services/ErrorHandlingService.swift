import Foundation
import SwiftUI
import Combine

// MARK: - Notification Types
// NotificationType is defined in NotificationView.swift

// NotificationItem is defined in NotificationView.swift

/// Service for managing error handling and user feedback throughout the application
class ErrorHandlingService: ObservableObject {
    // MARK: - Published Properties
    
    /// Current notifications to display
    @Published var notifications: [NotificationItem] = []
    
    /// Current modal error (for critical errors that require user attention)
    @Published var modalError: ModalErrorInfo?
    
    /// Whether a permission dialog should be shown
    @Published var showPermissionDialog: Bool = false
    
    /// Current permission request information
    @Published var permissionRequest: PermissionRequestInfo?
    
    // MARK: - Private Properties
    
    private let maxNotifications = 3
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = ErrorHandlingService()
    
    private init() {
        setupNotificationCleanup()
    }
    
    // MARK: - Public Methods
    
    /// Show a non-intrusive notification for minor errors or information
    /// - Parameters:
    ///   - message: The message to display
    ///   - type: The type of notification
    func showNotification(_ message: String, type: NotificationView.NotificationType) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove oldest notification if we're at the limit
            if self.notifications.count >= self.maxNotifications {
                self.notifications.removeFirst()
            }
            
            let notification = NotificationItem(message: message, type: type)
            self.notifications.append(notification)
        }
    }
    
    /// Show a modal error dialog for critical errors
    /// - Parameters:
    ///   - error: The error to display
    ///   - title: Optional custom title
    ///   - actions: Custom actions for the error dialog
    func showModalError(_ error: Error, title: String? = nil, actions: [ModalErrorAction] = []) {
        DispatchQueue.main.async { [weak self] in
            let errorInfo = ModalErrorInfo(
                error: error,
                title: title ?? "Error",
                actions: actions.isEmpty ? [ModalErrorAction.defaultOK] : actions
            )
            self?.modalError = errorInfo
        }
    }
    
    /// Show a permission request dialog
    /// - Parameter request: The permission request information
    func showPermissionRequest(_ request: PermissionRequestInfo) {
        DispatchQueue.main.async { [weak self] in
            self?.permissionRequest = request
            self?.showPermissionDialog = true
        }
    }
    
    /// Handle ImageViewerError with appropriate user feedback
    /// - Parameter error: The ImageViewerError to handle
    func handleImageViewerError(_ error: ImageViewerError) {
        switch error {
        case .folderAccessDenied:
            showPermissionRequest(PermissionRequestInfo(
                title: "Folder Access Required",
                message: "StillView - Simple Image Viewer needs permission to access the selected folder to display images.",
                explanation: "This app is sandboxed for your security and can only access folders you explicitly select.",
                primaryAction: PermissionAction(title: "Select Different Folder", action: {
                    NotificationCenter.default.post(name: .requestFolderSelection, object: nil)
                }),
                secondaryAction: PermissionAction(title: "Cancel", action: {})
            ))
            
        case .noImagesFound:
            showNotification(
                "No supported images found in the selected folder. Please select a folder containing JPEG, PNG, GIF, HEIF, or other supported image files.",
                type: .warning
            )
            
        case .imageLoadingFailed(let url):
            showNotification(
                "Failed to load image: \(url.lastPathComponent)",
                type: .error
            )
            
        case .corruptedImage(let url):
            showNotification(
                "Skipped corrupted image: \(url.lastPathComponent)",
                type: .warning
            )
            
        case .insufficientMemory:
            showModalError(error, title: "Memory Warning", actions: [
                ModalErrorAction(title: "Close Other Apps", action: {
                    NSWorkspace.shared.launchApplication("Activity Monitor")
                }),
                ModalErrorAction.defaultOK
            ])
            
        case .unsupportedImageFormat(let format):
            showNotification(
                "Skipped unsupported image format: \(format)",
                type: .warning
            )
            
        case .fileSystemError(let underlyingError):
            showModalError(underlyingError, title: "File System Error")
            
        case .scanningFailed(let underlyingError):
            showModalError(underlyingError, title: "Folder Scanning Failed")
            
        case .folderNotFound(let url):
            showNotification(
                "Folder no longer exists: \(url.lastPathComponent)",
                type: .error
            )
            
        case .folderScanningFailed(let underlyingError):
            showModalError(underlyingError, title: "Failed to Scan Folder")
        }
    }
    
    /// Handle ImageLoaderError with appropriate user feedback
    /// - Parameters:
    ///   - error: The ImageLoaderError to handle
    ///   - imageURL: The URL of the image that failed to load
    func handleImageLoaderError(_ error: ImageLoaderError, imageURL: URL) {
        switch error {
        case .fileNotFound:
            showNotification(
                "Image file not found: \(imageURL.lastPathComponent)",
                type: .error
            )
            
        case .unsupportedFormat:
            showNotification(
                "Skipped unsupported image: \(imageURL.lastPathComponent)",
                type: .warning
            )
            
        case .corruptedImage:
            showNotification(
                "Skipped corrupted image: \(imageURL.lastPathComponent)",
                type: .warning
            )
            
        case .insufficientMemory:
            showModalError(error, title: "Memory Warning", actions: [
                ModalErrorAction(title: "Close Other Apps", action: {
                    NSWorkspace.shared.launchApplication("Activity Monitor")
                }),
                ModalErrorAction(title: "Try Smaller Images", action: {}),
                ModalErrorAction.defaultOK
            ])
            
        case .loadingCancelled:
            // Don't show notification for cancelled loading
            break
        }
    }
    
    /// Clear the current modal error
    func clearModalError() {
        modalError = nil
    }
    
    /// Clear the permission dialog
    func clearPermissionDialog() {
        showPermissionDialog = false
        permissionRequest = nil
    }
    
    /// Remove a specific notification
    /// - Parameter notification: The notification to remove
    func removeNotification(_ notification: NotificationItem) {
        notifications.removeAll { $0.id == notification.id }
    }
    
    /// Clear all notifications
    func clearAllNotifications() {
        notifications.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationCleanup() {
        // Clean up old notifications every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupOldNotifications()
            }
            .store(in: &cancellables)
    }
    
    private func cleanupOldNotifications() {
        let cutoffTime = Date().addingTimeInterval(-60) // Remove notifications older than 1 minute
        notifications.removeAll { $0.timestamp < cutoffTime }
    }
}

// MARK: - Supporting Data Models

/// Information for modal error dialogs
struct ModalErrorInfo: Identifiable {
    let id = UUID()
    let error: Error
    let title: String
    let actions: [ModalErrorAction]
    
    var message: String {
        return error.localizedDescription
    }
    
    var recoverySuggestion: String? {
        if let imageViewerError = error as? ImageViewerError {
            return imageViewerError.recoverySuggestion
        }
        return nil
    }
}

/// Action for modal error dialogs
struct ModalErrorAction {
    let title: String
    let action: () -> Void
    let isDestructive: Bool
    
    init(title: String, action: @escaping () -> Void, isDestructive: Bool = false) {
        self.title = title
        self.action = action
        self.isDestructive = isDestructive
    }
    
    static let defaultOK = ModalErrorAction(title: "OK", action: {})
}

/// Information for permission request dialogs
struct PermissionRequestInfo {
    let title: String
    let message: String
    let explanation: String
    let primaryAction: PermissionAction
    let secondaryAction: PermissionAction?
    
    init(title: String, message: String, explanation: String, primaryAction: PermissionAction, secondaryAction: PermissionAction? = nil) {
        self.title = title
        self.message = message
        self.explanation = explanation
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
}

/// Action for permission dialogs
struct PermissionAction {
    let title: String
    let action: () -> Void
}

// MARK: - Notification Names

extension Notification.Name {
    static let requestFolderSelection = Notification.Name("requestFolderSelection")
}