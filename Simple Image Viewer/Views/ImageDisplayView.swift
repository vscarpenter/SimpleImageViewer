import SwiftUI
import AppKit

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
    
    // MARK: - Animation Properties
    private let transitionDuration: Double = 0.08 // Under 100ms as required
    private let loadingAnimationDuration: Double = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
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
            }
            .onChange(of: viewModel.zoomLevel) { newZoomLevel in
                updateMagnificationFromZoomLevel(newZoomLevel)
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
                .accessibilityLabel("Loading image")
            
            if viewModel.loadingProgress > 0 {
                VStack(spacing: 8) {
                    Text("Loading...")
                        .foregroundColor(.white)
                        .font(.headline)
                        .accessibilityHidden(true)
                    
                    ProgressView(value: viewModel.loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 200)
                        .accessibilityLabel("Loading progress")
                        .accessibilityValue("\(Int(viewModel.loadingProgress * 100)) percent complete")
                    
                    Text("\(Int(viewModel.loadingProgress * 100))%")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                        .accessibilityHidden(true)
                }
            } else {
                Text("Loading...")
                    .foregroundColor(.white)
                    .font(.headline)
                    .accessibilityHidden(true)
            }
            
            Button("Cancel") {
                viewModel.cancelLoading()
            }
            .foregroundColor(.white.opacity(0.8))
            .font(.caption)
            .accessibilityLabel("Cancel loading")
            .accessibilityHint("Stops loading the current image")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Loading image, \(Int(viewModel.loadingProgress * 100)) percent complete")
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
        
        return Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: displaySize.width, height: displaySize.height)
            .scaleEffect(magnification)
            .offset(x: dragOffset.width, y: dragOffset.height)
            .accessibilityLabel(imageAccessibilityDescription)
            .accessibilityHint("Drag to pan, pinch or use zoom controls to resize")
            .accessibilityAddTraits(.isImage)
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
                    
                    // Zoom gesture
                    MagnificationGesture()
                        .onChanged { value in
                            magnification = lastMagnification * value
                        }
                        .onEnded { value in
                            lastMagnification = magnification
                            
                            // Update view model zoom level based on gesture
                            let newZoomLevel = viewModel.zoomLevel * value
                            viewModel.setZoom(max(0.1, min(5.0, newZoomLevel)))
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
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            
            Text(message)
                .foregroundColor(.white)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
            
            Button("Dismiss") {
                viewModel.clearError()
            }
            .foregroundColor(.white.opacity(0.8))
            .font(.caption)
            .accessibilityLabel("Dismiss error")
            .accessibilityHint("Closes the error message")
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(message)")
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .accessibilityHidden(true)
            
            Text("No Image Selected")
                .foregroundColor(.gray)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            Text("Select a folder to start browsing images")
                .foregroundColor(.gray.opacity(0.8))
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No image selected. Select a folder to start browsing images")
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