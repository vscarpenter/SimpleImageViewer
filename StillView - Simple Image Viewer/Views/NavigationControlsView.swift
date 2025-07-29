import SwiftUI

/// Navigation controls and toolbar for the image viewer
struct NavigationControlsView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    let onExit: () -> Void
    
    // MARK: - State Properties
    @State private var isHovered = false
    @State private var showControls = true
    @State private var hideControlsTimer: Timer?
    
    // MARK: - Animation Properties
    private let controlsAnimationDuration: Double = 0.3
    private let autoHideDelay: Double = 3.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            if showControls || !viewModel.isFullscreen {
                topToolbar
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: controlsAnimationDuration), value: showControls)
            }
            
            Spacer()
            
            // Bottom status bar
            if showControls || !viewModel.isFullscreen {
                bottomStatusBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: controlsAnimationDuration), value: showControls)
            }
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                showControlsTemporarily()
            }
        }
        .onTapGesture {
            if viewModel.isFullscreen {
                toggleControlsVisibility()
            }
        }
        .onChange(of: viewModel.isFullscreen) { isFullscreen in
            if isFullscreen {
                startAutoHideTimer()
            } else {
                showControls = true
                stopAutoHideTimer()
            }
        }
        .onChange(of: viewModel.currentIndex) { _ in
            if viewModel.isFullscreen {
                showControlsTemporarily()
            }
        }
    }
    
    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: onExit) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundColor(.primary)
            .help("Return to folder selection (Escape or B)")
            .accessibilityLabel("Back to folder selection")
            .accessibilityHint("Returns to the main folder selection screen")
            
            // Image counter
            imageCounterView
            
            Spacer()
            
            // Share button
            shareButton
            
            // Zoom controls
            zoomControlsView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Share Button
    private var shareButton: some View {
        Button(action: {
            shareCurrentImage()
            showControlsTemporarily()
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(ToolbarButtonStyle())
        .help("Share current image")
        .accessibilityLabel("Share image")
        .accessibilityHint("Share the current image using system sharing options")
        .disabled(!viewModel.canShareCurrentImage)
    }
    
    // MARK: - Image Counter View
    private var imageCounterView: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.stack")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(viewModel.imageCounterText)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .accessibilityLabel("Image \(viewModel.currentIndex + 1) of \(viewModel.totalImages)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
    
    // MARK: - Zoom Controls View
    private var zoomControlsView: some View {
        HStack(spacing: 12) {
            // Zoom out button
            Button(action: {
                viewModel.zoomOut()
                showControlsTemporarily()
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(ToolbarButtonStyle())
            .help("Zoom out")
            .accessibilityLabel("Zoom out")
            .accessibilityHint("Decrease zoom level")
            
            // Zoom level indicator
            zoomLevelIndicator
            
            // Zoom in button
            Button(action: {
                viewModel.zoomIn()
                showControlsTemporarily()
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(ToolbarButtonStyle())
            .help("Zoom in")
            .accessibilityLabel("Zoom in")
            .accessibilityHint("Increase zoom level")
            
            Divider()
                .frame(height: 16)
            
            // Fit to window button
            Button(action: {
                viewModel.zoomToFit()
                showControlsTemporarily()
            }) {
                Image(systemName: "rectangle.and.arrow.up.right.and.arrow.down.left")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(ToolbarButtonStyle())
            .help("Fit to window")
            .accessibilityLabel("Fit to window")
            .accessibilityHint("Zoom to fit image in window")
            
            // Actual size button
            Button(action: {
                viewModel.zoomToActualSize()
                showControlsTemporarily()
            }) {
                Image(systemName: "1.square")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(ToolbarButtonStyle())
            .help("Actual size (100%)")
            .accessibilityLabel("Actual size")
            .accessibilityHint("Zoom to 100% actual size")
        }
    }
    
    // MARK: - Zoom Level Indicator
    private var zoomLevelIndicator: some View {
        Button(action: {
            // Cycle through common zoom levels when clicked
            let commonZoomLevels: [Double] = [-1.0, 0.5, 1.0, 1.5, 2.0] // -1.0 is fit-to-window
            let currentZoom = viewModel.zoomLevel
            
            if let currentIndex = commonZoomLevels.firstIndex(of: currentZoom) {
                let nextIndex = (currentIndex + 1) % commonZoomLevels.count
                viewModel.setZoom(commonZoomLevels[nextIndex])
            } else {
                viewModel.zoomToFit()
            }
            showControlsTemporarily()
        }) {
            Text(viewModel.zoomPercentageText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(minWidth: 40)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
        )
        .help("Current zoom: \(viewModel.zoomPercentageText). Click to cycle through zoom levels.")
        .accessibilityLabel("Zoom level: \(viewModel.zoomPercentageText)")
        .accessibilityHint("Tap to cycle through zoom levels")
    }
    
    // MARK: - Bottom Status Bar
    private var bottomStatusBar: some View {
        HStack(spacing: 16) {
            // File name display (if enabled)
            if viewModel.showFileName {
                fileNameView
            }
            
            Spacer()
            
            // Image Info toggle button
            imageInfoToggleButton
            
            // Slideshow toggle button
            slideshowToggleButton
            
            // Thumbnail strip toggle button
            thumbnailStripToggleButton
            
            // Grid view toggle button
            gridViewToggleButton
            
            // File name toggle button
            fileNameToggleButton
            
            Divider()
                .frame(height: 16)
            
            // Choose folder button
            chooseFolderButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - File Name View
    private var fileNameView: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(viewModel.currentFileName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel("File name: \(viewModel.currentFileName)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
    
    // MARK: - Image Info Toggle Button
    private var imageInfoToggleButton: some View {
        Button(action: {
            viewModel.toggleImageInfo()
            showControlsTemporarily()
        }) {
            Image(systemName: viewModel.showImageInfo ? "info.circle.fill" : "info.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.showImageInfo ? .accentColor : .secondary)
        }
        .buttonStyle(ToolbarButtonStyle())
        .help(viewModel.showImageInfo ? "Hide image info (I)" : "Show image info (I)")
        .accessibilityLabel(viewModel.showImageInfo ? "Hide image info" : "Show image info")
        .accessibilityHint("Toggle image metadata display")
    }
    
    // MARK: - Slideshow Toggle Button
    private var slideshowToggleButton: some View {
        Button(action: {
            viewModel.toggleSlideshow()
            showControlsTemporarily()
        }) {
            Image(systemName: viewModel.isSlideshow ? "pause.circle.fill" : "play.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.isSlideshow ? .accentColor : .secondary)
        }
        .buttonStyle(ToolbarButtonStyle())
        .help(viewModel.isSlideshow ? "Stop slideshow (S)" : "Start slideshow (S)")
        .accessibilityLabel(viewModel.isSlideshow ? "Stop slideshow" : "Start slideshow")
        .accessibilityHint("Toggle slideshow mode")
        .disabled(viewModel.totalImages < 2)
    }
    
    // MARK: - Thumbnail Strip Toggle Button
    private var thumbnailStripToggleButton: some View {
        Button(action: {
            viewModel.toggleThumbnailStrip()
            showControlsTemporarily()
        }) {
            Image(systemName: viewModel.viewMode == .thumbnailStrip ? "rectangle.grid.1x2.fill" : "rectangle.grid.1x2")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.viewMode == .thumbnailStrip ? .accentColor : .secondary)
        }
        .buttonStyle(ToolbarButtonStyle())
        .help(viewModel.viewMode == .thumbnailStrip ? "Hide thumbnail strip (T)" : "Show thumbnail strip (T)")
        .accessibilityLabel(viewModel.viewMode == .thumbnailStrip ? "Hide thumbnail strip" : "Show thumbnail strip")
        .accessibilityHint("Toggle thumbnail strip for quick image navigation")
        .disabled(viewModel.totalImages < 2)
    }
    
    // MARK: - Grid View Toggle Button
    private var gridViewToggleButton: some View {
        Button(action: {
            viewModel.toggleGridView()
            showControlsTemporarily()
        }) {
            Image(systemName: viewModel.viewMode == .grid ? "square.grid.3x3.fill" : "square.grid.3x3")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.viewMode == .grid ? .accentColor : .secondary)
        }
        .buttonStyle(ToolbarButtonStyle())
        .help(viewModel.viewMode == .grid ? "Exit grid view (G)" : "Show grid view (G)")
        .accessibilityLabel(viewModel.viewMode == .grid ? "Exit grid view" : "Show grid view")
        .accessibilityHint("Toggle grid view for browsing all images")
        .disabled(viewModel.totalImages < 2)
    }
    
    // MARK: - File Name Toggle Button
    private var fileNameToggleButton: some View {
        Button(action: {
            viewModel.toggleFileNameDisplay()
            showControlsTemporarily()
        }) {
            Image(systemName: viewModel.showFileName ? "eye.fill" : "eye.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.showFileName ? .accentColor : .secondary)
        }
        .buttonStyle(ToolbarButtonStyle())
        .help(viewModel.showFileName ? "Hide file name" : "Show file name")
        .accessibilityLabel(viewModel.showFileName ? "Hide file name" : "Show file name")
        .accessibilityHint("Toggle file name display")
    }
    
    // MARK: - Choose Folder Button
    private var chooseFolderButton: some View {
        Button(action: {
            onExit()
            showControlsTemporarily()
        }) {
            Image(systemName: "folder")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .buttonStyle(ToolbarButtonStyle())
        .help("Choose different folder (Escape or B)")
        .accessibilityLabel("Choose folder")
        .accessibilityHint("Return to folder selection to choose a different folder")
    }
    
    // MARK: - Helper Methods
    private func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: controlsAnimationDuration)) {
            showControls.toggle()
        }
        
        if showControls {
            startAutoHideTimer()
        }
    }
    
    private func showControlsTemporarily() {
        withAnimation(.easeInOut(duration: controlsAnimationDuration)) {
            showControls = true
        }
        
        if viewModel.isFullscreen {
            startAutoHideTimer()
        }
    }
    
    private func startAutoHideTimer() {
        stopAutoHideTimer()
        
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { _ in
            if viewModel.isFullscreen && !isHovered {
                withAnimation(.easeInOut(duration: controlsAnimationDuration)) {
                    showControls = false
                }
            }
        }
    }
    
    private func stopAutoHideTimer() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = nil
    }
    
    private func shareCurrentImage() {
        // Find the share button view to use as the source for the share sheet
        if let window = NSApplication.shared.mainWindow,
           let contentView = window.contentView {
            viewModel.shareCurrentImage(from: contentView)
        } else {
            viewModel.shareCurrentImage()
        }
    }
}

// MARK: - Toolbar Button Style
private struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .accentColor : .primary)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        configuration.isPressed 
                        ? Color(NSColor.controlAccentColor).opacity(0.2)
                        : Color(NSColor.controlBackgroundColor).opacity(0.8)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        NavigationControlsView(viewModel: {
            let vm = ImageViewerViewModel()
            // Mock some data for preview
            return vm
        }()) {
            // Preview exit action
            print("Exit pressed")
        }
    }
    .frame(width: 800, height: 600)
}

#Preview("Fullscreen Mode") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        NavigationControlsView(viewModel: {
            let vm = ImageViewerViewModel()
            vm.isFullscreen = true
            return vm
        }()) {
            // Preview exit action
            print("Exit pressed")
        }
    }
    .frame(width: 800, height: 600)
}