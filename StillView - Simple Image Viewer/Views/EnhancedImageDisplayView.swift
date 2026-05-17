import SwiftUI
import AppKit
import Combine

/// Enhanced image display view with macOS 26 capabilities
struct EnhancedImageDisplayView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    @StateObject private var enhancedProcessing = EnhancedImageProcessingService.shared
    @State private var dragOffset: CGSize = .zero
    @State private var magnification: CGFloat = 1.0
    @State private var isProcessing: Bool = false
    @State private var processingProgress: Double = 0.0
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundView
                
                // Main image content
                if let image = viewModel.currentImage {
                    modernImageContent(image, geometry: geometry)
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
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        handleMagnification(value)
                    }
                    .onEnded { value in
                        handleMagnificationEnd(value)
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDrag(value)
                    }
                    .onEnded { value in
                        handleDragEnd(value)
                    }
            )
            .onTapGesture(count: 2) {
                handleDoubleTap()
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
        Color(NSColor.windowBackgroundColor)
            .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func imageContent(_ image: NSImage, geometry: GeometryProxy) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(viewModel.zoomLevel == -1.0 ? 1.0 : viewModel.zoomLevel)
            .offset(dragOffset)
            .clipped()
            .animation(.easeInOut(duration: 0.3), value: viewModel.zoomLevel)
            .animation(.easeInOut(duration: 0.2), value: dragOffset)
    }
    
    @ViewBuilder
    private func modernImageContent(_ image: NSImage, geometry: GeometryProxy) -> some View {
        imageContent(image, geometry: geometry)
            .drawingGroup() // Enable hardware acceleration
    }
    
    @ViewBuilder
    private var placeholderContent: some View {
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
    
    private func handleMagnification(_ value: CGFloat) {
        let newMagnification = value * magnification
        let clampedMagnification = max(0.1, min(5.0, newMagnification))
        viewModel.setZoom(clampedMagnification)
    }
    
    private func handleMagnificationEnd(_ value: CGFloat) {
        magnification = viewModel.zoomLevel
    }
    
    private func handleDrag(_ value: DragGesture.Value) {
        if viewModel.zoomLevel > 1.0 {
            dragOffset = value.translation
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = .zero
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
