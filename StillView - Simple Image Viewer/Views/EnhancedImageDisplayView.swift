import AppKit
import Combine
import SwiftUI

/// One source of truth for mapping image pixels into the window's point coordinate space.
struct ImageViewportLayout: Equatable {
    let pixelSize: CGSize
    let viewportSize: CGSize
    let displayScale: CGFloat

    private var actualSize: CGSize {
        guard pixelSize.width.isFinite, pixelSize.height.isFinite,
              pixelSize.width > 0, pixelSize.height > 0 else { return .zero }
        let scale = displayScale.isFinite && displayScale > 0 ? displayScale : 1
        return CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
    }

    var fitZoomLevel: Double {
        let size = actualSize
        guard size.width > 0, size.height > 0,
              viewportSize.width.isFinite, viewportSize.height.isFinite else { return 0 }
        // Preserve the Studio stage's 28-point side and 24-point vertical insets.
        let width = max(0, viewportSize.width - 56)
        let height = max(0, viewportSize.height - 48)
        return Double(min(width / size.width, height / size.height))
    }

    func renderedSize(zoomLevel: Double) -> CGSize {
        let zoom = zoomLevel == -1 ? fitZoomLevel : zoomLevel
        guard zoom.isFinite, zoom > 0 else { return .zero }
        return CGSize(width: actualSize.width * zoom, height: actualSize.height * zoom)
    }

    func clampedOffset(_ offset: CGSize, zoomLevel: Double) -> CGSize {
        let rendered = renderedSize(zoomLevel: zoomLevel)
        let horizontalLimit = max(0, (rendered.width - max(0, viewportSize.width)) / 2)
        let verticalLimit = max(0, (rendered.height - max(0, viewportSize.height)) / 2)
        return CGSize(
            width: offset.width.isFinite ? max(-horizontalLimit, min(horizontalLimit, offset.width)) : 0,
            height: offset.height.isFinite ? max(-verticalLimit, min(verticalLimit, offset.height)) : 0
        )
    }

    static func pixelSize(of image: NSImage) -> CGSize {
        // NSImage.size is expressed in points and can reflect an embedded DPI value.
        // Bitmap dimensions preserve actual-size semantics even when those values differ.
        let representation = image.representations
            .filter { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }
            .max { Double($0.pixelsWide) * Double($0.pixelsHigh) < Double($1.pixelsWide) * Double($1.pixelsHigh) }
        guard let representation else { return image.size }
        return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }
}

/// Persistent gesture state; each new gesture begins from the current viewport.
struct ImageViewportState {
    private(set) var offset: CGSize = .zero
    private var dragStartOffset: CGSize?
    private var magnificationStartZoom: Double?

    mutating func updateDrag(translation: CGSize, layout: ImageViewportLayout, zoomLevel: Double) {
        let start = dragStartOffset ?? offset
        dragStartOffset = start
        offset = layout.clampedOffset(
            CGSize(width: start.width + translation.width, height: start.height + translation.height),
            zoomLevel: zoomLevel
        )
    }

    mutating func endDrag(translation: CGSize, layout: ImageViewportLayout, zoomLevel: Double) {
        updateDrag(translation: translation, layout: layout, zoomLevel: zoomLevel)
        dragStartOffset = nil
    }

    mutating func clamp(to layout: ImageViewportLayout, zoomLevel: Double) {
        offset = layout.clampedOffset(offset, zoomLevel: zoomLevel)
    }

    mutating func magnifiedZoom(_ magnification: Double, currentZoom: Double, fitZoom: Double) -> Double {
        let start = magnificationStartZoom ?? (currentZoom == -1 ? fitZoom : currentZoom)
        magnificationStartZoom = start
        guard magnification.isFinite, magnification > 0 else { return start }
        return max(0.01, min(max(5, fitZoom), start * magnification))
    }

    mutating func endMagnification() {
        magnificationStartZoom = nil
    }

    mutating func reset() {
        offset = .zero
        dragStartOffset = nil
        magnificationStartZoom = nil
    }
}

/// Enhanced image display view with macOS 26 capabilities
struct EnhancedImageDisplayView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    @StateObject private var enhancedProcessing = EnhancedImageProcessingService.shared
    @State private var viewportState = ImageViewportState()
    @State private var isProcessing: Bool = false
    @State private var processingProgress: Double = 0.0

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let layout = ImageViewportLayout(
                pixelSize: viewModel.currentImage.map(ImageViewportLayout.pixelSize(of:)) ?? .zero,
                viewportSize: geometry.size,
                displayScale: displayScale
            )
            ZStack {
                // Background
                backgroundView
                
                // Main image content
                if let image = viewModel.currentImage {
                    imageContent(image, layout: layout)
                } else {
                    placeholderContent
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    loadingOverlay
                }
                
                // Processing overlay
                if isProcessing {
                    processingOverlay
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(magnificationGesture(layout).simultaneously(with: dragGesture(layout)))
            .onTapGesture(count: 2) {
                handleDoubleTap()
            }
            .onAppear { updateLayout(layout) }
            .onChange(of: layout) { _, updated in updateLayout(updated) }
            .onChange(of: viewModel.currentImageFile?.url) { _, _ in viewportState.reset() }
            .onChange(of: viewModel.currentImage.map { ObjectIdentifier($0) }) { _, _ in
                viewportState.reset()
                updateLayout(layout)
            }
            .onChange(of: viewModel.zoomLevel) { _, zoom in
                if zoom == -1 {
                    viewportState.reset()
                } else {
                    viewportState.clamp(to: layout, zoomLevel: zoom)
                }
            }
        }
        .onReceive(enhancedProcessing.$isProcessing) { processing in
            isProcessing = processing
        }
        .onReceive(enhancedProcessing.$processingProgress) { progress in
            processingProgress = progress
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var backgroundView: some View {
        // Dedicated stage color — never windowBackgroundColor (finding V2)
        Color.appStage
            .ignoresSafeArea()
    }

    @ViewBuilder
    private func imageContent(_ image: NSImage, layout: ImageViewportLayout) -> some View {
        let size = layout.renderedSize(zoomLevel: viewModel.zoomLevel)
        Image(nsImage: image)
            .resizable()
            .frame(width: size.width, height: size.height)
            // Photos on the light stage get a cast shadow (Studio Screen 2)
            .shadow(
                color: colorScheme == .dark
                    ? .clear
                    : Color(.sRGB, red: 60 / 255, green: 70 / 255, blue: 90 / 255, opacity: 0.35),
                radius: 25, x: 0, y: 9
            )
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.12),
                radius: 6, x: 0, y: 1.5
            )
            .offset(layout.clampedOffset(viewportState.offset, zoomLevel: viewModel.zoomLevel))
            // Precision inspection follows input directly, including when Reduce Motion is enabled.
            .transaction { $0.animation = nil }
            .accessibilityLabel(viewModel.currentFileName)
            .accessibilityValue(viewModel.zoomPercentageText)
    }
    
    @ViewBuilder
    private var placeholderContent: some View {
        if let message = viewModel.errorMessage, !viewModel.isLoading {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)

                Text("Unable to display image")
                    .font(.title2)

                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                if viewModel.currentImageFile != nil {
                    Button("Retry") { viewModel.retryCurrentImage() }
                        .buttonStyle(.bordered)
                        .help("Try loading the selected image again")
                }
            }
            .padding(24)
        } else if !viewModel.isLoading {
            VStack(spacing: 16) {
                Image(systemName: "photo")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)

                Text("No Image Selected")
                    .font(.title2)
                    .foregroundColor(.secondary)

                if viewModel.totalImages == 0 {
                    Text("Select a folder containing images to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Loading Image...")
                .font(.headline)
                .foregroundColor(.primary)
            
            if viewModel.loadingProgress > 0 {
                ProgressView(value: viewModel.loadingProgress)
                    .frame(width: 200)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var processingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Enhancing Image...")
                .font(.headline)
                .foregroundColor(.primary)
            
            ProgressView(value: processingProgress)
                .frame(width: 200)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Gesture Handlers
    
    private func updateLayout(_ layout: ImageViewportLayout) {
        viewModel.updateFitZoomLevel(layout.fitZoomLevel)
        viewportState.clamp(to: layout, zoomLevel: viewModel.zoomLevel)
    }

    private func magnificationGesture(_ layout: ImageViewportLayout) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                viewModel.setZoom(viewportState.magnifiedZoom(
                    Double(value), currentZoom: viewModel.zoomLevel, fitZoom: layout.fitZoomLevel
                ))
            }
            .onEnded { value in
                viewModel.setZoom(viewportState.magnifiedZoom(
                    Double(value), currentZoom: viewModel.zoomLevel, fitZoom: layout.fitZoomLevel
                ))
                viewportState.endMagnification()
            }
    }

    private func dragGesture(_ layout: ImageViewportLayout) -> some Gesture {
        DragGesture()
            .onChanged { value in
                viewportState.updateDrag(translation: value.translation, layout: layout, zoomLevel: viewModel.zoomLevel)
            }
            .onEnded { value in
                viewportState.endDrag(translation: value.translation, layout: layout, zoomLevel: viewModel.zoomLevel)
            }
    }
    
    private func handleDoubleTap() {
        if viewModel.zoomLevel == 1.0 {
            viewModel.zoomToFit()
        } else {
            viewModel.zoomToActualSize()
        }
    }
    
}

// MARK: - Preview

#Preview {
    EnhancedImageDisplayView(viewModel: ImageViewerViewModel())
        .frame(width: 800, height: 600)
}
