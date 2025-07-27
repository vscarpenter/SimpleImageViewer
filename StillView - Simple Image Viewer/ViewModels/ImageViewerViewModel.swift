import SwiftUI
import Combine
import AppKit

/// ViewModel for the main image viewer interface
class ImageViewerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentImage: NSImage?
    @Published var currentIndex: Int = 0
    @Published var totalImages: Int = 0
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var zoomLevel: Double = 1.0
    @Published var isFullscreen: Bool = false
    @Published var errorMessage: String?
    @Published var showFileName: Bool = false
    @Published var shouldNavigateToFolderSelection: Bool = false
    
    // MARK: - Computed Properties
    var hasNext: Bool {
        return currentIndex < totalImages - 1
    }
    
    var hasPrevious: Bool {
        return currentIndex > 0
    }
    
    var currentImageFile: ImageFile? {
        guard !imageFiles.isEmpty && currentIndex >= 0 && currentIndex < imageFiles.count else {
            return nil
        }
        return imageFiles[currentIndex]
    }
    
    var imageCounterText: String {
        guard totalImages > 0 else { return "No images" }
        return "\(currentIndex + 1) of \(totalImages)"
    }
    
    var currentFileName: String {
        return currentImageFile?.displayName ?? ""
    }
    
    // MARK: - Private Properties
    private var imageFiles: [ImageFile] = []
    private var folderContent: FolderContent?
    private var cancellables = Set<AnyCancellable>()
    private let imageLoaderService: ImageLoaderService
    private var preferencesService: PreferencesService
    private let errorHandlingService: ErrorHandlingService
    
    // Zoom levels for quick access
    private let zoomLevels: [Double] = [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 5.0]
    private let fitToWindowZoom: Double = -1.0 // Special value for fit-to-window
    
    // MARK: - Initialization
    init(imageLoaderService: ImageLoaderService = DefaultImageLoaderService(),
         preferencesService: PreferencesService = DefaultPreferencesService(),
         errorHandlingService: ErrorHandlingService = ErrorHandlingService.shared) {
        self.imageLoaderService = imageLoaderService
        self.preferencesService = preferencesService
        self.errorHandlingService = errorHandlingService
        
        // Load preferences
        self.showFileName = preferencesService.showFileName
        
        // Set up preferences binding
        setupPreferencesBinding()
        
        // Set up memory warning handling
        setupMemoryWarningHandling()
    }
    
    // MARK: - Public Methods
    
    /// Load images from folder content
    /// - Parameter folderContent: The folder content containing image files
    func loadFolderContent(_ folderContent: FolderContent) {
        self.folderContent = folderContent
        self.imageFiles = folderContent.imageFiles
        self.totalImages = folderContent.totalImages
        self.currentIndex = folderContent.currentIndex
        
        // Load the current image
        if folderContent.hasImages {
            loadCurrentImage()
        } else {
            currentImage = nil
            errorMessage = "No images found in the selected folder"
        }
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to the next image
    func nextImage() {
        guard hasNext else { return }
        
        let newIndex = currentIndex + 1
        navigateToIndex(newIndex)
    }
    
    /// Navigate to the previous image
    func previousImage() {
        guard hasPrevious else { return }
        
        let newIndex = currentIndex - 1
        navigateToIndex(newIndex)
    }
    
    /// Navigate to the first image
    func goToFirst() {
        guard totalImages > 0 else { return }
        navigateToIndex(0)
    }
    
    /// Navigate to the last image
    func goToLast() {
        guard totalImages > 0 else { return }
        navigateToIndex(totalImages - 1)
    }
    
    /// Navigate to a specific image index
    /// - Parameter index: The target image index
    func navigateToIndex(_ index: Int) {
        guard index >= 0 && index < totalImages else { return }
        
        currentIndex = index
        loadCurrentImage()
        
        // Preload adjacent images for better performance
        preloadAdjacentImages()
    }
    
    // MARK: - Zoom Methods
    
    /// Set the zoom level
    /// - Parameter level: The zoom level (1.0 = 100%, -1.0 = fit to window)
    func setZoom(_ level: Double) {
        zoomLevel = level
    }
    
    /// Zoom in to the next level
    func zoomIn() {
        if zoomLevel == fitToWindowZoom {
            // If currently fit-to-window, go to 100%
            zoomLevel = 1.0
        } else {
            // Find next higher zoom level
            let nextLevel = zoomLevels.first { $0 > zoomLevel } ?? zoomLevels.last ?? 5.0
            zoomLevel = nextLevel
        }
    }
    
    /// Zoom out to the previous level
    func zoomOut() {
        if zoomLevel == fitToWindowZoom {
            // Already at minimum, do nothing
            return
        } else if zoomLevel <= zoomLevels.first ?? 0.1 {
            // Go to fit-to-window
            zoomLevel = fitToWindowZoom
        } else {
            // Find next lower zoom level
            let previousLevel = zoomLevels.last { $0 < zoomLevel } ?? zoomLevels.first ?? 0.1
            zoomLevel = previousLevel
        }
    }
    
    /// Reset zoom to fit window
    func zoomToFit() {
        zoomLevel = fitToWindowZoom
    }
    
    /// Set zoom to actual size (100%)
    func zoomToActualSize() {
        zoomLevel = 1.0
    }
    
    /// Check if current zoom is fit-to-window
    var isZoomFitToWindow: Bool {
        return zoomLevel == fitToWindowZoom
    }
    
    /// Get formatted zoom percentage for display
    var zoomPercentageText: String {
        if zoomLevel == fitToWindowZoom {
            return "Fit"
        } else {
            return "\(Int(zoomLevel * 100))%"
        }
    }
    
    // MARK: - Fullscreen Methods
    
    /// Toggle fullscreen mode
    func toggleFullscreen() {
        isFullscreen.toggle()
    }
    
    /// Enter fullscreen mode
    func enterFullscreen() {
        isFullscreen = true
    }
    
    /// Exit fullscreen mode
    func exitFullscreen() {
        isFullscreen = false
    }
    
    // MARK: - File Name Display
    
    /// Toggle file name display
    func toggleFileNameDisplay() {
        showFileName.toggle()
        preferencesService.showFileName = showFileName
        preferencesService.savePreferences()
    }
    
    // MARK: - Error Handling
    
    /// Clear the current error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Loading State Management
    
    /// Cancel current loading operation
    func cancelLoading() {
        if let currentImageFile = currentImageFile {
            imageLoaderService.cancelLoading(for: currentImageFile.url)
        }
        isLoading = false
        loadingProgress = 0.0
    }
    
    // MARK: - Private Methods
    
    private func setupPreferencesBinding() {
        // Update preferences when showFileName changes
        $showFileName
            .dropFirst() // Skip initial value
            .sink { [weak self] newValue in
                self?.preferencesService.showFileName = newValue
                self?.preferencesService.savePreferences()
            }
            .store(in: &cancellables)
    }
    
    private func setupMemoryWarningHandling() {
        NotificationCenter.default
            .publisher(for: .memoryWarning)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        // Clear the image loader cache
        imageLoaderService.clearCache()
        
        // Show warning to user
        errorMessage = "Memory Warning. Not enough memory to load image"
        
        // Auto-clear the warning after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if self?.errorMessage == "Memory Warning. Not enough memory to load image" {
                self?.errorMessage = nil
            }
        }
    }
    
    private func loadCurrentImage() {
        guard let imageFile = currentImageFile else {
            currentImage = nil
            return
        }
        
        // Clear any previous error
        errorMessage = nil
        
        // Set loading state
        isLoading = true
        loadingProgress = 0.0
        
        // Cancel any previous loading
        imageLoaderService.cancelLoading(for: imageFile.url)
        
        // Load the image
        imageLoaderService.loadImage(from: imageFile.url)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.loadingProgress = 0.0
                    
                    if case .failure(let error) = completion {
                        self?.handleImageLoadingError(error, for: imageFile)
                    }
                },
                receiveValue: { [weak self] image in
                    self?.currentImage = image
                    self?.isLoading = false
                    self?.loadingProgress = 1.0
                    
                    // Reset zoom to fit when loading new image
                    self?.zoomToFit()
                }
            )
            .store(in: &cancellables)
    }
    
    private func preloadAdjacentImages() {
        var urlsToPreload: [URL] = []
        
        // Add next image
        if hasNext, let nextImageFile = imageFiles[safe: currentIndex + 1] {
            urlsToPreload.append(nextImageFile.url)
        }
        
        // Add previous image
        if hasPrevious, let previousImageFile = imageFiles[safe: currentIndex - 1] {
            urlsToPreload.append(previousImageFile.url)
        }
        
        // Only preload adjacent images to save memory
        // Preload images with reduced count for memory efficiency
        imageLoaderService.preloadImages(urlsToPreload, maxCount: 2)
    }
    
    private func handleImageLoadingError(_ error: Error, for imageFile: ImageFile) {
        if let imageLoaderError = error as? ImageLoaderError {
            // Use the error handling service for consistent error handling
            errorHandlingService.handleImageLoaderError(imageLoaderError, imageURL: imageFile.url)
            
            // For corrupted or unsupported images, try to skip to next image automatically
            if imageLoaderError == .corruptedImage || imageLoaderError == .unsupportedFormat {
                skipToNextValidImage()
            }
        } else {
            // Handle generic errors
            errorMessage = "Failed to load image: \(imageFile.displayName)"
            
            // Auto-clear error after 3 seconds
            let currentErrorMessage = errorMessage
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                if self?.errorMessage == currentErrorMessage {
                    self?.errorMessage = nil
                }
            }
        }
    }
    
    /// Skip to the next valid image when current image fails to load
    private func skipToNextValidImage() {
        // Try to find the next valid image
        var nextIndex = currentIndex + 1
        var attempts = 0
        let maxAttempts = min(5, totalImages) // Limit attempts to avoid infinite loops
        
        while nextIndex < totalImages && attempts < maxAttempts {
            let nextImageFile = imageFiles[nextIndex]
            
            // Quick check if the file exists and is readable
            if FileManager.default.fileExists(atPath: nextImageFile.url.path) {
                // Try to load this image
                navigateToIndex(nextIndex)
                return
            }
            
            nextIndex += 1
            attempts += 1
        }
        
        // If no valid next image found, try previous images
        nextIndex = currentIndex - 1
        attempts = 0
        
        while nextIndex >= 0 && attempts < maxAttempts {
            let previousImageFile = imageFiles[nextIndex]
            
            if FileManager.default.fileExists(atPath: previousImageFile.url.path) {
                navigateToIndex(nextIndex)
                return
            }
            
            nextIndex -= 1
            attempts += 1
        }
        
        // If no valid images found, show error
        errorMessage = "No valid images found in the current folder"
        errorHandlingService.showNotification(
            "All images in the current folder appear to be corrupted or inaccessible",
            type: .error
        )
    }
    
    /// Clear all content and prepare for navigation back to folder selection
    func clearContent() {
        currentImage = nil
        imageFiles = []
        folderContent = nil
        currentIndex = 0
        totalImages = 0
        isLoading = false
        loadingProgress = 0.0
        errorMessage = nil
        zoomLevel = 1.0
        isFullscreen = false
    }
    
    /// Navigate back to folder selection
    func navigateToFolderSelection() {
        shouldNavigateToFolderSelection = true
    }
    
    // MARK: - Share Methods
    
    /// Share the current image using the system share sheet
    /// - Parameter sourceView: The view to present the share sheet from (for positioning)
    func shareCurrentImage(from sourceView: NSView? = nil) {
        guard let currentImageFile = currentImageFile else {
            errorHandlingService.showNotification("No image to share", type: .warning)
            return
        }
        
        // Create sharing service picker
        let sharingServicePicker = NSSharingServicePicker(items: [currentImageFile.url])
        
        // Set delegate for customization if needed
        sharingServicePicker.delegate = SharingServiceDelegate()
        
        // Show the sharing picker
        if let sourceView = sourceView {
            sharingServicePicker.show(relativeTo: sourceView.bounds, of: sourceView, preferredEdge: .minY)
        } else {
            // Fallback: try to find the main window and show from center
            if let window = NSApplication.shared.mainWindow {
                let centerRect = NSRect(
                    x: window.frame.width / 2 - 50,
                    y: window.frame.height / 2 - 25,
                    width: 100,
                    height: 50
                )
                sharingServicePicker.show(relativeTo: centerRect, of: window.contentView!, preferredEdge: .minY)
            }
        }
    }
    
    /// Get available sharing services for the current image
    var availableSharingServices: [NSSharingService] {
        guard let currentImageFile = currentImageFile else { return [] }
        return NSSharingService.sharingServices(forItems: [currentImageFile.url])
    }
    
    /// Check if sharing is available for the current image
    var canShareCurrentImage: Bool {
        return currentImageFile != nil && !availableSharingServices.isEmpty
    }
}

// MARK: - Sharing Service Delegate
private class SharingServiceDelegate: NSObject, NSSharingServicePickerDelegate {
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
        return SharingDelegate()
    }
}

private class SharingDelegate: NSObject, NSSharingServiceDelegate {
    func sharingService(_ sharingService: NSSharingService, willShareItems items: [Any]) {
        // Optional: Log or track sharing events
        print("Sharing image via \(sharingService.title)")
    }
    
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        DispatchQueue.main.async {
            ErrorHandlingService.shared.showNotification(
                "Failed to share image: \(error.localizedDescription)",
                type: .error
            )
        }
    }
    
    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        DispatchQueue.main.async {
            ErrorHandlingService.shared.showNotification(
                "Image shared successfully",
                type: .success
            )
        }
    }
}

// MARK: - Array Safe Subscript Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}