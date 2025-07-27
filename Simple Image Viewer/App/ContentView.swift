import SwiftUI

struct ContentView: View {
    // MARK: - State Properties
    @StateObject private var imageViewerViewModel = ImageViewerViewModel()
    @StateObject private var errorHandlingService = ErrorHandlingService.shared
    @State private var showImageViewer = false
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showImageViewer && imageViewerViewModel.totalImages > 0 {
                    // Main image viewer interface
                    ZStack {
                        // Main image display (full screen)
                        ImageDisplayView(viewModel: imageViewerViewModel)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        
                        // Navigation controls overlay
                        NavigationControlsView(viewModel: imageViewerViewModel) {
                            // Exit to folder selection
                            showImageViewer = false
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                } else {
                    // Folder selection interface
                    FolderSelectionView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
        .overlay(alignment: .topTrailing) {
            // Notification container for non-intrusive messages
            if !errorHandlingService.notifications.isEmpty {
                VStack(alignment: .trailing, spacing: 8) {
                    ForEach(errorHandlingService.notifications) { notification in
                        HStack {
                            Text(notification.message)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(notification.type.color.opacity(0.9))
                                .cornerRadius(8)
                                .lineLimit(3)
                                .accessibilityHidden(true)
                            Button("×") {
                                errorHandlingService.removeNotification(notification)
                            }
                            .foregroundColor(.white)
                            .padding(.leading, 4)
                            .accessibilityLabel("Dismiss notification")
                            .accessibilityHint("Removes this notification from view")
                        }
                        .frame(maxWidth: 400)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(notification.type.accessibilityPrefix): \(notification.message)")
                        .accessibilityAction(named: "Dismiss") {
                            errorHandlingService.removeNotification(notification)
                        }
                    }
                    Spacer()
                }
                .padding(.top, showImageViewer ? 60 : 20)
                .padding(.trailing, 20)
                .padding(.leading, 20) // Ensure it doesn't extend beyond left edge
                .allowsHitTesting(true)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Notifications")
            }
        }
        .overlay {
            // Modal error dialog
            if let modalError = errorHandlingService.modalError {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Prevent dismissal by background tap for errors
                        }
                    
                    VStack(spacing: 20) {
                        Text(modalError.title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text(modalError.message)
                            .font(.body)
                            .multilineTextAlignment(.center)
                        Button("OK") {
                            errorHandlingService.clearModalError()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("OK")
                        .accessibilityHint("Dismisses the error dialog")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Error dialog: \(modalError.title). \(modalError.message)")
                    .padding(24)
                    .frame(maxWidth: 400)
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
                .animation(.easeInOut(duration: 0.2), value: errorHandlingService.modalError != nil)
            }
        }
        .overlay {
            // Permission request dialog
            if errorHandlingService.showPermissionDialog,
               let permissionRequest = errorHandlingService.permissionRequest {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Prevent dismissal by background tap for permission requests
                        }
                    
                    VStack(spacing: 20) {
                        Text(permissionRequest.title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text(permissionRequest.message)
                            .font(.body)
                            .multilineTextAlignment(.center)
                        Text(permissionRequest.explanation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            if let secondaryAction = permissionRequest.secondaryAction {
                                Button(secondaryAction.title) {
                                    secondaryAction.action()
                                    errorHandlingService.clearPermissionDialog()
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel(secondaryAction.title)
                            }
                            Button(permissionRequest.primaryAction.title) {
                                permissionRequest.primaryAction.action()
                                errorHandlingService.clearPermissionDialog()
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel(permissionRequest.primaryAction.title)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Permission request: \(permissionRequest.title). \(permissionRequest.message)")
                    .padding(24)
                    .frame(maxWidth: 450)
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
                .animation(.easeInOut(duration: 0.2), value: errorHandlingService.showPermissionDialog)
            }
        }
        .onAppear {
            setupApplication()
        }
        .onReceive(NotificationCenter.default.publisher(for: .folderSelected)) { notification in
            if let folderContent = notification.object as? FolderContent {
                imageViewerViewModel.loadFolderContent(folderContent)
                showImageViewer = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestFolderSelection)) { _ in
            // Handle request to show folder selection (from error handling)
            showImageViewer = false
        }
        .focusable()
        .onKeyPress(.leftArrow) {
            imageViewerViewModel.previousImage()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            imageViewerViewModel.nextImage()
            return .handled
        }
        .onKeyPress(.space) {
            imageViewerViewModel.nextImage()
            return .handled
        }
        .onKeyPress(.escape) {
            // Exit to folder selection when viewing images
            if showImageViewer {
                showImageViewer = false
                return .handled
            }
            return .ignored
        }
        .onTapGesture {
            // Ensure the view can receive keyboard events by requesting focus
        }
    }
    
    // MARK: - Private Methods
    
    private func setupApplication() {
        restoreApplicationState()
    }
    
    private func restoreApplicationState() {
        let preferencesService = DefaultPreferencesService()
        
        // Restore other preferences
        imageViewerViewModel.showFileName = preferencesService.showFileName
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let folderSelected = Notification.Name("folderSelected")
}


// MARK: - Preview
#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}