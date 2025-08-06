import SwiftUI

/// Skeleton loading view that shows animated placeholder shapes while images are loading
struct SkeletonLoadingView: View {
    // MARK: - State Properties
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var pulseOpacity: Double = 0.3
    
    // MARK: - Configuration Properties
    let imageSize: CGSize?
    let showProgressBar: Bool
    let loadingProgress: Double
    
    // MARK: - Animation Properties
    private let shimmerDuration: Double = 1.5
    private let pulseDuration: Double = 1.0
    
    init(imageSize: CGSize? = nil, showProgressBar: Bool = false, loadingProgress: Double = 0.0) {
        self.imageSize = imageSize
        self.showProgressBar = showProgressBar
        self.loadingProgress = loadingProgress
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Main skeleton image placeholder
            skeletonImagePlaceholder
            
            // Progress information
            if showProgressBar && loadingProgress > 0 {
                progressSection
            } else {
                loadingIndicator
            }
        }
        .onAppear {
            startAnimations()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading image")
        .accessibilityValue(showProgressBar ? "\(Int(loadingProgress * 100)) percent complete" : "Loading in progress")
    }
    
    // MARK: - Skeleton Image Placeholder
    
    private var skeletonImagePlaceholder: some View {
        GeometryReader { geometry in
            let placeholderSize = calculatePlaceholderSize(in: geometry)
            
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
        .aspectRatio(imageSize != nil ? imageSize!.width / imageSize!.height : 4/3, contentMode: .fit)
        .frame(maxWidth: 600, maxHeight: 400)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressView(value: loadingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.accentColor))
                .frame(width: 200)
                .accessibilityLabel("Loading progress")
                .accessibilityValue("\(Int(loadingProgress * 100)) percent complete")
            
            // Progress text
            Text("\(Int(loadingProgress * 100))%")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            // Loading text with pulse animation
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.primary)
                .opacity(pulseOpacity)
                .accessibilityHidden(true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Loading Indicator
    
    private var loadingIndicator: some View {
        VStack(spacing: 16) {
            // Animated loading spinner
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                .scaleEffect(1.2)
                .accessibilityLabel("Loading image")
            
            // Loading text with pulse animation
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.primary)
                .opacity(pulseOpacity)
                .accessibilityHidden(true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculatePlaceholderSize(in geometry: GeometryProxy) -> CGSize {
        if let imageSize = imageSize {
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
    
    private func startAnimations() {
        // Start shimmer animation
        let shimmerAnimation = Animation.linear(duration: shimmerDuration).repeatForever(autoreverses: false)
        if let adaptiveShimmer = AccessibilityService.shared.adaptiveAnimation(shimmerAnimation) {
            withAnimation(adaptiveShimmer) {
                shimmerOffset = 1.0
            }
        }
        
        // Start pulse animation
        let pulseAnimation = Animation.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)
        if let adaptivePulse = AccessibilityService.shared.adaptiveAnimation(pulseAnimation) {
            withAnimation(adaptivePulse) {
                pulseOpacity = 0.8
            }
        }
    }
}

// MARK: - Progressive Loading View

/// Progressive loading view that shows a low-resolution preview while the full image loads
struct ProgressiveLoadingView: View {
    let previewImage: NSImage?
    let loadingProgress: Double
    let targetSize: CGSize?
    
    @State private var blurRadius: CGFloat = 8.0
    @State private var overlayOpacity: Double = 0.8
    
    var body: some View {
        ZStack {
            if let previewImage = previewImage {
                // Low-resolution preview with blur
                Image(nsImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .blur(radius: blurRadius)
                    .overlay(
                        // Loading overlay
                        Rectangle()
                            .fill(.regularMaterial)
                            .opacity(overlayOpacity)
                    )
                    .overlay(
                        // Progress indicator
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                                .scaleEffect(1.2)
                            
                            if loadingProgress > 0 {
                                Text("\(Int(loadingProgress * 100))%")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 4)
                        )
                    )
                    .onChange(of: loadingProgress) { progress in
                        updateProgressiveEffects(progress: progress)
                    }
                    .accessibilityLabel("Loading high resolution image")
                    .accessibilityValue("\(Int(loadingProgress * 100)) percent complete")
            } else {
                // Fallback to skeleton loading if no preview available
                SkeletonLoadingView(
                    imageSize: targetSize,
                    showProgressBar: loadingProgress > 0,
                    loadingProgress: loadingProgress
                )
            }
        }
        .onAppear {
            updateProgressiveEffects(progress: loadingProgress)
        }
    }
    
    private func updateProgressiveEffects(progress: Double) {
        // Reduce blur and overlay opacity as loading progresses
        let targetBlur = max(0.0, 8.0 * (1.0 - progress))
        let targetOpacity = max(0.0, 0.8 * (1.0 - progress))
        
        let transitionAnimation = Animation.easeInOut(duration: 0.3)
        if let animation = AccessibilityService.shared.adaptiveAnimation(transitionAnimation) {
            withAnimation(animation) {
                blurRadius = targetBlur
                overlayOpacity = targetOpacity
            }
        } else {
            // No animation for reduced motion
            blurRadius = targetBlur
            overlayOpacity = targetOpacity
        }
    }
}

// MARK: - Preview

#Preview("Skeleton Loading") {
    VStack(spacing: 20) {
        SkeletonLoadingView()
            .frame(height: 300)
        
        SkeletonLoadingView(
            imageSize: CGSize(width: 800, height: 600),
            showProgressBar: true,
            loadingProgress: 0.65
        )
        .frame(height: 300)
    }
    .padding()
    .background(Color.black)
}

#Preview("Progressive Loading") {
    ProgressiveLoadingView(
        previewImage: NSImage(systemSymbolName: "photo", accessibilityDescription: nil),
        loadingProgress: 0.45,
        targetSize: CGSize(width: 800, height: 600)
    )
    .frame(width: 400, height: 300)
    .padding()
    .background(Color.black)
}