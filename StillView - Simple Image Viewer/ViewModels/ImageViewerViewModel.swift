// swiftlint:disable file_length type_body_length line_length
import SwiftUI
import Combine
import AppKit

/// ViewModel for the main image viewer interface
@MainActor
class ImageViewerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentImage: NSImage?
    @Published var currentIndex: Int = 0
    @Published var totalImages: Int = 0
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var expectedImageSize: CGSize?
    @Published var zoomLevel: Double = 1.0
    @Published var isFullscreen: Bool = false
    @Published var errorMessage: String?
    @Published var showFileName: Bool = false
    @Published var shouldNavigateToFolderSelection: Bool = false
    @Published var isSlideshow: Bool = false
    @Published var slideshowInterval: Double = 3.0
    @Published var viewMode: ViewMode = .single

    // Inspector state (Studio redesign): one docked panel, one active tab.
    @Published var inspectorVisible: Bool = false
    @Published var inspectorTab: InspectorTab = .info

    // Grid toolbar state (Studio redesign, finding U10)
    @Published var sortOrder: ImageSortOrder = .name
    /// Minimum grid tile width in points, driven by the toolbar density slider
    @Published var gridDensity: Double = 160

    // AI Insights state
    @Published private(set) var isAIAnalysisEnabled: Bool = false
    @Published private(set) var isEnhancedProcessingEnabled: Bool = false
    @Published private(set) var isAIInsightsAvailable: Bool = false
    @Published private(set) var imageInsightAvailability: ImageInsightAvailability = .unavailable(.unknown)
    let imageInsightViewModel: ImageInsightViewModel
    
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
    
    var allImageFiles: [ImageFile] {
        return imageFiles
    }

    var currentFolderURL: URL? {
        return folderContent?.folderURL
    }

    /// Folder name shown in the toolbar breadcrumb
    var currentFolderName: String {
        return currentFolderURL?.lastPathComponent ?? "Photos"
    }

    // MARK: - Private Properties
    private var imageFiles: [ImageFile] = []
    private var folderContent: FolderContent?
    private var cancellables = Set<AnyCancellable>()
    private let imageLoaderService: ImageLoaderService
    private var preferencesService: PreferencesService
    private let errorHandlingService: ErrorHandlingService
    private var slideshowTimer: Timer?
    private let thumbnailCache = NSCache<NSURL, NSImage>()
    private let sharingDelegate = SharingServiceDelegate()
    
    // MARK: - macOS 26 Enhanced Services
    private let enhancedImageProcessing = EnhancedImageProcessingService.shared
    private let enhancedSecurity = EnhancedSecurityService.shared
    private let imageInsightService: AppleIntelligenceInsightsService
    
    // Zoom levels for quick access
    private let zoomLevels: [Double] = [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 5.0]
    private let fitToWindowZoom: Double = -1.0 // Special value for fit-to-window

    // MARK: - Initialization
    init(imageLoaderService: ImageLoaderService = DefaultImageLoaderService(),
         preferencesService: PreferencesService = DefaultPreferencesService(),
         errorHandlingService: ErrorHandlingService = ErrorHandlingService.shared,
         imageInsightService: AppleIntelligenceInsightsService = .shared) {
        self.imageLoaderService = imageLoaderService
        self.preferencesService = preferencesService
        self.errorHandlingService = errorHandlingService
        self.imageInsightService = imageInsightService
        self.imageInsightViewModel = ImageInsightViewModel(service: imageInsightService)
        self.isAIAnalysisEnabled = preferencesService.enableAIAnalysis
        self.isEnhancedProcessingEnabled = preferencesService.enableImageEnhancements
        
        // Setup thumbnail cache
        thumbnailCache.countLimit = 100
        thumbnailCache.totalCostLimit = 25 * 1024 * 1024 // 25MB
        
        // Load preferences. The "show image info" preference now means
        // "open the inspector on the Info tab at launch".
        self.showFileName = preferencesService.showFileName
        self.inspectorVisible = preferencesService.showImageInfo
        self.slideshowInterval = preferencesService.slideshowInterval

        // Initialize AI Insights availability.
        updateAIInsightsAvailability()
        
        // Set up preferences binding
        setupPreferencesBinding()
        
        // Set up memory warning handling
        setupMemoryWarningHandling()
        
        // Subscribe to AI Insights preference changes.
        NotificationCenter.default.publisher(for: .aiAnalysisPreferenceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAIAnalysisPreferenceChange(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .imageEnhancementsPreferenceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleImageEnhancementsPreferenceChange(notification)
            }
            .store(in: &cancellables)
        
        // Subscribe to app activation to re-check system compatibility
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAIInsightsAvailability()
                self?.prepareImageInsightForCurrentImage()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load images from folder content
    /// - Parameter folderContent: The folder content containing image files
    func loadFolderContent(_ folderContent: FolderContent) {
        self.folderContent = folderContent
        self.imageFiles = folderContent.imageFiles
        self.totalImages = folderContent.totalImages
        self.currentIndex = folderContent.currentIndex
        
        // Initialize AI Insights state for new folder session
        initializeAIInsightsForNewSession()

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
        expectedImageSize = nil
    }

    // MARK: - AI Insights UI Methods

    var canGenerateImageInsight: Bool {
        isAIAnalysisEnabled && imageInsightAvailability.isAvailable && currentImageFile != nil
    }
    
    /// Check if AI Insights is supported by the system (independent of user preference)
    var isAIInsightsSupported: Bool {
        imageInsightAvailability.isUserVisible
    }
    
    /// Update AI Insights availability based on system compatibility and preferences
    func updateAIInsightsAvailability() {
        imageInsightAvailability = imageInsightService.availability()
        let userEnabledAI = preferencesService.enableAIAnalysis
        isAIInsightsAvailable = imageInsightAvailability.isUserVisible && userEnabledAI
        imageInsightViewModel.updateAvailability(imageInsightAvailability)

        // Fall back to the Info tab if Insights becomes unavailable
        if !isAIInsightsAvailable {
            if inspectorTab == .insights {
                inspectorTab = .info
            }
            cancelImageInsightGeneration()
        }
        
        Logger.info("AI Insights availability updated - User: \(userEnabledAI), Available: \(isAIInsightsAvailable)", context: "AIInsights")
    }

    func generateImageInsight() {
        prepareImageInsightForCurrentImage()
        imageInsightViewModel.generate()
    }

    func cancelImageInsightGeneration() {
        imageInsightViewModel.cancelGeneration()
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
        
        // Update preferences when slideshowInterval changes
        $slideshowInterval
            .dropFirst() // Skip initial value
            .sink { [weak self] newValue in
                self?.preferencesService.slideshowInterval = newValue
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

    /// Handle AI Insights preference change notification
    private func handleAIAnalysisPreferenceChange(_ notification: Notification) {
        // Extract the new preference value from the notification
        let newValue: Bool

        // Safely extract the preference value with fallback
        if let notificationValue = notification.object as? Bool {
            newValue = notificationValue
        } else {
            // Fallback to reading directly from preferences service
            newValue = preferencesService.enableAIAnalysis
            Logger.warning("Preference notification missing value, using fallback", context: "AIInsights")
        }

        // Update the local state
        updateAIAnalysisEnabled(newValue)

        // If AI Insights is disabled, ensure panel state persistence is also reset.
        if !newValue {
            Logger.info("AI Insights disabled - panel state will be reset", context: "AIInsights")
        }
    }
    
    /// Handle automatic image enhancement preference change
    private func handleImageEnhancementsPreferenceChange(_ notification: Notification) {
        let newValue: Bool

        if let notificationValue = notification.object as? Bool {
            newValue = notificationValue
        } else {
            newValue = preferencesService.enableImageEnhancements
            Logger.warning("Enhancement preference notification missing value, using fallback", context: "ImageEnhancements")
        }

        guard isEnhancedProcessingEnabled != newValue else { return }

        isEnhancedProcessingEnabled = newValue

        guard currentImageFile != nil else { return }
        loadCurrentImage()
    }
    
    /// Update the AI Insights enabled state and synchronize UI.
    private func updateAIAnalysisEnabled(_ enabled: Bool) {
        guard isAIAnalysisEnabled != enabled else { return }
        
        isAIAnalysisEnabled = enabled

        // Update AI Insights availability based on new preference; it already
        // falls back to the Info tab and cancels generation when disabled.
        updateAIInsightsAvailability()

        if enabled {
            prepareImageInsightForCurrentImage()
        }
    }
    
    /// Initialize AI Insights state for a new folder session
    private func initializeAIInsightsForNewSession() {
        // Update availability for the new session
        updateAIInsightsAvailability()

        // Leave the Insights tab only if the user doesn't want it remembered;
        // WindowStateManager restores the proper state when persistence is on.
        if !preferencesService.rememberAIInsightsPanelState {
            if inspectorTab == .insights {
                inspectorTab = .info
            }
            Logger.info("AI Insights tab reset for new session (persistence disabled)")
        } else {
            Logger.info("Inspector state will be restored from saved session if available")
        }
    }

    /// Reset AI Insights state when ending a session
    private func resetAIInsightsForSessionEnd() {
        cancelImageInsightGeneration()
        Logger.info("AI Insights state reset for session end")
    }

    private func prepareImageInsightForCurrentImage() {
        updateAIInsightsAvailability()
        guard isAIAnalysisEnabled else {
            imageInsightViewModel.updateAvailability(.unavailable(.unknown))
            return
        }

        guard let imageFile = currentImageFile else {
            imageInsightViewModel.prepareForImage(nil, availability: .unavailable(.imageUnavailable))
            return
        }

        let input = imageInsightService.makeInput(for: imageFile)
        imageInsightViewModel.prepareForImage(input, availability: imageInsightAvailability)
    }

    private func loadCurrentImage() {
        cancelImageInsightGeneration()
        guard let imageFile = currentImageFile else {
            currentImage = nil
            expectedImageSize = nil
            imageInsightViewModel.prepareForImage(nil, availability: .unavailable(.imageUnavailable))
            return
        }
        
        // Clear any previous error and state
        errorMessage = nil
        expectedImageSize = nil
        prepareImageInsightForCurrentImage()

        // Set loading state
        isLoading = true
        loadingProgress = 0.0
        
        // Cancel any previous loading
        imageLoaderService.cancelLoading(for: imageFile.url)
        
        // Try to get expected image size from metadata for better skeleton loading
        loadExpectedImageSize(for: imageFile)
        
        // Load the image with enhanced processing if available
        loadImageWithEnhancements(imageFile)
    }
    
    /// Load image with macOS 26 enhancements
    private func loadImageWithEnhancements(_ imageFile: ImageFile) {
        // Use enhanced image processing only when available and enabled by the user
        if isEnhancedProcessingEnabled {
            loadImageWithEnhancedProcessing(imageFile)
        } else {
            loadImageStandard(imageFile)
        }
    }
    
    /// Load image with enhanced processing
    private func loadImageWithEnhancedProcessing(_ imageFile: ImageFile) {
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
                    self?.processImageWithEnhancements(image, for: imageFile)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Load image with standard processing
    private func loadImageStandard(_ imageFile: ImageFile) {
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
                    guard let self else { return }
                    self.currentImage = image
                    self.isLoading = false
                    self.loadingProgress = 1.0
                    
                    // Reset zoom to fit when loading new image
                    self.zoomToFit()
                }
            )
            .store(in: &cancellables)
    }
    
    /// Process image with macOS 26 enhancements
    private func processImageWithEnhancements(_ image: NSImage, for imageFile: ImageFile) {
        Task {
            do {
                // Apply enhanced processing features
                let features: Set<ProcessingFeature> = [
                    .smartCropping,
                    .colorEnhancement,
                    .noiseReduction
                ]
                
                let processedImage = try await enhancedImageProcessing.processImageAsync(
                    image,
                    with: features
                )
                
                if !self.isEnhancedProcessingEnabled {
                    await MainActor.run {
                        self.currentImage = image
                        self.isLoading = false
                        self.loadingProgress = 1.0
                        self.zoomToFit()
                    }
                    return
                }

                await MainActor.run {
                    self.currentImage = processedImage.currentImage
                    self.isLoading = false
                    self.loadingProgress = 1.0
                    
                    // Reset zoom to fit when loading new image
                    self.zoomToFit()
                }
            } catch {
                await MainActor.run {
                    // Fallback to standard image if processing fails
                    self.currentImage = image
                    self.isLoading = false
                    self.loadingProgress = 1.0
                    self.zoomToFit()
                }
            }
        }
    }
    
    private func loadExpectedImageSize(for imageFile: ImageFile) {
        // Try to get image dimensions from metadata without loading the full image
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let imageSource = CGImageSourceCreateWithURL(imageFile.url as CFURL, nil),
                  CGImageSourceGetCount(imageSource) > 0 else {
                return
            }
            
            // Get image properties
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
               let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
               let height = properties[kCGImagePropertyPixelHeight] as? NSNumber {
                
                let imageSize = CGSize(width: width.doubleValue, height: height.doubleValue)
                
                DispatchQueue.main.async {
                    self?.expectedImageSize = imageSize
                }
            }
        }
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
        // Stop slideshow if running
        stopSlideshow()
        
        // Cancel any ongoing loading
        if let currentImageFile = currentImageFile {
            imageLoaderService.cancelLoading(for: currentImageFile.url)
        }
        
        // Clear the image cache to free memory
        imageLoaderService.clearCache()

        currentImage = nil
        expectedImageSize = nil
        imageFiles = []
        folderContent = nil
        currentIndex = 0
        totalImages = 0
        isLoading = false
        loadingProgress = 0.0
        errorMessage = nil
        zoomLevel = 1.0
        isFullscreen = false
        viewMode = .single
        inspectorVisible = false
        inspectorTab = .info
        
        // Reset AI Insights state
        resetAIInsightsForSessionEnd()
        
        // Clear thumbnail cache
        thumbnailCache.removeAllObjects()
    }
    
    /// Navigate back to folder selection
    func navigateToFolderSelection() {
        shouldNavigateToFolderSelection = true
    }
    
    // MARK: - Slideshow Methods
    
    /// Start the slideshow
    func startSlideshow() {
        guard totalImages > 1 else {
            errorHandlingService.showNotification("Need at least 2 images for slideshow", type: .warning)
            return
        }
        
        isSlideshow = true
        startSlideshowTimer()
    }
    
    /// Stop the slideshow
    func stopSlideshow() {
        isSlideshow = false
        stopSlideshowTimer()
    }
    
    /// Toggle slideshow on/off
    func toggleSlideshow() {
        if isSlideshow {
            stopSlideshow()
        } else {
            startSlideshow()
        }
    }
    
    /// Set slideshow interval
    /// - Parameter interval: Time in seconds between slides
    func setSlideshowInterval(_ interval: Double) {
        slideshowInterval = max(1.0, min(30.0, interval)) // Clamp between 1-30 seconds
        
        // Restart timer if slideshow is active
        if isSlideshow {
            stopSlideshowTimer()
            startSlideshowTimer()
        }
    }
    
    private func startSlideshowTimer() {
        slideshowTimer?.invalidate()
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: slideshowInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.advanceSlideshow()
            }
        }
    }
    
    private func stopSlideshowTimer() {
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }
    
    private func advanceSlideshow() {
        if hasNext {
            nextImage()
        } else {
            // Loop back to first image
            goToFirst()
        }
    }
    
    // MARK: - View Mode Methods

    /// Toggle between single and grid view (G key)
    func toggleGridView() {
        viewMode = viewMode.togglingGrid()
    }

    /// Toggle between single and strip view (T key)
    func toggleThumbnailStrip() {
        viewMode = viewMode.togglingStrip()
    }

    /// Set specific view mode
    /// - Parameter mode: The view mode to set
    func setViewMode(_ mode: ViewMode) {
        viewMode = mode
    }

    /// Re-sort the image list, keeping the currently displayed file selected.
    /// - Parameter order: The sort order chosen in the grid toolbar
    func applySortOrder(_ order: ImageSortOrder) {
        sortOrder = order
        guard !imageFiles.isEmpty else { return }

        let currentURL = currentImageFile?.url
        imageFiles.sort { order.areInIncreasingOrder($0, $1) }

        if let currentURL,
           let newIndex = imageFiles.firstIndex(where: { $0.url == currentURL }) {
            currentIndex = newIndex
        }
    }

    /// Jump to specific image from thumbnail selection.
    /// In grid mode this only moves the selection (the inspector follows);
    /// opening the image in Single is an explicit action (double-click/Return).
    /// - Parameter index: The index of the image to jump to
    func jumpToImage(at index: Int) {
        guard index >= 0 && index < totalImages else { return }

        currentIndex = index

        // Load the image
        loadCurrentImage()
    }

    // MARK: - Inspector Methods

    /// I key / sidebar button: toggle the inspector (keeps the current tab).
    func toggleInspector() {
        inspectorVisible.toggle()
        syncInsightLifecycleWithInspector()
    }

    /// Cmd+I / Insights entry points: open the inspector on a specific tab.
    /// - Parameter tab: The tab to show
    func showInspector(tab: InspectorTab) {
        inspectorTab = tab
        inspectorVisible = true
        syncInsightLifecycleWithInspector()
    }

    /// Select a tab in the already-visible inspector (tab bar clicks).
    /// - Parameter tab: The tab to select
    func selectInspectorTab(_ tab: InspectorTab) {
        inspectorTab = tab
        syncInsightLifecycleWithInspector()
    }

    /// Prepare insight input while the Insights tab is visible; cancel any
    /// in-flight generation the moment it no longer is (panel closed or the
    /// user switched to Info).
    private func syncInsightLifecycleWithInspector() {
        if inspectorVisible && inspectorTab == .insights {
            prepareImageInsightForCurrentImage()
        } else {
            cancelImageInsightGeneration()
        }
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
        sharingServicePicker.delegate = sharingDelegate
        
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
    
    /// Check if sharing is available for the current image. Service
    /// enumeration is deprecated with no replacement; the sharing picker
    /// itself presents whatever services exist for the file.
    var canShareCurrentImage: Bool {
        return currentImageFile != nil
    }
    
    // MARK: - Delete Methods
    
    /// Move the current image to trash with confirmation
    @MainActor
    func moveCurrentImageToTrash() async {
        guard let currentImageFile = currentImageFile else {
            errorHandlingService.showNotification("No image to delete", type: .warning)
            return
        }
        
        // Show confirmation dialog
        let confirmed = await showDeleteConfirmation(for: currentImageFile)
        guard confirmed else { return }
        
        // Ensure security-scoped access before attempting delete
        let fileURL = currentImageFile.url
        let parentURL = fileURL.deletingLastPathComponent()
        
        // Start security-scoped access for the parent directory
        let hasAccess = parentURL.startAccessingSecurityScopedResource()
        
        defer {
            if hasAccess {
                parentURL.stopAccessingSecurityScopedResource()
            }
        }
        
        guard hasAccess else {
            errorHandlingService.showNotification(
                "Permission denied. Please re-select the folder to grant delete permissions.",
                type: .error
            )
            return
        }
        
        // Move to trash using NSWorkspace
        NSWorkspace.shared.recycle([fileURL], completionHandler: { (trashedItems, error) in
            DispatchQueue.main.async {
                if let error = error {
                    // Check for specific permission errors
                    if error.localizedDescription.contains("permission") || 
                       error.localizedDescription.contains("Operation not permitted") {
                        self.errorHandlingService.showNotification(
                            "Permission denied. The app needs write access to this folder. Please re-select the folder.",
                            type: .error
                        )
                    } else {
                        self.errorHandlingService.showNotification(
                            "Failed to move image to trash: \(error.localizedDescription)",
                            type: .error
                        )
                    }
                } else {
                    // Successfully moved to trash
                    self.handleImageDeletion()
                    self.errorHandlingService.showNotification(
                        "Image moved to Trash",
                        type: .success
                    )
                }
            }
        })
    }
    
    /// Show confirmation dialog for deleting an image
    @MainActor
    private func showDeleteConfirmation(for imageFile: ImageFile) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Move to Trash"
                alert.informativeText = "Are you sure you want to move \"\(imageFile.displayName)\" to the Trash? This action can be undone from the Trash."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Move to Trash")
                alert.addButton(withTitle: "Cancel")
                
                // Set the trash button as the default (pressing Enter)
                if let trashButton = alert.buttons.first {
                    trashButton.keyEquivalent = "\r" // Enter key
                }
                
                // Set cancel button shortcut
                if alert.buttons.count > 1 {
                    alert.buttons[1].keyEquivalent = "\u{1b}" // Escape key
                }
                
                // Run the alert
                let response = alert.runModal()
                continuation.resume(returning: response == .alertFirstButtonReturn)
            }
        }
    }
    
    /// Handle the image deletion by updating the image list and navigation
    private func handleImageDeletion() {
        let deletedIndex = currentIndex
        
        // Remove the image from our array
        imageFiles.remove(at: deletedIndex)
        totalImages = imageFiles.count
        
        // Handle navigation after deletion
        if totalImages == 0 {
            // No more images, go back to folder selection
            shouldNavigateToFolderSelection = true
            return
        }
        
        // Adjust current index if necessary
        if currentIndex >= totalImages {
            currentIndex = totalImages - 1
        }
        
        // Load the new current image
        loadCurrentImage()
    }
    
    /// Check if deletion is available for the current image
    var canDeleteCurrentImage: Bool {
        return currentImageFile != nil
    }
}

// MARK: - Sharing Service Delegate
private class SharingServiceDelegate: NSObject, NSSharingServicePickerDelegate {
    private let sharingDelegate = SharingDelegate()
    
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? {
        return sharingDelegate
    }
}

private class SharingDelegate: NSObject, NSSharingServiceDelegate {
    func sharingService(_ sharingService: NSSharingService, willShareItems items: [Any]) {
        // Optional: Log or track sharing events
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

// MARK: - Sort Comparators

extension ImageSortOrder {
    /// Comparator over ImageFile. "Date Captured" uses the file creation date —
    /// scanning EXIF for a whole folder just to sort would be too costly.
    func areInIncreasingOrder(_ lhs: ImageFile, _ rhs: ImageFile) -> Bool {
        switch self {
        case .name:
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        case .dateCaptured:
            return lhs.creationDate < rhs.creationDate
        case .dateModified:
            return lhs.modificationDate < rhs.modificationDate
        case .size:
            return lhs.size > rhs.size
        }
    }
}

// MARK: - Array Safe Subscript Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
