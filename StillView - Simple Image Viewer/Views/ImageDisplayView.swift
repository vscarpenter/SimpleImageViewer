import SwiftUI
import AppKit

/// Mini-map navigator for zoomed images
struct MiniMapNavigatorView: View {
    // MARK: - Properties
    
    /// Current zoom level
    let zoomLevel: Double
    
    /// Whether the zoom is currently fit-to-window
    let isFitToWindow: Bool
    
    /// Size of the full image
    let imageSize: CGSize
    
    /// Size of the viewport/container
    let viewportSize: CGSize
    
    /// Current pan offset
    let panOffset: CGSize
    
    /// Callback when user taps on mini-map to navigate
    let onNavigate: (CGPoint) -> Void
    
    // MARK: - Constants
    private let miniMapSize: CGFloat = 120
    private let viewportIndicatorColor = Color.white.opacity(0.8)
    private let miniMapBackgroundColor = Color.black.opacity(0.6)
    
    // MARK: - Computed Properties
    
    /// Whether to show the mini-map (only when zoomed beyond fit-to-window)
    private var shouldShowMiniMap: Bool {
        return !isFitToWindow && zoomLevel > 1.0
    }
    
    /// Scale factor for the mini-map
    private var miniMapScale: CGFloat {
        let imageAspectRatio = imageSize.width / imageSize.height
        let miniMapAspectRatio: CGFloat = 1.0 // Square mini-map
        
        if imageAspectRatio > miniMapAspectRatio {
            // Image is wider - scale based on width
            return miniMapSize / imageSize.width
        } else {
            // Image is taller - scale based on height
            return miniMapSize / imageSize.height
        }
    }
    
    /// Size of the mini-map image representation
    private var miniMapImageSize: CGSize {
        return CGSize(
            width: imageSize.width * miniMapScale,
            height: imageSize.height * miniMapScale
        )
    }
    
    /// Size and position of the viewport indicator
    private var viewportIndicator: CGRect {
        let viewportWidth = viewportSize.width / zoomLevel
        let viewportHeight = viewportSize.height / zoomLevel
        
        // Scale viewport to mini-map coordinates
        let scaledViewportWidth = viewportWidth * miniMapScale
        let scaledViewportHeight = viewportHeight * miniMapScale
        
        // Calculate position based on pan offset
        let normalizedPanX = panOffset.width / (imageSize.width * zoomLevel - viewportSize.width)
        let normalizedPanY = panOffset.height / (imageSize.height * zoomLevel - viewportSize.height)
        
        let indicatorX = (miniMapImageSize.width - scaledViewportWidth) * (-normalizedPanX * 0.5 + 0.5)
        let indicatorY = (miniMapImageSize.height - scaledViewportHeight) * (-normalizedPanY * 0.5 + 0.5)
        
        return CGRect(
            x: indicatorX,
            y: indicatorY,
            width: scaledViewportWidth,
            height: scaledViewportHeight
        )
    }
    
    var body: some View {
        if shouldShowMiniMap {
            VStack {
                HStack {
                    Spacer()
                    miniMapContent
                        .padding(8)
                }
                Spacer()
            }
            .transition(.opacity.combined(with: .scale))
        }
    }
    
    private var miniMapContent: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(miniMapBackgroundColor)
                .frame(width: miniMapSize, height: miniMapSize)
            
            // Image representation (simplified as a rectangle)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.4))
                .frame(width: miniMapImageSize.width, height: miniMapImageSize.height)
            
            // Viewport indicator
            RoundedRectangle(cornerRadius: 2)
                .stroke(viewportIndicatorColor, lineWidth: 2)
                .frame(width: viewportIndicator.width, height: viewportIndicator.height)
                .position(
                    x: miniMapSize/2 + viewportIndicator.midX - miniMapImageSize.width/2,
                    y: miniMapSize/2 + viewportIndicator.midY - miniMapImageSize.height/2
                )
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .onTapGesture { location in
            handleMiniMapTap(at: location)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mini-map navigator")
        .accessibilityHint("Tap to navigate to different areas of the zoomed image")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Private Methods
    
    /// Handle tap on mini-map to navigate
    private func handleMiniMapTap(at location: CGPoint) {
        // Convert tap location to normalized coordinates (0-1)
        let normalizedX = (location.x - (miniMapSize - miniMapImageSize.width) / 2) / miniMapImageSize.width
        let normalizedY = (location.y - (miniMapSize - miniMapImageSize.height) / 2) / miniMapImageSize.height
        
        // Clamp to valid range
        let clampedX = max(0, min(1, normalizedX))
        let clampedY = max(0, min(1, normalizedY))
        
        // Convert to image coordinates
        let targetPoint = CGPoint(
            x: clampedX * imageSize.width,
            y: clampedY * imageSize.height
        )
        
        onNavigate(targetPoint)
    }
}

/// View that displays the current zoom level with visual feedback
struct ZoomIndicatorView: View {
    // MARK: - Properties
    
    /// Current zoom level (1.0 = 100%, -1.0 = fit to window)
    let zoomLevel: Double
    
    /// Whether the zoom is currently fit-to-window
    let isFitToWindow: Bool
    
    /// Size of the image being displayed
    let imageSize: CGSize
    
    /// Size of the viewport/container
    let viewportSize: CGSize
    
    // MARK: - Animation State
    @State private var animationProgress: Double = 0.0
    @State private var isVisible: Bool = false
    
    // MARK: - Constants
    private let indicatorSize: CGFloat = 80
    private let ringWidth: CGFloat = 4
    private let autoHideDelay: Double = 2.0
    
    // MARK: - Computed Properties
    
    /// Normalized zoom level for the progress ring (0.0 to 1.0)
    private var normalizedZoomLevel: Double {
        if isFitToWindow {
            return 0.0 // Special case for fit-to-window
        }
        
        // Map zoom levels from 0.1 to 5.0 to 0.0 to 1.0
        let minZoom = 0.1
        let maxZoom = 5.0
        let clampedZoom = max(minZoom, min(maxZoom, zoomLevel))
        return (clampedZoom - minZoom) / (maxZoom - minZoom)
    }
    
    /// Formatted zoom percentage text
    private var zoomText: String {
        if isFitToWindow {
            return "Fit"
        } else {
            return "\(Int(zoomLevel * 100))%"
        }
    }
    
    /// Color for the zoom indicator based on zoom level
    private var indicatorColor: Color {
        if isFitToWindow {
            return .appAccent
        } else if zoomLevel < 1.0 {
            return .appWarning // Orange for zoomed out
        } else if zoomLevel > 2.0 {
            return .red // Red for high zoom levels
        } else {
            return .appAccent // Blue for normal zoom levels
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.appSecondaryText.opacity(0.3), lineWidth: ringWidth)
                .frame(width: indicatorSize, height: indicatorSize)
            
            // Progress ring
            Circle()
                .trim(from: 0.0, to: animationProgress)
                .stroke(
                    indicatorColor,
                    style: StrokeStyle(
                        lineWidth: ringWidth,
                        lineCap: .round
                    )
                )
                .frame(width: indicatorSize, height: indicatorSize)
                .rotationEffect(.degrees(-90)) // Start from top
            
            // Center content
            VStack(spacing: 4) {
                // Zoom icon
                Image(systemName: isFitToWindow ? "viewfinder" : "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(indicatorColor)
                
                // Zoom percentage
                Text(zoomText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.appText)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Zoom indicator")
        .accessibilityValue("Current zoom level: \(zoomText)")
        .onChange(of: zoomLevel) { _ in
            updateIndicator()
        }
        .onChange(of: isFitToWindow) { _ in
            updateIndicator()
        }
        .onAppear {
            updateIndicator()
        }
    }
    
    // MARK: - Private Methods
    
    /// Update the indicator with animation
    private func updateIndicator() {
        // Show the indicator
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isVisible = true
        }
        
        // Animate the progress ring
        withAnimation(.easeInOut(duration: 0.4)) {
            animationProgress = normalizedZoomLevel
        }
        
        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
        }
    }
}

/// Custom NSView wrapper to handle scroll wheel events
struct ScrollWheelView: NSViewRepresentable {
    let onScrollWheel: (CGPoint, CGFloat) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelNSView()
        view.onScrollWheel = onScrollWheel
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let scrollView = nsView as? ScrollWheelNSView {
            scrollView.onScrollWheel = onScrollWheel
        }
    }
}

class ScrollWheelNSView: NSView {
    var onScrollWheel: ((CGPoint, CGFloat) -> Void)?
    
    override func scrollWheel(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let deltaY = event.scrollingDeltaY
        
        // Only handle zoom if the scroll is significant enough
        if abs(deltaY) > 1.0 {
            onScrollWheel?(location, deltaY)
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

/// Main view for displaying images with zoom and pan support
struct ImageDisplayView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    
    // MARK: - State Properties
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var magnification: CGFloat = 1.0
    @State private var lastMagnification: CGFloat = 1.0
    @State private var imageSize: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var showZoomIndicator: Bool = false
    @State private var zoomTargetLocation: CGPoint = .zero
    @State private var showZoomTarget: Bool = false
    
    // MARK: - Animation Properties
    private let transitionDuration: Double = 0.08 // Under 100ms as required
    private let loadingAnimationDuration: Double = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with context menu for empty areas
                Color.black
                    .ignoresSafeArea()
                    .emptyAreaContextMenu(viewModel: viewModel)
                
                // Main content
                if viewModel.isLoading {
                    loadingView
                        .transition(.opacity.animation(.easeInOut(duration: loadingAnimationDuration)))
                } else if let image = viewModel.currentImage {
                    imageView(image: image, in: geometry)
                        .transition(.opacity.animation(.easeInOut(duration: transitionDuration)))
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                        .transition(.opacity.animation(.easeInOut(duration: transitionDuration)))
                } else {
                    emptyStateView
                        .transition(.opacity.animation(.easeInOut(duration: transitionDuration)))
                }
                
                // Mini-map navigator overlay
                if viewModel.currentImage != nil {
                    MiniMapNavigatorView(
                        zoomLevel: viewModel.zoomLevel,
                        isFitToWindow: viewModel.isZoomFitToWindow,
                        imageSize: imageSize,
                        viewportSize: containerSize,
                        panOffset: dragOffset,
                        onNavigate: { targetPoint in
                            navigateToPoint(targetPoint)
                        }
                    )
                    .padding(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 20))
                }
                
                // Zoom target indicator
                if showZoomTarget {
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .position(zoomTargetLocation)
                        .transition(.opacity.combined(with: .scale))
                }
                
                // Zoom indicator overlay
                if viewModel.currentImage != nil && showZoomIndicator {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZoomIndicatorView(
                                zoomLevel: viewModel.zoomLevel,
                                isFitToWindow: viewModel.isZoomFitToWindow,
                                imageSize: imageSize,
                                viewportSize: containerSize
                            )
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 20))
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .onAppear {
                containerSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                containerSize = newSize
                resetZoomAndPan()
            }
            .onChange(of: viewModel.currentImage) { _ in
                // Reset zoom and pan when image changes for smooth transitions
                withAnimation(.easeInOut(duration: transitionDuration)) {
                    resetZoomAndPan()
                }
                
                // Show zoom indicator when new image loads
                if viewModel.currentImage != nil {
                    showZoomIndicator = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        showZoomIndicator = false
                    }
                }
            }
            .onChange(of: viewModel.zoomLevel) { newZoomLevel in
                updateMagnificationFromZoomLevel(newZoomLevel)
                showZoomIndicator = true
                
                // Auto-hide zoom indicator after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showZoomIndicator = false
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            // Enhanced skeleton loading placeholder
            skeletonImagePlaceholder
                .frame(maxWidth: 600, maxHeight: 400)
            
            // Progress information
            if viewModel.loadingProgress > 0 {
                VStack(spacing: 8) {
                    Text("Loading...")
                        .foregroundColor(.appText)
                        .font(.headline)
                        .accessibilityHidden(true)
                    
                    ProgressView(value: viewModel.loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.appAccent))
                        .frame(width: 200)
                        .accessibilityLabel("Loading progress")
                        .accessibilityValue("\(Int(viewModel.loadingProgress * 100)) percent complete")
                    
                    Text("\(Int(viewModel.loadingProgress * 100))%")
                        .foregroundColor(.appSecondaryText)
                        .font(.caption)
                        .accessibilityHidden(true)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appAccent))
                        .scaleEffect(1.2)
                        .accessibilityLabel("Loading image")
                    
                    Text("Loading...")
                        .foregroundColor(.appText)
                        .font(.headline)
                        .accessibilityHidden(true)
                }
            }
            
            Button("Cancel") {
                viewModel.cancelLoading()
            }
            .foregroundColor(.appSecondaryText)
            .font(.caption)
            .accessibilityLabel("Cancel loading")
            .accessibilityHint("Stops loading the current image")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appOverlayBackground)
                .shadow(color: .black.opacity(Color.isDarkMode ? 0.4 : 0.2), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Loading image, \(Int(viewModel.loadingProgress * 100)) percent complete")
    }
    
    // MARK: - Skeleton Image Placeholder
    
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var pulseOpacity: Double = 0.3
    
    private var skeletonImagePlaceholder: some View {
        GeometryReader { geometry in
            let placeholderSize = calculateSkeletonSize(in: geometry)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(skeletonGradient)
                .frame(width: placeholderSize.width, height: placeholderSize.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .overlay(
                    // Shimmer effect overlay
                    shimmerOverlay(size: placeholderSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                )
                .overlay(
                    // Photo icon in center
                    Image(systemName: "photo")
                        .font(.system(size: min(placeholderSize.width, placeholderSize.height) * 0.15))
                        .foregroundColor(.secondary.opacity(0.6))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                )
        }
        .aspectRatio(viewModel.expectedImageSize != nil ? 
                    viewModel.expectedImageSize!.width / viewModel.expectedImageSize!.height : 4/3, 
                    contentMode: .fit)
        .onAppear {
            startSkeletonAnimations()
        }
    }
    
    private func calculateSkeletonSize(in geometry: GeometryProxy) -> CGSize {
        if let imageSize = viewModel.expectedImageSize {
            // Use actual image dimensions if available
            let aspectRatio = imageSize.width / imageSize.height
            let maxWidth = min(geometry.size.width * 0.8, 600)
            let maxHeight = min(geometry.size.height * 0.6, 400)
            
            if aspectRatio > 1 {
                // Landscape image
                let width = min(maxWidth, maxHeight * aspectRatio)
                return CGSize(width: width, height: width / aspectRatio)
            } else {
                // Portrait or square image
                let height = min(maxHeight, maxWidth / aspectRatio)
                return CGSize(width: height * aspectRatio, height: height)
            }
        } else {
            // Default placeholder size
            let size = min(geometry.size.width * 0.6, geometry.size.height * 0.5, 300)
            return CGSize(width: size * 1.33, height: size) // 4:3 aspect ratio
        }
    }
    
    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.2),
                Color.gray.opacity(0.15),
                Color.gray.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func shimmerOverlay(size: CGSize) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width * 0.3, height: size.height)
            .offset(x: shimmerOffset * size.width * 1.5)
    }
    
    private func startSkeletonAnimations() {
        // Start shimmer animation if motion is allowed
        if !AccessibilityService.shared.isReducedMotionEnabled {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.0
            }
            
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.8
            }
        }
    }
    
    // MARK: - Image View
    private func imageView(image: NSImage, in geometry: GeometryProxy) -> some View {
        let nsImage = image
        let imageAspectRatio = nsImage.size.width / nsImage.size.height
        let containerAspectRatio = geometry.size.width / geometry.size.height
        
        // Calculate fit-to-window size while maintaining aspect ratio
        let fitSize: CGSize
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container
            fitSize = CGSize(
                width: geometry.size.width,
                height: geometry.size.width / imageAspectRatio
            )
        } else {
            // Image is taller than container
            fitSize = CGSize(
                width: geometry.size.height * imageAspectRatio,
                height: geometry.size.height
            )
        }
        
        // Calculate display size based on zoom level
        let displaySize: CGSize
        if viewModel.isZoomFitToWindow {
            displaySize = fitSize
        } else {
            displaySize = CGSize(
                width: nsImage.size.width * viewModel.zoomLevel,
                height: nsImage.size.height * viewModel.zoomLevel
            )
        }
        
        return ZStack {
            // Scroll wheel handler overlay
            ScrollWheelView { location, deltaY in
                let zoomIn = deltaY > 0
                zoomToCursor(at: location, zoomIn: zoomIn)
            }
            
            // Main image
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: displaySize.width, height: displaySize.height)
                .scaleEffect(magnification)
                .offset(x: dragOffset.width, y: dragOffset.height)
                .accessibilityLabel(imageAccessibilityDescription)
                .accessibilityHint("Drag to pan, pinch, scroll wheel, or double-click to zoom. Right-click for options.")
                .accessibilityAddTraits(.isImage)
                .onTapGesture(count: 2) { location in
                    // Double-click to zoom in/out
                    let shouldZoomIn = viewModel.zoomLevel < 2.0
                    zoomToCursor(at: location, zoomIn: shouldZoomIn)
                }
                .imageContextMenu(
                    for: viewModel.currentImageFile,
                    viewModel: viewModel
                )
        }
            .gesture(
                SimultaneousGesture(
                    // Pan gesture
                    DragGesture()
                        .onChanged { value in
                            dragOffset = CGSize(
                                width: lastDragOffset.width + value.translation.width,
                                height: lastDragOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastDragOffset = dragOffset
                        },
                    
                    // Zoom gesture with cursor-based zoom
                    MagnificationGesture()
                        .onChanged { value in
                            magnification = lastMagnification * value
                            
                            // Show zoom indicator during gesture
                            showZoomIndicator = true
                        }
                        .onEnded { value in
                            lastMagnification = magnification
                            
                            // Update view model zoom level based on gesture
                            let newZoomLevel = viewModel.zoomLevel * value
                            viewModel.setZoom(max(0.1, min(5.0, newZoomLevel)))
                            
                            // Keep showing zoom indicator briefly after gesture ends
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                showZoomIndicator = false
                            }
                        }
                )
            )
            .onAppear {
                imageSize = displaySize
            }
            .onChange(of: displaySize) { newSize in
                imageSize = newSize
            }
            .animation(.easeInOut(duration: transitionDuration), value: displaySize)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.appWarning)
                .accessibilityHidden(true)
            
            Text(message)
                .foregroundColor(.appText)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
            
            Button("Dismiss") {
                viewModel.clearError()
            }
            .foregroundColor(.appSecondaryText)
            .font(.caption)
            .accessibilityLabel("Dismiss error")
            .accessibilityHint("Closes the error message")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appOverlayBackground)
                .shadow(color: .black.opacity(Color.isDarkMode ? 0.4 : 0.2), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(message)")
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundColor(.appSecondaryText)
                .accessibilityHidden(true)
            
            Text("No Image Selected")
                .foregroundColor(.appText)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            Text("Select a folder to start browsing images")
                .foregroundColor(.appSecondaryText)
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No image selected. Select a folder to start browsing images. Right-click for options.")
        .emptyAreaContextMenu(viewModel: viewModel)
    }
    
    // MARK: - Helper Methods
    private func resetZoomAndPan() {
        dragOffset = .zero
        lastDragOffset = .zero
        magnification = 1.0
        lastMagnification = 1.0
    }
    
    private func updateMagnificationFromZoomLevel(_ zoomLevel: Double) {
        withAnimation(.easeInOut(duration: transitionDuration)) {
            magnification = 1.0
            lastMagnification = 1.0
        }
    }
    
    /// Navigate to a specific point on the image via mini-map
    private func navigateToPoint(_ targetPoint: CGPoint) {
        guard let image = viewModel.currentImage else { return }
        
        // Calculate the required pan offset to center the target point
        let imageDisplaySize = CGSize(
            width: image.size.width * viewModel.zoomLevel,
            height: image.size.height * viewModel.zoomLevel
        )
        
        // Calculate where the target point should be positioned (center of viewport)
        let targetOffsetX = containerSize.width / 2 - (targetPoint.x * viewModel.zoomLevel)
        let targetOffsetY = containerSize.height / 2 - (targetPoint.y * viewModel.zoomLevel)
        
        // Clamp the offset to valid bounds
        let maxOffsetX = max(0, (imageDisplaySize.width - containerSize.width) / 2)
        let maxOffsetY = max(0, (imageDisplaySize.height - containerSize.height) / 2)
        
        let clampedOffsetX = max(-maxOffsetX, min(maxOffsetX, targetOffsetX))
        let clampedOffsetY = max(-maxOffsetY, min(maxOffsetY, targetOffsetY))
        
        // Animate to the new position
        withAnimation(.easeInOut(duration: 0.3)) {
            dragOffset = CGSize(width: clampedOffsetX, height: clampedOffsetY)
            lastDragOffset = dragOffset
        }
    }
    
    /// Zoom toward a specific cursor position
    private func zoomToCursor(at location: CGPoint, zoomIn: Bool) {
        guard let image = viewModel.currentImage else { return }
        
        let currentZoom = viewModel.zoomLevel
        let zoomFactor: Double = zoomIn ? 1.2 : 0.8
        let newZoom = max(0.1, min(5.0, currentZoom * zoomFactor))
        
        // Don't zoom if we're already at the limit
        guard newZoom != currentZoom else { return }
        
        // Show zoom target feedback
        zoomTargetLocation = location
        showZoomTarget = true
        
        // Calculate the point in image coordinates before zoom
        let imageDisplaySize = CGSize(
            width: image.size.width * currentZoom,
            height: image.size.height * currentZoom
        )
        
        // Convert cursor location to image coordinates
        let imageX = (location.x - dragOffset.width - containerSize.width / 2 + imageDisplaySize.width / 2) / currentZoom
        let imageY = (location.y - dragOffset.height - containerSize.height / 2 + imageDisplaySize.height / 2) / currentZoom
        
        // Update zoom level
        viewModel.setZoom(newZoom)
        
        // Calculate new display size
        let newImageDisplaySize = CGSize(
            width: image.size.width * newZoom,
            height: image.size.height * newZoom
        )
        
        // Calculate new offset to keep the cursor point in the same position
        let newOffsetX = containerSize.width / 2 - location.x - (imageX * newZoom - newImageDisplaySize.width / 2)
        let newOffsetY = containerSize.height / 2 - location.y - (imageY * newZoom - newImageDisplaySize.height / 2)
        
        // Clamp the offset to valid bounds
        let maxOffsetX = max(0, (newImageDisplaySize.width - containerSize.width) / 2)
        let maxOffsetY = max(0, (newImageDisplaySize.height - containerSize.height) / 2)
        
        let clampedOffsetX = max(-maxOffsetX, min(maxOffsetX, newOffsetX))
        let clampedOffsetY = max(-maxOffsetY, min(maxOffsetY, newOffsetY))
        
        // Animate to the new position
        withAnimation(.easeInOut(duration: 0.2)) {
            dragOffset = CGSize(width: clampedOffsetX, height: clampedOffsetY)
            lastDragOffset = dragOffset
        }
        
        // Show zoom indicator
        showZoomIndicator = true
        
        // Hide visual feedback after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showZoomTarget = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showZoomIndicator = false
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private var imageAccessibilityDescription: String {
        guard let currentImageFile = viewModel.currentImageFile else {
            return "Image"
        }
        
        // Get base description from file name
        let fileName = currentImageFile.name
        var description = "Image: \(fileName)"
        
        // Add dimensions if available
        if let image = viewModel.currentImage {
            let width = Int(image.size.width)
            let height = Int(image.size.height)
            description += ", \(width) by \(height) pixels"
        }
        
        // Try to get rich metadata description
        let metadataService = ImageMetadataService()
        let metadata = metadataService.extractMetadata(from: currentImageFile.url)
        
        // Add metadata if available
        if !metadata.accessibilityDescription.isEmpty {
            description = metadata.accessibilityDescription
        }
        
        // Add current viewing context
        description += ". Zoom \(viewModel.zoomPercentageText)"
        description += ". Image \(viewModel.currentIndex + 1) of \(viewModel.totalImages)"
        
        return description
    }
}

// MARK: - Preview
#Preview {
    ImageDisplayView(viewModel: ImageViewerViewModel())
        .frame(width: 800, height: 600)
}