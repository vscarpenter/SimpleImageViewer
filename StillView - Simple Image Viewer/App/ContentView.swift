// swiftlint:disable file_length
import SwiftUI

struct ContentView: View {
    // MARK: - State Properties
    @StateObject private var imageViewerViewModel = ImageViewerViewModel()
    @StateObject private var errorHandlingService = ErrorHandlingService.shared
    @State private var showImageViewer = false
    // Favorites removed
    @State private var showAIConsentDialog = false
    
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
            .overlay {
                aiConsentOverlay
            }
            .onAppear {
                setupApplication()
                evaluateAIConsent()
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
                } else {
                    folderSelectionInterface
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    @ViewBuilder
    private func imageViewerInterface(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Main image viewer area
            ZStack {
                // Calculate available width for image viewer
                let availableWidth = imageViewerViewModel.isAIInsightsAvailable && imageViewerViewModel.showAIInsights
                    ? geometry.size.width - 360 // 320 panel width + 40 padding
                    : geometry.size.width
                
                // Use enhanced image display view when available
                if #available(macOS 15.0, *) {
                    EnhancedImageDisplayView(viewModel: imageViewerViewModel)
                        .frame(width: availableWidth, height: geometry.size.height)
                } else {
                    ImageDisplayView(viewModel: imageViewerViewModel)
                        .frame(width: availableWidth, height: geometry.size.height)
                }
                
                NavigationControlsView(viewModel: imageViewerViewModel, onExit: {
                    showImageViewer = false
                })
                .frame(width: availableWidth, height: geometry.size.height)
                
                // Thumbnail Strip (when in thumbnail strip mode)
                if imageViewerViewModel.viewMode == .thumbnailStrip {
                    VStack {
                        Spacer()
                        ThumbnailStripView(viewModel: imageViewerViewModel)
                    }
                    .allowsHitTesting(true)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: imageViewerViewModel.viewMode)
                }
                
                // Grid Overlay (when in grid mode)
                if imageViewerViewModel.viewMode == .grid {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .overlay(
                            ThumbnailGridView(viewModel: imageViewerViewModel)
                        )
                        .allowsHitTesting(true)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: imageViewerViewModel.viewMode)
                }
                
                // Image Info Overlay
                if imageViewerViewModel.showImageInfo,
                   let currentImageFile = imageViewerViewModel.currentImageFile {
                    VStack {
                        HStack {
                            ImageInfoOverlayView(
                                imageFile: currentImageFile,
                                currentImage: imageViewerViewModel.currentImage
                            )
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.leading, 20)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: imageViewerViewModel.showImageInfo)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), 
                      value: imageViewerViewModel.showAIInsights)
            
            // AI Insights Panel (when available and toggled on)
            if imageViewerViewModel.isAIInsightsAvailable,
               imageViewerViewModel.showAIInsights {
                aiInsightsPanel(geometry: geometry)
            }
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

    @ViewBuilder
    private var aiConsentOverlay: some View {
        if showAIConsentDialog {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                AIConsentDialog(
                    onAllow: {
                        AIConsentManager.shared.recordConsent(allowAnalysis: true)
                        showAIConsentDialog = false
                        imageViewerViewModel.retryAIAnalysis()
                    },
                    onDecline: {
                        AIConsentManager.shared.recordConsent(allowAnalysis: false)
                        showAIConsentDialog = false
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private func aiInsightsPanel(geometry: GeometryProxy) -> some View {
        // AI Insights inspector panel
        AIInsightsInspectorView(viewModel: imageViewerViewModel)
            .frame(width: 320, height: geometry.size.height - 40)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 12, x: -2, y: 0)
            .padding(.top, 20)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
            .allowsHitTesting(true)
            .accessibilityLabel("AI Insights Inspector")
            .accessibilityHint("Inspector panel showing AI-powered analysis of the current image")
    }
    
    // MARK: - Private Methods
    
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
    
    private func evaluateAIConsent() {
        guard AIConsentManager.shared.shouldShowConsent() else { return }
        showAIConsentDialog = true
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


// MARK: - Thumbnail Views

/// Horizontal thumbnail strip for quick image navigation
struct ThumbnailStripView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    
    // MARK: - Properties
    private let thumbnailSize: CGSize = CGSize(width: 80, height: 60)
    private let stripHeight: CGFloat = 100
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(viewModel.allImageFiles.enumerated()), id: \.element.id) { index, imageFile in
                        ThumbnailItemView(
                            imageFile: imageFile,
                            index: index,
                            isSelected: index == viewModel.currentIndex,
                            size: thumbnailSize,
                            onTap: {
                                viewModel.jumpToImage(at: index)
                            },
                            viewModel: viewModel
                        )
                        .id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(height: stripHeight)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .onChange(of: viewModel.currentIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(viewModel.currentIndex, anchor: .center)
            }
        }
    }
}

/// Individual thumbnail item in the strip
struct ThumbnailItemView: View {
    let imageFile: ImageFile
    let index: Int
    let isSelected: Bool
    let size: CGSize
    let onTap: () -> Void
    let viewModel: ImageViewerViewModel
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color.white)
                    .shadow(
                        color: isSelected ? .accentColor.opacity(0.4) : .black.opacity(0.1),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: 1
                    )
                
                // Content
                Group {
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        // Fallback icon
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: size.width - 8, height: size.height - 8)
                
                // Selection indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 3)
                }
                
                // Favorites removed
                
                // Image index overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                            )
                            .padding(.trailing, 4)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: size.width, height: size.height)
        .help("Image \(index + 1): \(imageFile.displayName)")
        .accessibilityLabel("Thumbnail \(index + 1), \(imageFile.displayName)")
        .accessibilityHint("Tap to view this image, right-click for options")
        .thumbnailContextMenu(for: imageFile, at: index, viewModel: viewModel)
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: imageFile.url) { _ in
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        isLoading = true
        
        // Simple thumbnail generation using NSImage
        DispatchQueue.global(qos: .userInitiated).async {
            let thumbnailImage = generateSimpleThumbnail(from: imageFile.url, size: size)
            
            DispatchQueue.main.async {
                thumbnail = thumbnailImage
                isLoading = false
            }
        }
    }
    
    private func generateSimpleThumbnail(from url: URL, size: CGSize) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let targetSize = size
        let imageSize = image.size
        
        // Calculate aspect ratio
        let aspectRatio = imageSize.width / imageSize.height
        let targetAspectRatio = targetSize.width / targetSize.height
        
        var scaledSize: NSSize
        if aspectRatio > targetAspectRatio {
            scaledSize = NSSize(width: targetSize.width, height: targetSize.width / aspectRatio)
        } else {
            scaledSize = NSSize(width: targetSize.height * aspectRatio, height: targetSize.height)
        }
        
        let thumbnail = NSImage(size: scaledSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: scaledSize))
        thumbnail.unlockFocus()
        
        return thumbnail
    }
}

/// Full-screen grid view for browsing all images
struct ThumbnailGridView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    
    // MARK: - Properties
    private let gridThumbnailSize: CGSize = CGSize(width: 200, height: 150)
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Adaptive grid columns
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 250), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar for macOS
            HStack {
                Button("Close") {
                    viewModel.setViewMode(.normal)
                }
                .keyboardShortcut(.escape, modifiers: [])
                .padding(.leading)
                
                Spacer()
                
                Text("Grid View (\(viewModel.totalImages) images)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.currentIndex + 1) of \(viewModel.totalImages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing)
            }
            .padding(.vertical, 8)
            .background(.regularMaterial)
            
            // Grid content
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(viewModel.allImageFiles.enumerated()), id: \.element.id) { index, imageFile in
                                GridThumbnailItemView(
                                    imageFile: imageFile,
                                    index: index,
                                    isSelected: index == viewModel.currentIndex,
                                    size: gridThumbnailSize,
                                    onTap: {
                                        viewModel.jumpToImage(at: index)
                                    },
                                    viewModel: viewModel
                                )
                                .id(index)
                            }
                        }
                        .padding(20)
                    }
                    .background(
                        Color(colorScheme == .dark ? NSColor.windowBackgroundColor : NSColor.controlBackgroundColor)
                            .opacity(0.95)
                    )
                    .onChange(of: viewModel.currentIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(viewModel.currentIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.setViewMode(.normal)
                }
        )
    }
}

/// Individual thumbnail item in the grid
struct GridThumbnailItemView: View {
    let imageFile: ImageFile
    let index: Int
    let isSelected: Bool
    let size: CGSize
    let onTap: () -> Void
    let viewModel: ImageViewerViewModel
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    @State private var isHovered = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Services
    
    /// Favorites service for checking favorite status (will be injected when available)
    // @StateObject private var favoritesService = DefaultFavoritesService(
    //     preferencesService: DefaultPreferencesService()
    // )
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail container
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color.white)
                        .shadow(
                            color: isSelected ? .accentColor.opacity(0.4) : .black.opacity(0.1),
                            radius: isSelected ? 6 : 3,
                            x: 0,
                            y: 2
                        )
                    
                    // Thumbnail content
                    Group {
                        if let thumbnail = thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else if isLoading {
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Fallback
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("Failed to load")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(width: size.width - 16, height: size.height - 16)
                    
                    // Selection indicator
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor, lineWidth: 4)
                    }
                    
                    // Hover overlay
                    if isHovered && !isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.1))
                    }
                    
                    // Favorites removed
                    
                    // Index badge
                    VStack {
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.accentColor : Color.black.opacity(0.7))
                                )
                                .padding(.top, 8)
                                .padding(.leading, 8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .frame(width: size.width, height: size.height)
                
                // File info
                VStack(alignment: .leading, spacing: 2) {
                    Text(imageFile.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(imageFile.formattedSize)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(imageFile.formatDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: size.width, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .help("Image \(index + 1): \(imageFile.displayName)")
        .accessibilityLabel("Grid thumbnail \(index + 1), \(imageFile.displayName)")
        .accessibilityHint("Double-tap to view this image, right-click for options")
        .thumbnailContextMenu(for: imageFile, at: index, viewModel: viewModel)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: imageFile.url) { _ in
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        isLoading = true
        
        // Simple thumbnail generation using NSImage
        DispatchQueue.global(qos: .userInitiated).async {
            let thumbnailImage = generateSimpleThumbnail(from: imageFile.url, size: size)
            
            DispatchQueue.main.async {
                thumbnail = thumbnailImage
                isLoading = false
            }
        }
    }
    
    private func generateSimpleThumbnail(from url: URL, size: CGSize) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let targetSize = size
        let imageSize = image.size
        
        // Calculate aspect ratio
        let aspectRatio = imageSize.width / imageSize.height
        let targetAspectRatio = targetSize.width / targetSize.height
        
        var scaledSize: NSSize
        if aspectRatio > targetAspectRatio {
            scaledSize = NSSize(width: targetSize.width, height: targetSize.width / aspectRatio)
        } else {
            scaledSize = NSSize(width: targetSize.height * aspectRatio, height: targetSize.height)
        }
        
        let thumbnail = NSImage(size: scaledSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: scaledSize))
        thumbnail.unlockFocus()
        
        return thumbnail
    }
}

// MARK: - AI Consent Dialog
/// Simple, clear consent dialog for AI features - follows CLAUDE.md simplicity guidelines
private struct AIConsentDialog: View {
    @State private var showingDetails = false
    let onAllow: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon and title
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("AI-Powered Image Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            // Clear, simple explanation
            VStack(alignment: .leading, spacing: 12) {
                Text("StillView can analyze your images to provide:")
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "person.2", text: "Detect people and faces")
                    FeatureRow(icon: "pawprint", text: "Identify animals and objects")
                    FeatureRow(icon: "textformat", text: "Extract readable text")
                    FeatureRow(icon: "paintpalette", text: "Analyze colors and quality")
                }
            }
            .padding(.horizontal, 8)

            // Privacy assurance
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("All analysis happens locally on your device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.green)
                    Text("No data sent to external servers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)

            // Action buttons
            HStack(spacing: 16) {
                Button("Not Now") {
                    onDecline()
                }
                .buttonStyle(.bordered)

                Button("Enable AI Features") {
                    onAllow()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }

            // Details toggle
            Button(showingDetails ? "Hide Details" : "Learn More") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingDetails.toggle()
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if showingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Technical Details:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("• Uses Apple's Vision framework for on-device analysis")
                    Text("• Processes images locally using Core ML models")
                    Text("• You can change this setting anytime in Preferences")
                    Text("• Disabling won't affect other app features")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(32)
        .frame(maxWidth: 500)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

/// Simple feature row component
private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
