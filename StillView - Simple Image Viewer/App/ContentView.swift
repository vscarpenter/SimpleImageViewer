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
        ZStack {
            ImageDisplayView(viewModel: imageViewerViewModel)
                .frame(width: geometry.size.width, height: geometry.size.height)
            
            NavigationControlsView(viewModel: imageViewerViewModel) {
                showImageViewer = false
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            
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
    
    private func setupApplication() {
        restoreApplicationState()
        setupWindowStateManager()
    }
    
    private func restoreApplicationState() {
        let preferencesService = DefaultPreferencesService()
        
        // Restore other preferences
        imageViewerViewModel.showFileName = preferencesService.showFileName
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

// MARK: - Preview
#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}