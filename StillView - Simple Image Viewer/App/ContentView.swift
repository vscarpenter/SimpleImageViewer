// swiftlint:disable file_length
import SwiftUI

struct ContentView: View {
    // MARK: - State Properties
    @StateObject private var imageViewerViewModel = ImageViewerViewModel()
    @StateObject private var errorHandlingService = ErrorHandlingService.shared
    @State private var showImageViewer = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Stage hover-arrow visibility (fade in on pointer move, out after ~3 s idle)
    @State private var stageArrowsVisible = false
    @State private var stageArrowsHideTask: Task<Void, Never>?

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
            .onReceive(NotificationCenter.default.publisher(for: .restoreWindowState)) { notification in
                handleWindowStateRestoration(notification)
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
                        // Toolbar owns the (hidden) title-bar region
                        .ignoresSafeArea(edges: .top)
                } else {
                    folderSelectionInterface
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    @ViewBuilder
    private func imageViewerInterface(geometry: GeometryProxy) -> some View {
        // Studio workspace: full-width toolbar on top (per the mocks — the
        // inspector docks below it), then stage (or grid) + filmstrip with the
        // inspector on the right. The stage only resizes as the single
        // inspector open/close animation (finding U4).
        VStack(spacing: 0) {
            StudioToolbar(viewModel: imageViewerViewModel)

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    if imageViewerViewModel.viewMode == .grid {
                        GridPane(viewModel: imageViewerViewModel)
                    } else {
                        ZStack {
                            EnhancedImageDisplayView(viewModel: imageViewerViewModel)
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active:
                                        stageArrowsVisible = true
                                        scheduleStageArrowsHide()
                                    case .ended:
                                        stageArrowsVisible = false
                                        stageArrowsHideTask?.cancel()
                                    }
                                }
                            StageHoverArrows(
                                viewModel: imageViewerViewModel,
                                isVisible: stageArrowsVisible
                            )
                        }

                        if imageViewerViewModel.viewMode.showsFilmstrip {
                            FilmstripView(viewModel: imageViewerViewModel)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                if imageViewerViewModel.inspectorVisible {
                    InspectorView(viewModel: imageViewerViewModel)
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.3),
                value: imageViewerViewModel.inspectorVisible
            )
        }
    }
    
    @ViewBuilder
    private var folderSelectionInterface: some View {
        FolderSelectionView(onImageSelected: { folderContent, imageFile in
            // Load the folder content with the selected image
            imageViewerViewModel.loadFolderContent(folderContent)
            showImageViewer = true
            
            // Update window state manager with new folder and image
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                Task { @MainActor in
                    appDelegate.windowStateManager.updateFolderState(
                        folderURL: folderContent.folderURL,
                        imageIndex: folderContent.currentIndex
                    )
                }
            }
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var notificationOverlay: some View {
        if !errorHandlingService.notifications.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(errorHandlingService.notifications) { notification in
                    notificationItem(notification)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
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

    private func scheduleStageArrowsHide() {
        stageArrowsHideTask?.cancel()
        stageArrowsHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            stageArrowsVisible = false
        }
    }

    private func setupApplication() {
        restoreApplicationState()
        setupWindowStateManager()
    }
    
    private func restoreApplicationState() {
        let preferencesService = DefaultPreferencesService()
        
        // Restore other preferences
        imageViewerViewModel.showFileName = preferencesService.showFileName
        
        // Initialize AI Insights state based on preferences
        initializeAIInsightsOnLaunch()
    }
    
    /// Initialize AI Insights state on app launch based on preferences and saved state
    private func initializeAIInsightsOnLaunch() {
        // Ensure AI Insights availability is properly set
        imageViewerViewModel.updateAIInsightsAvailability()
        
        // The actual panel visibility will be restored later when window state is applied
        // This ensures proper initialization order
        Logger.info("AI Insights initialization completed on app launch")
    }
    
    private func setupWindowStateManager() {
        // Get the app delegate and set up the window state manager with the view model
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            Task { @MainActor in
                appDelegate.windowStateManager.setImageViewerViewModel(imageViewerViewModel)
            }
        }
    }
    
    private func handleFolderSelection(_ notification: Notification) {
        if let folderContent = notification.object as? FolderContent {
            imageViewerViewModel.loadFolderContent(folderContent)
            showImageViewer = true
            
            // Update window state manager with new folder
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                Task { @MainActor in
                    appDelegate.windowStateManager.updateFolderState(
                        folderURL: folderContent.folderURL,
                        imageIndex: folderContent.currentIndex
                    )
                }
            }
        }
    }
    
    private func handleWindowStateRestoration(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let folderURL = userInfo["folderURL"] as? URL,
              let imageIndex = userInfo["imageIndex"] as? Int else {
            return
        }
        
        // Create a folder selection view model to handle the restoration
        let folderSelectionViewModel = FolderSelectionViewModel()
        
        // Restore the folder at the specific image index
        Task { @MainActor in
            // Set the folder URL and trigger scanning
            folderSelectionViewModel.selectedFolderURL = folderURL
            
            // Wait for scanning to complete and then navigate to the specific image
            // We'll use a simple approach by posting a delayed notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Try to restore the folder content
                if let folderContent = folderSelectionViewModel.selectedFolderContent {
                    // Update the folder content to start at the restored image index
                    let restoredFolderContent = FolderContent(
                        folderURL: folderContent.folderURL,
                        imageFiles: folderContent.imageFiles,
                        currentIndex: min(imageIndex, folderContent.imageFiles.count - 1)
                    )
                    
                    self.imageViewerViewModel.loadFolderContent(restoredFolderContent)
                    self.showImageViewer = true
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let folderSelected = Notification.Name("folderSelected")
}

// MARK: - Stage Hover Arrows

/// Prev/next arrows shown over the stage while the pointer is active (Studio
/// redesign). Purely presentational — hover tracking lives on the stage view
/// so this overlay never intercepts stage gestures. The far-side arrow — the
/// direction you can't navigate — idles at 35 % opacity.
private struct StageHoverArrows: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    let isVisible: Bool

    var body: some View {
        HStack {
            arrow(symbol: "chevron.left", enabled: viewModel.hasPrevious, label: "Previous image") {
                viewModel.previousImage()
            }
            Spacer()
            arrow(symbol: "chevron.right", enabled: viewModel.hasNext, label: "Next image") {
                viewModel.nextImage()
            }
        }
        .padding(.horizontal, 16)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.25), value: isVisible)
        .allowsHitTesting(isVisible)
    }

    private func arrow(symbol: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(.sRGB, red: 20 / 255, green: 20 / 255, blue: 22 / 255, opacity: 0.7))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.35)
        .accessibilityLabel(label)
    }
}



// MARK: - Preview
#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
