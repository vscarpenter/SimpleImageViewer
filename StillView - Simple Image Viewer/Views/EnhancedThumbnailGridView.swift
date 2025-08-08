import SwiftUI
import AppKit
import Combine

/// Enhanced thumbnail grid view with metadata badges and smooth animations
struct EnhancedThumbnailGridView: View {
    // MARK: - Properties
    
    /// Array of image files to display
    let imageFiles: [ImageFile]
    
    /// Currently selected image file
    let selectedImageFile: ImageFile?
    
    /// Thumbnail quality level
    let thumbnailQuality: ThumbnailQuality
    
    /// View model for context menu actions
    let viewModel: ImageViewerViewModel
    
    /// Callback when an image is selected
    let onImageSelected: (ImageFile) -> Void
    
    /// Callback when an image is double-clicked
    let onImageDoubleClicked: (ImageFile) -> Void
    
    // MARK: - State Properties
    
    @State private var hoveredImageFile: ImageFile?
    @State private var thumbnailCache: [URL: NSImage] = [:]
    @State private var loadingThumbnails: Set<URL> = []
    @StateObject private var layoutManager = ResponsiveGridLayoutManager()
    
    // MARK: - Services
    
    private let thumbnailGenerator = EnhancedThumbnailGenerator.createIntegrated()
    
    // MARK: - Constants
    
    private let animationDuration: Double = 0.3
    private let hoverAnimationDuration: Double = 0.2
    private let selectionAnimationDuration: Double = 0.25
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: layoutManager.getGridColumns(), spacing: layoutManager.effectiveGridSize.spacing) {
                    ForEach(Array(imageFiles.enumerated()), id: \.element.url) { index, imageFile in
                        ThumbnailGridItem(
                            imageFile: imageFile,
                            index: index,
                            viewModel: viewModel,
                            isSelected: selectedImageFile?.url == imageFile.url,
                            isHovered: hoveredImageFile?.url == imageFile.url,
                            thumbnail: thumbnailCache[imageFile.url],
                            isLoading: loadingThumbnails.contains(imageFile.url),
                            thumbnailSize: layoutManager.getOptimalThumbnailSize(),
                            onTap: { onImageSelected(imageFile) },
                            onDoubleTap: { onImageDoubleClicked(imageFile) },
                            onHover: { isHovering in
                                withAnimation(.easeInOut(duration: hoverAnimationDuration)) {
                                    hoveredImageFile = isHovering ? imageFile : nil
                                }
                            }
                        )
                        .onAppear {
                            loadThumbnailIfNeeded(for: imageFile)
                        }
                    }
                }
                .padding(layoutManager.effectiveGridSize.padding)
            }
            .onAppear {
                layoutManager.updateWindowSize(geometry.size)
                preloadVisibleThumbnails()
            }
            .onChange(of: geometry.size) { newSize in
                if layoutManager.shouldUpdateLayout(for: newSize) {
                    layoutManager.updateWindowSize(newSize)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedImageFile?.url)
        .animation(.easeInOut(duration: 0.3), value: layoutManager.effectiveGridSize)
    }
    
    // MARK: - Private Methods
    
    private func loadThumbnailIfNeeded(for imageFile: ImageFile) {
        guard thumbnailCache[imageFile.url] == nil,
              !loadingThumbnails.contains(imageFile.url) else {
            return
        }
        
        loadingThumbnails.insert(imageFile.url)
        
        thumbnailGenerator.generateThumbnail(from: imageFile.url, quality: thumbnailQuality)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    loadingThumbnails.remove(imageFile.url)
                    if case .failure(let error) = completion {
                        print("Failed to generate thumbnail for \(imageFile.url): \(error)")
                    }
                },
                receiveValue: { thumbnail in
                    withAnimation(.easeInOut(duration: animationDuration)) {
                        thumbnailCache[imageFile.url] = thumbnail
                    }
                    loadingThumbnails.remove(imageFile.url)
                }
            )
            .store(in: &cancellables)
    }
    
    private func preloadVisibleThumbnails() {
        // Preload first batch of thumbnails
        let preloadCount = min(layoutManager.getOptimalColumnCount() * 3, imageFiles.count)
        for i in 0..<preloadCount {
            loadThumbnailIfNeeded(for: imageFiles[i])
        }
    }
    
    // MARK: - Public Methods
    
    /// Set the user's preferred grid size
    /// - Parameter gridSize: The preferred grid size
    func setPreferredGridSize(_ gridSize: ThumbnailGridSize) {
        layoutManager.setUserPreferredGridSize(gridSize)
    }
    
    /// Toggle responsive layout on/off
    /// - Parameter enabled: Whether responsive layout should be enabled
    func setResponsiveLayoutEnabled(_ enabled: Bool) {
        layoutManager.setResponsiveLayoutEnabled(enabled)
    }
    
    /// Get the current layout manager for external access
    /// - Returns: The responsive grid layout manager
    func getLayoutManager() -> ResponsiveGridLayoutManager {
        return layoutManager
    }
    
    // MARK: - Cancellables Storage
    
    @State private var cancellables = Set<AnyCancellable>()
}

/// Individual thumbnail grid item with metadata and animations
private struct ThumbnailGridItem: View {
    // MARK: - Properties
    
    let imageFile: ImageFile
    let index: Int
    let viewModel: ImageViewerViewModel
    let isSelected: Bool
    let isHovered: Bool
    let thumbnail: NSImage?
    let isLoading: Bool
    let thumbnailSize: CGSize
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onHover: (Bool) -> Void
    
    // MARK: - Animation State
    
    @State private var animationScale: CGFloat = 1.0
    @State private var animationOpacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 8) {
            thumbnailContainer
        }
        .scaleEffect(animationScale)
        .opacity(animationOpacity)
        .onHover { hovering in
            onHover(hovering)
            
            // Hover animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                animationScale = hovering ? 1.05 : 1.0
            }
        }
        .onTapGesture {
            // Selection animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                animationScale = 0.95
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animationScale = isHovered ? 1.05 : 1.0
                }
            }
            
            onTap()
        }
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Image: \(imageFile.url.lastPathComponent)")
        .accessibilityHint("Tap to select, double-tap to open, right-click for options")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .thumbnailContextMenu(for: imageFile, at: index, viewModel: viewModel)
    }
    
    private var thumbnailContainer: some View {
        ZStack {
            backgroundView
            thumbnailContentView
            selectionIndicator
            hoverOverlay
            metadataBadgesOverlay
            fileNameLabel
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
    }
    
    @ViewBuilder
    private var thumbnailContentView: some View {
        if let thumbnail = thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .scale))
        } else if isLoading {
            SkeletonThumbnailView(size: thumbnailSize)
        } else {
            Image(systemName: "photo")
                .font(.system(size: thumbnailSize.width * 0.3))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appAccent, lineWidth: 3)
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private var hoverOverlay: some View {
        if isHovered && !isSelected {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appAccent.opacity(0.2))
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .transition(.opacity)
        }
    }
    
    private var metadataBadgesOverlay: some View {
        VStack {
            HStack {
                Spacer()
                if isHovered || isSelected {
                    FileFormatBadge(fileExtension: imageFile.url.pathExtension)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Spacer()
            HStack {
                if isHovered || isSelected {
                    FileSizeBadge(fileSize: imageFile.size)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                if isHovered || isSelected {
                    DateBadge(date: imageFile.modificationDate)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(6)
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
    }
    
    private var fileNameLabel: some View {
        Text(imageFile.url.lastPathComponent)
            .font(.caption)
            .foregroundColor(.appText)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(width: thumbnailSize.width)
            .opacity(isHovered || isSelected ? 1.0 : 0.7)
    }
}

/// Skeleton loading view for thumbnails
private struct SkeletonThumbnailView: View {
    let size: CGSize
    
    @State private var shimmerOffset: CGFloat = -1.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.15),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.width, height: size.height)
            .overlay(
                // Shimmer effect
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            )
            .onAppear {
                if !AccessibilityService.shared.isReducedMotionEnabled {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        shimmerOffset = 1.0
                    }
                }
            }
    }
}

/// File format badge
private struct FileFormatBadge: View {
    let fileExtension: String
    
    var body: some View {
        Text(fileExtension.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(formatColor)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            )
    }
    
    private var formatColor: Color {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg":
            return .orange
        case "png":
            return .blue
        case "gif":
            return .green
        case "heic", "heif":
            return .purple
        case "tiff", "tif":
            return .red
        case "webp":
            return .pink
        default:
            return .gray
        }
    }
}

/// File size badge
private struct FileSizeBadge: View {
    let fileSize: Int64
    
    var body: some View {
        Text(formattedFileSize)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            )
    }
    
    private var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

/// Date badge
private struct DateBadge: View {
    let date: Date
    
    var body: some View {
        Text(formattedDate)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            )
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// ThumbnailGridSize enum is defined in ThumbnailQuality.swift

// MARK: - Preview

#Preview {
    // Create sample ImageFile instances using the proper initializer
    let sampleImageFiles: [ImageFile] = []
    
    // For preview purposes, we'll use an empty array since ImageFile requires actual file URLs
    // In a real scenario, these would be loaded from the file system
    
    EnhancedThumbnailGridView(
        imageFiles: sampleImageFiles,
        selectedImageFile: nil,
        thumbnailQuality: .medium,
        viewModel: ImageViewerViewModel(),
        onImageSelected: { _ in },
        onImageDoubleClicked: { _ in }
    )
    .frame(width: 800, height: 600)
}