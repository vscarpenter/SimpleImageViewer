import SwiftUI

/// Navigation controls and toolbar for the image viewer
struct NavigationControlsView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    let onExit: () -> Void
    
    // MARK: - State Properties
    @State private var isHovered = false
    @State private var showControls = true
    @State private var hideControlsTimer: Timer?
    
    // MARK: - Responsive Layout Properties
    @StateObject private var layoutManager: ToolbarLayoutManager
    @State private var availableWidth: CGFloat = 800
    @State private var isOverflowMenuPresented = false
    
    // Initialize layout manager with view model reference
    init(viewModel: ImageViewerViewModel, onExit: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onExit = onExit
        self._layoutManager = StateObject(wrappedValue: ToolbarLayoutManager(imageViewerViewModel: viewModel))
    }
    
    // MARK: - Animation Properties
    private let controlsAnimationDuration: Double = 0.3
    private let autoHideDelay: Double = 3.0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Consolidated top toolbar
                if showControls || !viewModel.isFullscreen {
                    consolidatedTopToolbar
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: controlsAnimationDuration), value: showControls)
                }
                
                Spacer()
                
                // File name overlay (when enabled and not inline)
                if viewModel.showFileName && showControls && shouldShowFileNameOverlay {
                    fileNameOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: controlsAnimationDuration), value: showControls)
                }
            }
            .onAppear {
                availableWidth = geometry.size.width
                layoutManager.updateLayout(for: availableWidth)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                availableWidth = newWidth
                layoutManager.updateLayout(for: newWidth)
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
        .onChange(of: viewModel.isFullscreen) { _, isFullscreen in
            if isFullscreen {
                startAutoHideTimer()
            } else {
                showControls = true
                stopAutoHideTimer()
            }
        }
        .onChange(of: viewModel.currentIndex) { _, _ in
            if viewModel.isFullscreen {
                showControlsTemporarily()
            }
        }
        .onChange(of: viewModel.isAIInsightsAvailable) { _, _ in
            layoutManager.updateAIInsightsAvailability()
        }
    }
    
    // MARK: - Consolidated Top Toolbar
    private var consolidatedTopToolbar: some View {
        HStack(spacing: 0) {
            // Left Section: Navigation & Context
            responsiveLeftSection
            
            // Section divider (only show in full layout)
            if layoutManager.currentLayout == .full {
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, layoutManager.currentLayout == .full ? 12 : 6)
            }
            
            // Center Section: View Mode Controls (adaptive)
            if shouldShowCenterSection {
                responsiveCenterSection
                
                if layoutManager.currentLayout == .full {
                    Spacer()
                }
            } else {
                Spacer()
            }
            
            // Right Section: Image Actions & Zoom
            responsiveRightSection
            
            // Overflow menu button (when needed)
            if layoutManager.showOverflowButton {
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)
                
                ToolbarOverflowButton(
                    isMenuPresented: $isOverflowMenuPresented,
                    overflowItems: layoutManager.overflowItems,
                    viewModel: viewModel
                )
            }
        }
        .padding(.horizontal, layoutManager.currentLayout == .ultraCompact ? 8 : 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appToolbarBackground.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, layoutManager.currentLayout == .ultraCompact ? 8 : 16)
        .padding(.top, 8)
    }
    
    // MARK: - Responsive Left Section
    private var responsiveLeftSection: some View {
        HStack(spacing: layoutManager.currentLayout == .ultraCompact ? 8 : 12) {
            // Back button (always visible)
            Button(action: onExit) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    if layoutManager.currentLayout != .ultraCompact {
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .foregroundColor(.appText)
            .help("Return to folder selection (Escape or B)")
            .accessibilityLabel("Back to folder selection")
            .accessibilityHint("Returns to the main folder selection screen")
            
            // Favorites removed

            // Image counter (always visible)
            imageCounterView
            
            // Choose folder button (hidden in compact modes)
            if layoutManager.isItemVisible("folder") {
                chooseFolderButton
            }
        }
    }
    
    // MARK: - Legacy Left Section (for compatibility)
    private var leftSection: some View {
        responsiveLeftSection
    }
    
    // MARK: - Responsive Center Section
    private var responsiveCenterSection: some View {
        HStack(spacing: 8) {
            // Image Info toggle button
            if layoutManager.isItemVisible("info") {
                imageInfoToggleButton
            }
            
            // AI Insights toggle button (when available and visible in layout)
            if layoutManager.isItemVisible("aiInsights") {
                aiInsightsToggleButton
            }
            
            // Slideshow toggle button
            if layoutManager.isItemVisible("slideshow") {
                slideshowToggleButton
            }
            
            // Thumbnail strip toggle button
            if layoutManager.isItemVisible("thumbnails") {
                thumbnailStripToggleButton
            }
            
            // Grid view toggle button
            if layoutManager.isItemVisible("grid") {
                gridViewToggleButton
            }
        }
    }
    
    // MARK: - Legacy Center Section (for compatibility)
    private var centerSection: some View {
        responsiveCenterSection
    }
    
    // MARK: - Responsive Right Section
    private var responsiveRightSection: some View {
        HStack(spacing: 8) {
            // Favorites removed
            
            // Share button (hidden in compact modes)
            if layoutManager.isItemVisible("share") {
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)
                
                shareButton
            }
            
            // Delete button (hidden in compact modes)
            if layoutManager.isItemVisible("delete") {
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)
                
                deleteButton
            }
            
            // Zoom controls (always visible, but may be simplified)
            if layoutManager.currentLayout == .ultraCompact {
                compactZoomControls
            } else {
                zoomControlsView
            }
            
            // File name toggle button (hidden in most compact modes)
            if layoutManager.isItemVisible("filename") {
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)
                
                fileNameToggleButton
            }
            
            // Inline file name (when space permits and enabled)
            if shouldShowInlineFileName {
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)
                
                inlineFileNameView
            }
        }
    }
    
    // MARK: - Legacy Right Section (for compatibility)
    private var rightSection: some View {
        responsiveRightSection
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
    
    // MARK: - Delete Button
    private var deleteButton: some View {
        Button(action: {
            moveCurrentImageToTrash()
            showControlsTemporarily()
        }) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(ToolbarButtonStyle())
        .help("Move current image to Trash (Delete)")
        .accessibilityLabel("Delete image")
        .accessibilityHint("Move the current image to Trash")
        .disabled(!viewModel.canDeleteCurrentImage)
    }
    
    // Favorites removed
    
    // MARK: - Image Counter View
    private var imageCounterView: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.stack")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appSecondaryText)
                .accessibilityHidden(true)
            
            Text(viewModel.imageCounterText)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.appText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Image \(viewModel.currentIndex + 1) of \(viewModel.totalImages)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.appSecondaryBackground.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.appBorder.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - Zoom Controls View
    private var zoomControlsView: some View {
        HStack(spacing: 4) {
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
                .foregroundColor(.appText)
                .frame(minWidth: 40)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.appSecondaryBackground.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.appBorder.opacity(0.2), lineWidth: 0.5)
        )
        .help("Current zoom: \(viewModel.zoomPercentageText). Click to cycle through zoom levels.")
        .accessibilityLabel("Zoom level: \(viewModel.zoomPercentageText)")
        .accessibilityHint("Tap to cycle through zoom levels")
    }
    
    // MARK: - File Name Overlay
    private var fileNameOverlay: some View {
        HStack {
            fileNameView
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - File Name View
    private var fileNameView: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appSecondaryText)
                .accessibilityHidden(true)
            
            Text(viewModel.currentFileName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appText)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel("File name: \(viewModel.currentFileName)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.appSecondaryBackground.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.appBorder.opacity(0.2), lineWidth: 0.5)
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
                .foregroundColor(viewModel.showImageInfo ? .systemAccent : .appSecondaryText)
        }
        .buttonStyle(ToolbarButtonStyle())
        .help(viewModel.showImageInfo ? "Hide image info (I)" : "Show image info (I)")
        .accessibilityLabel(viewModel.showImageInfo ? "Hide image info" : "Show image info")
        .accessibilityHint("Toggle image metadata display")
    }
    
    // MARK: - AI Insights Toggle Button
    private var aiInsightsToggleButton: some View {
        Button(action: {
            viewModel.toggleAIInsights()
            showControlsTemporarily()
        }) {
            Image(systemName: viewModel.showAIInsights ? "brain.head.profile.fill" : "brain.head.profile")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.showAIInsights ? .systemAccent : .appSecondaryText)
        }
        .buttonStyle(ToolbarButtonStyle())
        .help(viewModel.showAIInsights ? "Hide AI Insights" : "Show AI Insights")
        .accessibilityLabel(viewModel.showAIInsights ? "Hide AI Insights" : "Show AI Insights")
        .accessibilityHint("Toggle AI-powered image analysis panel")
    }
    
    // MARK: - Slideshow Toggle Button
    private var slideshowToggleButton: some View {
        Button(action: {
            viewModel.toggleSlideshow()
            showControlsTemporarily()
        }) {
            Image(systemName: viewModel.isSlideshow ? "pause.circle.fill" : "play.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.isSlideshow ? .systemAccent : .appSecondaryText)
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
                .foregroundColor(viewModel.viewMode == .thumbnailStrip ? .systemAccent : .appSecondaryText)
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
                .foregroundColor(viewModel.viewMode == .grid ? .systemAccent : .appSecondaryText)
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
                .foregroundColor(viewModel.showFileName ? .systemAccent : .appSecondaryText)
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
        }
        .buttonStyle(ToolbarButtonStyle())
        .help("Choose different folder (Escape or B)")
        .accessibilityLabel("Choose folder")
        .accessibilityHint("Return to folder selection to choose a different folder")
    }
    
    // MARK: - Responsive Layout Helpers
    
    private var shouldShowCenterSection: Bool {
        return layoutManager.currentLayout == .full || 
               layoutManager.visibleItems["center"]?.isEmpty == false
    }
    
    private var shouldShowFileNameOverlay: Bool {
        return !shouldShowInlineFileName && layoutManager.currentLayout != .ultraCompact
    }
    
    private var shouldShowInlineFileName: Bool {
        return viewModel.showFileName && 
               layoutManager.currentLayout == .full &&
               availableWidth > 900 // Extra space needed for inline display
    }
    
    // MARK: - Compact Zoom Controls
    private var compactZoomControls: some View {
        HStack(spacing: 2) {
            // Zoom out button
            Button(action: {
                viewModel.zoomOut()
                showControlsTemporarily()
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(CompactToolbarButtonStyle())
            .help("Zoom out")
            .accessibilityLabel("Zoom out")
            
            // Zoom level indicator (simplified)
            Button(action: {
                viewModel.zoomToFit()
                showControlsTemporarily()
            }) {
                Text(viewModel.zoomPercentageText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.appText)
                    .frame(minWidth: 30)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.appSecondaryBackground.opacity(0.9))
            )
            .help("Reset zoom")
            
            // Zoom in button
            Button(action: {
                viewModel.zoomIn()
                showControlsTemporarily()
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(CompactToolbarButtonStyle())
            .help("Zoom in")
            .accessibilityLabel("Zoom in")
        }
    }
    
    // MARK: - Inline File Name View
    private var inlineFileNameView: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.appSecondaryText)
                .accessibilityHidden(true)
            
            Text(viewModel.currentFileName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 150) // Limit width to prevent toolbar overflow
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.appSecondaryBackground.opacity(0.6))
        )
        .help("File: \(viewModel.currentFileName)")
        .accessibilityLabel("File name: \(viewModel.currentFileName)")
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
            Task {
                await MainActor.run {
                    if self.viewModel.isFullscreen && !self.isHovered {
                        withAnimation(.easeInOut(duration: self.controlsAnimationDuration)) {
                            self.showControls = false
                        }
                    }
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
    
    private func moveCurrentImageToTrash() {
        Task { @MainActor in
            await viewModel.moveCurrentImageToTrash()
        }
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
        }(), onExit: {
            // Preview exit action
            // Exit pressed
        })
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
        }(), onExit: {
            // Preview exit action
            // Exit pressed
        })
    }
    .frame(width: 800, height: 600)
}

