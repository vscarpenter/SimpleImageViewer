import SwiftUI

struct ContentView: View {
    // MARK: - State Properties
    @StateObject private var imageViewerViewModel = ImageViewerViewModel()
    @StateObject private var errorHandlingService = ErrorHandlingService.shared
    @State private var showImageViewer = false
    
    // MARK: - Body
    var body: some View {
        mainContent
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(alignment: .topTrailing) {
                notificationOverlay
            }
            .overlay {
                modalErrorOverlay
            }
            .overlay {
                permissionRequestOverlay
            }
            .onAppear {
                setupApplication()
            }
            .onReceive(NotificationCenter.default.publisher(for: .folderSelected)) { notification in
                handleFolderSelection(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .requestFolderSelection)) { _ in
                showImageViewer = false
            }
            .background(InvisibleKeyCapture(keyHandler: KeyboardHandler(imageViewerViewModel: imageViewerViewModel)))
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var mainContent: some View {
        GeometryReader { geometry in
            ZStack {
                if showImageViewer && imageViewerViewModel.totalImages > 0 {
                    imageViewerInterface(geometry: geometry)
                } else {
                    folderSelectionInterface
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    @ViewBuilder
    private func imageViewerInterface(geometry: GeometryProxy) -> some View {
        ZStack {
            ImageDisplayView(viewModel: imageViewerViewModel)
                .frame(width: geometry.size.width, height: geometry.size.height)
            
            NavigationControlsView(viewModel: imageViewerViewModel) {
                showImageViewer = false
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    @ViewBuilder
    private var folderSelectionInterface: some View {
        FolderSelectionView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var notificationOverlay: some View {
        if !errorHandlingService.notifications.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(errorHandlingService.notifications) { notification in
                    notificationItem(notification)
                }
                Spacer()
            }
            .padding(.top, showImageViewer ? 60 : 20)
            .padding(.trailing, 20)
            .padding(.leading, 20)
            .allowsHitTesting(true)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Notifications")
        }
    }
    
    @ViewBuilder
    private func notificationItem(_ notification: NotificationItem) -> some View {
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
        }
        .frame(maxWidth: 400)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notification.type.accessibilityPrefix): \(notification.message)")
    }
    
    @ViewBuilder
    private var modalErrorOverlay: some View {
        if let modalError = errorHandlingService.modalError {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text(modalError.title)
                        .font(.headline)
                    Text(modalError.message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    Button("OK") {
                        errorHandlingService.clearModalError()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .frame(maxWidth: 400)
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
    }
    
    @ViewBuilder
    private var permissionRequestOverlay: some View {
        if errorHandlingService.showPermissionDialog,
           let permissionRequest = errorHandlingService.permissionRequest {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text(permissionRequest.title)
                        .font(.headline)
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
                        }
                        Button(permissionRequest.primaryAction.title) {
                            permissionRequest.primaryAction.action()
                            errorHandlingService.clearPermissionDialog()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
                .frame(maxWidth: 450)
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
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
    
    private func handleFolderSelection(_ notification: Notification) {
        if let folderContent = notification.object as? FolderContent {
            imageViewerViewModel.loadFolderContent(folderContent)
            showImageViewer = true
        }
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