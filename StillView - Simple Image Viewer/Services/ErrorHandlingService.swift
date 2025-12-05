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
            
            // Auto-dismiss after 5 seconds for non-error notifications
            if type != .error {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.removeNotification(notification)
                }
            }
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
            
        case .bookmarkResolutionFailed(let url):
            showPermissionRequest(PermissionRequestInfo(
                title: "Folder Access Expired",
                message: "Access to \"\(url.lastPathComponent)\" has expired and needs to be restored.",
                explanation: "macOS security requires apps to periodically renew access to folders outside the app sandbox.",
                primaryAction: PermissionAction(title: "Select Folder Again", action: {
                    NotificationCenter.default.post(name: .requestFolderSelection, object: nil)
                }),
                secondaryAction: PermissionAction(title: "Cancel", action: {})
            ))
            
        case .noImagesFound:
            showNotification(
                "No supported images found in the selected folder. " +
                "Please select a folder containing JPEG, PNG, GIF, HEIF, or other supported image files.",
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
                    if let activityMonitorURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                        NSWorkspace.shared.openApplication(at: activityMonitorURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
                    }
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
                    if let activityMonitorURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                        NSWorkspace.shared.openApplication(at: activityMonitorURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
                    }
                }),
                ModalErrorAction(title: "Try Smaller Images", action: {}),
                ModalErrorAction.defaultOK
            ])
            
        case .loadingCancelled:
            // Don't show notification for cancelled loading
            break
            
        case .fileSystemError:
            showNotification(
                "File system error: \(imageURL.lastPathComponent)",
                type: .error
            )
        }
    }
    
    /// Handle AI Analysis errors with appropriate user feedback
    /// - Parameters:
    ///   - error: The AIAnalysisError to handle
    ///   - retryAction: Optional retry action for recoverable errors
    func handleAIAnalysisError(_ error: AIAnalysisError, retryAction: (() -> Void)? = nil) {
        Logger.error("AI Analysis error: \(error.localizedDescription)", context: "AIAnalysis")
        
        // Don't show user notifications for errors that shouldn't be displayed
        guard error.shouldDisplayToUser else {
            return
        }
        
        switch error {
        case .featureNotAvailable:
            showNotification(
                "AI analysis requires macOS 26 or later",
                type: .warning
            )
            
        case .invalidImage, .unsupportedImageFormat:
            showNotification(
                error.localizedDescription ?? "Image format not supported for AI analysis",
                type: .warning
            )
            
        case .modelLoadingFailed(let model):
            showModalError(error, title: "AI Model Error", actions: [
                ModalErrorAction(title: "Restart App", action: {
                    NSApplication.shared.terminate(nil)
                }),
                ModalErrorAction.defaultOK
            ])
            
        case .analysisTimeout:
            if let retryAction = retryAction {
                showModalError(error, title: "Analysis Timeout", actions: [
                    ModalErrorAction(title: "Try Again", action: retryAction),
                    ModalErrorAction.defaultOK
                ])
            } else {
                showNotification(
                    "AI analysis timed out - try a smaller image",
                    type: .error
                )
            }
            
        case .insufficientMemory:
            showModalError(error, title: "Memory Warning", actions: [
                ModalErrorAction(title: "Activity Monitor", action: {
                    if let activityMonitorURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                        NSWorkspace.shared.openApplication(at: activityMonitorURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
                    }
                }),
                ModalErrorAction(title: "Try Again", action: retryAction ?? {}),
                ModalErrorAction.defaultOK
            ])
            
        case .preferenceSyncFailed:
            showModalError(error, title: "Preference Error", actions: [
                ModalErrorAction(title: "Open Preferences", action: {
                    NotificationCenter.default.post(name: .openPreferences, object: nil)
                }),
                ModalErrorAction(title: "Try Again", action: retryAction ?? {}),
                ModalErrorAction.defaultOK
            ])
            
        case .systemResourcesUnavailable:
            showModalError(error, title: "System Resources", actions: [
                ModalErrorAction(title: "Restart App", action: {
                    NSApplication.shared.terminate(nil)
                }),
                ModalErrorAction.defaultOK
            ])
            
        case .networkError, .coreMLError, .visionError:
            if let retryAction = retryAction, error.isRetryable {
                showModalError(error, title: "AI Analysis Error", actions: [
                    ModalErrorAction(title: "Try Again", action: retryAction),
                    ModalErrorAction.defaultOK
                ])
            } else {
                showNotification(
                    error.localizedDescription ?? "AI analysis failed",
                    type: .error
                )
            }
            
        case .notificationSystemFailed:
            // This is handled by handleNotificationSystemFailure
            showNotification(
                "AI notification system failed - some features may be limited",
                type: .warning
            )
            
        case .analysisInterrupted:
            // Don't show notification for interruptions as they're usually intentional
            break
        }
    }
    
    /// Handle AI Analysis errors with generic Error type (for compatibility)
    /// - Parameters:
    ///   - error: The error to handle
    ///   - retryAction: Optional retry action for recoverable errors
    func handleAIAnalysisError(_ error: Error, retryAction: (() -> Void)? = nil) {
        if let aiError = error as? AIAnalysisError {
            handleAIAnalysisError(aiError, retryAction: retryAction)
        } else {
            Logger.error("Generic AI analysis error: \(error.localizedDescription)", context: "AIAnalysis")
            showNotification(
                "AI analysis error: \(error.localizedDescription)",
                type: .error
            )
        }
    }
    
    /// Handle preference synchronization failures with fallback mechanisms
    /// - Parameters:
    ///   - error: The error that occurred during preference sync
    ///   - fallbackAction: Fallback action to attempt
    func handlePreferenceSyncFailure(_ error: Error, fallbackAction: @escaping () -> Void) {
        Logger.error("Preference synchronization failed: \(error.localizedDescription)", context: "PreferenceSync")
        
        // Attempt fallback mechanism
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            fallbackAction()
        }
        
        // Show user notification about the issue
        showNotification(
            "Preference sync failed - using fallback mechanism",
            type: .warning
        )
    }
    
    /// Handle notification system failures with graceful degradation
    /// - Parameter error: The notification system error
    func handleNotificationSystemFailure(_ error: Error) {
        Logger.error("Notification system failed: \(error.localizedDescription)", context: "NotificationSystem")
        
        // Clear any corrupted notification state
        notifications.removeAll()
        
        // Try to recover by posting a simple notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showNotification(
                "Notification system recovered",
                type: .info
            )
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
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications.removeAll { $0.id == notification.id }
        }
    }
    
    /// Clear all notifications
    func clearAllNotifications() {
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications.removeAll()
        }
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
    static let showWhatsNew = Notification.Name("showWhatsNew")
    static let whatsNewDismissed = Notification.Name("whatsNewDismissed")
    static let openPreferences = Notification.Name("openPreferences")
    static let notificationSystemFailure = Notification.Name("notificationSystemFailure")
    // aiInsightsInitializationComplete is defined in SimpleImageViewerApp.swift
    // aiAnalysisPreferenceDidChange, imageEnhancementsPreferenceDidChange, and aiCaptionPreferencesDidChange are defined in PreferencesService.swift
}
