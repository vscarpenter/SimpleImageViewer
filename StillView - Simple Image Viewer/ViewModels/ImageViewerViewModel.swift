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
    /// Published source of truth for filmstrip and grid content.
    @Published private(set) var allImageFiles: [ImageFile] = []

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
        guard !allImageFiles.isEmpty && currentIndex >= 0 && currentIndex < allImageFiles.count else {
            return nil
        }
        return allImageFiles[currentIndex]
    }
    
    var imageCounterText: String {
        guard totalImages > 0 else { return "No images" }
        return "\(currentIndex + 1) of \(totalImages)"
    }
    
    var currentFileName: String {
        return currentImageFile?.displayName ?? ""
    }
    
    var currentFolderURL: URL? {
        return folderContent?.folderURL
    }

    /// Folder name shown in the toolbar breadcrumb
    var currentFolderName: String {
        return currentFolderURL?.lastPathComponent ?? "Photos"
    }

    // MARK: - Private Properties
    private var folderContent: FolderContent?
    private var cancellables = Set<AnyCancellable>()
    private var currentImageLoad: AnyCancellable?
    private var activeImageLoadID: UUID?
    private var activeImageLoadURL: URL?
    private var enhancementTask: Task<Void, Never>?
    private var expectedImageSizeTask: Task<Void, Never>?
    private var failedImageURLs: Set<URL> = []
    private let imageLoaderService: ImageLoaderService
    private let imageEnhancer: (NSImage) async throws -> NSImage
    private let expectedImageSizeLoader: (URL) async -> CGSize?
    private var preferencesService: PreferencesService
    private let errorHandlingService: ErrorHandlingService
    private var slideshowTimer: Timer?
    private let thumbnailCache = NSCache<NSURL, NSImage>()
    private let sharingDelegate = SharingServiceDelegate()
    
    // MARK: - macOS 26 Enhanced Services
    private let enhancedSecurity = EnhancedSecurityService.shared
    private let insightAvailabilityProvider: () -> ImageInsightAvailability
    private let insightInputProvider: (ImageFile) -> ImageInsightInput
    private var systemInsightAvailability: ImageInsightAvailability = .unavailable(.unknown)
    private var currentImageRevision: ImageRevision?

    private struct ImageRevision: Equatable {
        let url: URL
        let byteCount: Int64?
        let modificationDate: Date?
    }
    
    // Zoom levels for quick access
    private let zoomLevels: [Double] = [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 5.0]
    private let fitToWindowZoom: Double = -1.0 // Special value for fit-to-window
    private(set) var fitZoomLevel: Double = 1.0

    // MARK: - Initialization
    init(imageLoaderService: ImageLoaderService = DefaultImageLoaderService(),
         preferencesService: PreferencesService = DefaultPreferencesService(),
         errorHandlingService: ErrorHandlingService = ErrorHandlingService.shared,
         imageInsightService: any ImageInsightGenerating = AppleIntelligenceInsightsService.shared,
         imageEnhancer: ((NSImage) async throws -> NSImage)? = nil,
         expectedImageSizeLoader: ((URL) async -> CGSize?)? = nil,
         insightAvailabilityProvider: (() -> ImageInsightAvailability)? = nil,
         insightInputProvider: ((ImageFile) -> ImageInsightInput)? = nil) {
        self.imageLoaderService = imageLoaderService
        self.imageEnhancer = imageEnhancer ?? { image in
            let features: Set<ProcessingFeature> = [.smartCropping, .colorEnhancement, .noiseReduction]
            return try await EnhancedImageProcessingService.shared.processImageAsync(image, with: features).currentImage
        }
        self.expectedImageSizeLoader = expectedImageSizeLoader ?? { url in
            let task = Task.detached(priority: .utility) {
                guard !Task.isCancelled else { return nil as CGSize? }
                return Self.readExpectedImageSize(at: url)
            }
            return await withTaskCancellationHandler {
                await task.value
            } onCancel: {
                task.cancel()
            }
        }
        self.preferencesService = preferencesService
        self.errorHandlingService = errorHandlingService
        self.insightAvailabilityProvider = insightAvailabilityProvider ?? AppleIntelligenceInsightsService.shared.availability
        self.insightInputProvider = insightInputProvider ?? AppleIntelligenceInsightsService.shared.makeInput
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
        cancelLoading()
        failedImageURLs.removeAll()
        self.folderContent = folderContent
        self.allImageFiles = folderContent.imageFiles
        self.totalImages = folderContent.totalImages
        self.currentIndex = folderContent.currentIndex
        
        // Initialize AI Insights state for new folder session
        initializeAIInsightsForNewSession()

        // Load the current image
        if folderContent.hasImages {
            loadCurrentImage()
        } else {
            currentImage = nil
            prepareImageInsightForCurrentImage()
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
        guard level.isFinite else { return }
        zoomLevel = level == fitToWindowZoom ? level : min(max(level, 0.01), max(5, fitZoomLevel))
    }

    /// The view supplies the pixel scale needed to fit its current drawable area.
    func updateFitZoomLevel(_ level: Double) {
        guard level.isFinite, level > 0 else { return }
        fitZoomLevel = level
    }
    
    /// Zoom in to the next level
    func zoomIn() {
        let currentLevel = isZoomFitToWindow ? fitZoomLevel : zoomLevel
        zoomLevel = zoomLevels.first { $0 > currentLevel } ?? max(currentLevel, 5)
    }
    
    /// Zoom out to the previous level
    func zoomOut() {
        let currentLevel = isZoomFitToWindow ? fitZoomLevel : zoomLevel
        zoomLevel = zoomLevels.last { $0 < currentLevel } ?? max(0.01, currentLevel / 2)
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

    /// The window fullscreen commands drive. The studio window has no
    /// dedicated fullscreen control, so the key/main window is the target.
    private var fullscreenWindow: NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow
    }

    /// Toggle fullscreen mode
    func toggleFullscreen() {
        guard let window = fullscreenWindow else { return }
        let entering = !window.styleMask.contains(.fullScreen)
        window.toggleFullScreen(nil)
        isFullscreen = entering
    }

    /// Enter fullscreen mode
    func enterFullscreen() {
        guard let window = fullscreenWindow else { return }
        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        isFullscreen = true
    }

    /// Exit fullscreen mode
    func exitFullscreen() {
        guard let window = fullscreenWindow else { return }
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
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
        cancelActiveImageLoad()
        isLoading = false
        loadingProgress = 0.0
        expectedImageSize = nil
    }

    /// An explicit retry starts a new recovery attempt for the current selection.
    func retryCurrentImage() {
        loadCurrentImage()
    }

    /// Identifies the selection/load that metadata belongs to, including same-URL reloads.
    var currentImageRequestID: UUID? { activeImageLoadID }

    // MARK: - AI Insights UI Methods

    var canGenerateImageInsight: Bool {
        isAIAnalysisEnabled && imageInsightAvailability.isAvailable && currentImageFile != nil
    }
    
    /// Check if AI Insights is supported by the system (independent of user preference)
    var isAIInsightsSupported: Bool {
        systemInsightAvailability.isUserVisible
    }
    
    /// Update AI Insights availability based on system compatibility and preferences
    func updateAIInsightsAvailability() {
        systemInsightAvailability = insightAvailabilityProvider()
        isAIAnalysisEnabled = preferencesService.enableAIAnalysis
        imageInsightAvailability = isAIAnalysisEnabled ? systemInsightAvailability : .unavailable(.appDisabled)
        isAIInsightsAvailable = imageInsightAvailability.isAvailable
        imageInsightViewModel.updateAvailability(imageInsightAvailability)
    }

    func enableAIInsights() {
        preferencesService.enableAIAnalysis = true
        preferencesService.savePreferences()
        prepareImageInsightForCurrentImage()
    }

    func generateImageInsight() {
        prepareImageInsightForCurrentImage()
        guard canGenerateImageInsight else { return }
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
        // Read the owning preference store; unrelated windows may use a different store.
        prepareImageInsightForCurrentImage()
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
        currentImageRevision = nil
        imageInsightViewModel.prepareForImage(nil, availability: imageInsightAvailability)
        Logger.info("AI Insights state reset for session end")
    }

    private func prepareImageInsightForCurrentImage(reloadIfChanged: Bool = true) {
        updateAIInsightsAvailability()
        guard let imageFile = currentImageFile else {
            currentImageRevision = nil
            imageInsightViewModel.prepareForImage(nil, availability: imageInsightAvailability)
            return
        }

        let input = insightInputProvider(imageFile)
        let revision = ImageRevision(url: imageFile.url, byteCount: input.fileByteCount,
                                     modificationDate: input.fileModificationDate)
        if reloadIfChanged, let previousRevision = currentImageRevision,
           previousRevision.url == revision.url, previousRevision != revision {
            // The stage and Insights must refer to the same file revision after an external edit.
            loadCurrentImage()
            return
        }
        currentImageRevision = revision
        imageInsightViewModel.prepareForImage(input, availability: imageInsightAvailability)
    }

    private func cancelActiveImageLoad() {
        // Invalidate first: cancellation alone cannot suppress work already queued for publication.
        activeImageLoadID = nil
        currentImageLoad?.cancel()
        currentImageLoad = nil
        enhancementTask?.cancel()
        enhancementTask = nil
        expectedImageSizeTask?.cancel()
        expectedImageSizeTask = nil
        if let url = activeImageLoadURL {
            imageLoaderService.cancelLoading(for: url)
        }
        activeImageLoadURL = nil
    }

    private func isCurrentImageLoad(_ loadID: UUID, for imageFile: ImageFile) -> Bool {
        activeImageLoadID == loadID && currentImageFile?.url == imageFile.url
    }

    private func loadCurrentImage(resetRecovery: Bool = true) {
        cancelActiveImageLoad()
        if resetRecovery {
            failedImageURLs.removeAll()
        }
        currentImage = nil
        expectedImageSize = nil
        isLoading = false
        loadingProgress = 0
        guard let imageFile = currentImageFile else {
            currentImageRevision = nil
            imageInsightViewModel.prepareForImage(nil, availability: imageInsightAvailability)
            return
        }

        let loadID = UUID()
        activeImageLoadID = loadID
        activeImageLoadURL = imageFile.url
        errorMessage = nil
        prepareImageInsightForCurrentImage(reloadIfChanged: false)
        isLoading = true
        loadExpectedImageSize(for: imageFile, loadID: loadID)

        currentImageLoad = imageLoaderService.loadImage(from: imageFile.url)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, self.isCurrentImageLoad(loadID, for: imageFile) else { return }
                    self.currentImageLoad = nil
                    // A successful decode can still have an enhancement in progress.
                    if case .failure(let error) = completion {
                        self.isLoading = false
                        self.loadingProgress = 0
                        self.expectedImageSizeTask?.cancel()
                        self.expectedImageSize = nil
                        self.handleImageLoadingError(error, for: imageFile)
                    }
                },
                receiveValue: { [weak self] image in
                    guard let self, self.isCurrentImageLoad(loadID, for: imageFile) else { return }
                    if self.isEnhancedProcessingEnabled {
                        self.processImageWithEnhancements(image, for: imageFile, loadID: loadID)
                    } else {
                        self.publishImage(image, for: imageFile, loadID: loadID)
                    }
                }
            )
    }

    private func publishImage(_ image: NSImage, for imageFile: ImageFile, loadID: UUID) {
        guard isCurrentImageLoad(loadID, for: imageFile) else { return }
        currentImage = image
        isLoading = false
        loadingProgress = 1
        failedImageURLs.removeAll()
        zoomToFit()
    }

    private func processImageWithEnhancements(_ image: NSImage, for imageFile: ImageFile, loadID: UUID) {
        enhancementTask = Task { [weak self] in
            guard let self else { return }
            do {
                let processedImage = try await self.imageEnhancer(image)
                guard !Task.isCancelled, self.isCurrentImageLoad(loadID, for: imageFile) else { return }
                self.publishImage(processedImage, for: imageFile, loadID: loadID)
            } catch {
                guard !Task.isCancelled, self.isCurrentImageLoad(loadID, for: imageFile) else { return }
                // A processing failure still leaves a usable original image.
                self.publishImage(image, for: imageFile, loadID: loadID)
            }
        }
    }

    private func loadExpectedImageSize(for imageFile: ImageFile, loadID: UUID) {
        expectedImageSizeTask = Task { [weak self] in
            guard let self else { return }
            let size = await self.expectedImageSizeLoader(imageFile.url)
            guard !Task.isCancelled, self.isCurrentImageLoad(loadID, for: imageFile) else { return }
            self.expectedImageSize = size
        }
    }

    nonisolated private static func readExpectedImageSize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if (5...8).contains(orientation) {
            return CGSize(width: height.doubleValue, height: width.doubleValue)
        }
        return CGSize(width: width.doubleValue, height: height.doubleValue)
    }

    private func preloadAdjacentImages() {
        var urlsToPreload: [URL] = []
        
        // Add next image
        if hasNext, let nextImageFile = allImageFiles[safe: currentIndex + 1] {
            urlsToPreload.append(nextImageFile.url)
        }
        
        // Add previous image
        if hasPrevious, let previousImageFile = allImageFiles[safe: currentIndex - 1] {
            urlsToPreload.append(previousImageFile.url)
        }
        
        // Only preload adjacent images to save memory
        // Preload images with reduced count for memory efficiency
        imageLoaderService.preloadImages(urlsToPreload, maxCount: 2)
    }
    
    private func handleImageLoadingError(_ error: Error, for imageFile: ImageFile) {
        errorMessage = "Failed to load \(imageFile.displayName): \(error.localizedDescription)"
        guard let loaderError = error as? ImageLoaderError else { return }
        errorHandlingService.handleImageLoaderError(loaderError, imageURL: imageFile.url)
        if loaderError == .corruptedImage || loaderError == .unsupportedFormat {
            failedImageURLs.insert(imageFile.url)
            skipToNextValidImage()
        }
    }

    /// Recovery spans successive failures, so two bad files cannot keep selecting each other.
    private func skipToNextValidImage() {
        let maximumAttempts = min(5, totalImages)
        let nextIndices = Array((currentIndex + 1)..<totalImages)
        let previousIndices = Array((0..<currentIndex).reversed())
        if failedImageURLs.count < maximumAttempts,
           let nextIndex = (nextIndices + previousIndices).first(where: {
               !failedImageURLs.contains(allImageFiles[$0].url)
           }) {
            currentIndex = nextIndex
            loadCurrentImage(resetRecovery: false)
            return
        }

        stopSlideshow()
        if failedImageURLs.count >= totalImages {
            errorMessage = "No valid images found in the current folder"
        } else {
            errorMessage = "Could not open \(failedImageURLs.count) images. Select another image to try again."
        }
    }

    /// Clear all content and prepare for navigation back to folder selection
    func clearContent() {
        // Stop slideshow if running
        stopSlideshow()
        
        // Cancel decoding, enhancement, and metadata publication before clearing the selection.
        cancelLoading()
        failedImageURLs.removeAll()
        
        // Clear the image cache to free memory
        imageLoaderService.clearCache()

        currentImage = nil
        expectedImageSize = nil
        allImageFiles = []
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
        guard !allImageFiles.isEmpty else { return }

        let currentURL = currentImageFile?.url
        allImageFiles.sort { order.areInIncreasingOrder($0, $1) }

        if let currentURL,
           let newIndex = allImageFiles.firstIndex(where: { $0.url == currentURL }) {
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
        allImageFiles.remove(at: deletedIndex)
        totalImages = allImageFiles.count
        
        // Handle navigation after deletion
        if totalImages == 0 {
            // No more images, invalidate any pending work before leaving the viewer.
            loadCurrentImage()
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
