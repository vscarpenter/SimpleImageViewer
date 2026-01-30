// swiftlint:disable file_length type_body_length line_length
import SwiftUI
import Combine
import AppKit

/// View modes for the image viewer
enum ViewMode: String, CaseIterable {
    case normal = "normal"
    case thumbnailStrip = "thumbnailStrip"
    case grid = "grid"
    
    var displayName: String {
        switch self {
        case .normal:
            return "Normal View"
        case .thumbnailStrip:
            return "Thumbnail Strip"
        case .grid:
            return "Grid View"
        }
    }
    
    var icon: String {
        switch self {
        case .normal:
            return "photo"
        case .thumbnailStrip:
            return "rectangle.grid.1x2"
        case .grid:
            return "square.grid.3x3"
        }
    }
}

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
    @Published var showImageInfo: Bool = false
    @Published var isSlideshow: Bool = false
    @Published var slideshowInterval: Double = 3.0
    @Published var viewMode: ViewMode = .normal

    // AI analysis state
    @Published private(set) var currentAnalysis: ImageAnalysisResult?
    @Published private(set) var analysisTags: [String] = []
    @Published private(set) var analysisObjects: [DetectedObject] = []
    @Published private(set) var analysisScenes: [SceneClassification] = []
    @Published private(set) var analysisText: [RecognizedText] = []
    @Published private(set) var analysisError: Error?
    @Published private(set) var isAnalyzingAI: Bool = false
    @Published private(set) var aiAnalysisProgress: Double = 0.0
    @Published private(set) var isAIAnalysisEnabled: Bool = true
    @Published private(set) var isEnhancedProcessingEnabled: Bool = false
    
    // AI Insights UI state
    @Published private(set) var showAIInsights: Bool = false
    @Published private(set) var isAIInsightsAvailable: Bool = false
    @Published private(set) var aiInsights: [AIInsight] = []

    // Phase 6.3: Analysis stage tracking for UI progress display
    @Published private(set) var currentAnalysisStage: String?

    private let aiBrain = AIBrain.shared
    
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
    
    // Favorites removed
    
    // MARK: - Private Properties
    private var imageFiles: [ImageFile] = []
    private var folderContent: FolderContent?
    private var cancellables = Set<AnyCancellable>()
    private let imageLoaderService: ImageLoaderService
    private var preferencesService: PreferencesService
    private let errorHandlingService: ErrorHandlingService
    // Favorites removed
    private var slideshowTimer: Timer?
    private let thumbnailCache = NSCache<NSURL, NSImage>()
    private let sharingDelegate = SharingServiceDelegate()
    
    // MARK: - macOS 26 Enhanced Services
    private let compatibilityService = MacOS26CompatibilityService.shared
    private let enhancedImageProcessing = EnhancedImageProcessingService.shared
    private let enhancedSecurity = EnhancedSecurityService.shared
    private let aiAnalysisService = AIImageAnalysisService.shared
    
    // Zoom levels for quick access
    private let zoomLevels: [Double] = [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 5.0]
    private let fitToWindowZoom: Double = -1.0 // Special value for fit-to-window

    // AI analysis task management
    private var analysisTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(imageLoaderService: ImageLoaderService = DefaultImageLoaderService(),
         preferencesService: PreferencesService = DefaultPreferencesService(),
         errorHandlingService: ErrorHandlingService = ErrorHandlingService.shared) {
        self.imageLoaderService = imageLoaderService
        self.preferencesService = preferencesService
        self.errorHandlingService = errorHandlingService
        self.isAIAnalysisEnabled = preferencesService.enableAIAnalysis
        self.isEnhancedProcessingEnabled = preferencesService.enableImageEnhancements
        
        // Setup thumbnail cache
        thumbnailCache.countLimit = 100
        thumbnailCache.totalCostLimit = 25 * 1024 * 1024 // 25MB
        
        // Load preferences
        self.showFileName = preferencesService.showFileName
        self.showImageInfo = preferencesService.showImageInfo
        self.slideshowInterval = preferencesService.slideshowInterval
        
        // Initialize AI Insights availability and sync with preferences
        updateAIInsightsAvailability()
        syncAIInsightsWithPreferences()
        
        // Initialize AI Insights state based on preferences and system availability
        initializeAIInsightsState()
        
        // Set up preferences binding
        setupPreferencesBinding()
        
        // Set up memory warning handling
        setupMemoryWarningHandling()
        
        // Observe AI analysis service state
        aiAnalysisService.$isAnalyzing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.isAnalyzingAI = $0
            }
            .store(in: &cancellables)

        aiAnalysisService.$analysisProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.aiAnalysisProgress = $0
            }
            .store(in: &cancellables)

        // Phase 6.3: Subscribe to analysis stage changes for UI progress display
        aiAnalysisService.$currentAnalysisStage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stage in
                self?.currentAnalysisStage = stage.rawValue
            }
            .store(in: &cancellables)
        
        // Subscribe to AI analysis preference changes with error handling
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
        
        // Subscribe to notification system failures
        NotificationCenter.default.publisher(for: .notificationSystemFailure)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let error = notification.object as? Error {
                    self?.handleNotificationSystemFailure(error)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to app activation to re-check system compatibility
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAIInsightsAvailability()
            }
            .store(in: &cancellables)
        
        // Subscribe to AI Insights initialization completion
        NotificationCenter.default.publisher(for: .aiInsightsInitializationComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAIInsightsInitializationComplete()
            }
            .store(in: &cancellables)
        
        // Favorites removed
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
        
        // Favorites removed
        
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

    /// Retry AI analysis for the current image if available
    func retryAIAnalysis() {
        guard let image = currentImage else { return }
        scheduleAIAnalysisIfNeeded(image: image, file: currentImageFile)
    }

    /// Phase 6.3: Cancel the current AI analysis task
    func cancelAIAnalysis() {
        analysisTask?.cancel()
        aiAnalysisService.cancelAnalysis()
        resetAnalysisState()
    }
    
    // MARK: - AI Insights UI Methods
    
    /// Toggle the visibility of the AI Insights panel
    func toggleAIInsights() {
        guard isAIInsightsAvailable else { return }
        showAIInsights.toggle()
    }
    
    /// Restore AI Insights panel visibility state from saved session
    /// - Parameter shouldShow: Whether to show the AI Insights panel
    func restoreAIInsightsState(_ shouldShow: Bool) {
        guard isAIInsightsAvailable else { return }
        showAIInsights = shouldShow
    }
    
    /// Check if AI Insights is supported by the system (independent of user preference)
    var isAIInsightsSupported: Bool {
        if #available(macOS 26.0, *) {
            return compatibilityService.isFeatureAvailable(.aiImageAnalysis)
        }
        return false
    }
    
    /// Update AI Insights availability based on system compatibility and preferences
    func updateAIInsightsAvailability() {
        // Check system compatibility first - AI Insights requires macOS 26+
        let systemSupportsAI = isAIInsightsSupported
        
        let userEnabledAI = preferencesService.enableAIAnalysis
        isAIInsightsAvailable = systemSupportsAI && userEnabledAI
        
        // Reset showAIInsights if AI Insights becomes unavailable
        if !isAIInsightsAvailable {
            showAIInsights = false
        }
        
        Logger.info("AI Insights availability updated - System: \(systemSupportsAI), User: \(userEnabledAI), Available: \(isAIInsightsAvailable)", context: "AIInsights")
    }
    
    /// Handle notification system failures
    private func handleNotificationSystemFailure(_ error: Error) {
        Logger.error("Notification system failure detected: \(error.localizedDescription)", context: "AIInsights")
        errorHandlingService.handleNotificationSystemFailure(error)
        
        // Implement fallback mechanism for critical AI Insights notifications
        setupFallbackNotificationSystem()
    }
    
    /// Setup fallback notification system for AI Insights
    private func setupFallbackNotificationSystem() {
        Logger.info("Setting up fallback notification system for AI Insights", context: "AIInsights")
        
        // Use a timer-based polling mechanism as fallback with periodic checks
        var pollCount = 0
        let maxPolls = 12 // Poll for 1 minute (5 second intervals)
        
        let fallbackTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            pollCount += 1
            
            // Attempt to sync preferences
            self.fallbackPreferenceSync()
            
            // Stop polling after max attempts or if notification system recovers
            if pollCount >= maxPolls {
                timer.invalidate()
                Logger.info("Fallback notification system polling completed", context: "AIInsights")
            }
        }
        
        // Store timer reference to prevent deallocation
        RunLoop.main.add(fallbackTimer, forMode: .common)
        
        // Also attempt immediate recovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.fallbackPreferenceSync()
        }
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
        
        // Update preferences when showImageInfo changes
        $showImageInfo
            .dropFirst() // Skip initial value
            .sink { [weak self] newValue in
                self?.preferencesService.showImageInfo = newValue
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
    
    // Favorites removed
    
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

    @MainActor
    private func resetAnalysisState(clearError: Bool = true) {
        currentAnalysis = nil
        analysisTags = []
        analysisObjects = []
        analysisScenes = []
        analysisText = []
        aiAnalysisProgress = 0.0
        if clearError {
            analysisError = nil
        }
    }

    /// Handle AI analysis preference change notification
    private func handleAIAnalysisPreferenceChange(_ notification: Notification) {
        do {
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
            
            // If AI analysis is disabled, ensure panel state persistence is also reset
            if !newValue {
                Logger.info("AI analysis disabled - AI Insights panel state will be reset", context: "AIInsights")
            }
            
        } catch let error as AIAnalysisError {
            // Handle AI-specific preference synchronization failure
            Logger.error("AI-specific preference sync error: \(error.localizedDescription)", context: "AIInsights")
            
            switch error {
            case .preferenceSyncFailed:
                errorHandlingService.handlePreferenceSyncFailure(error) { [weak self] in
                    Task { @MainActor in
                        self?.fallbackPreferenceSync()
                    }
                }
            case .notificationSystemFailed:
                // Setup fallback notification system
                setupFallbackNotificationSystem()
            default:
                // For other AI errors, attempt fallback sync
                fallbackPreferenceSync()
            }
        } catch {
            // Handle generic preference synchronization failure
            Logger.error("Failed to handle AI analysis preference change: \(error.localizedDescription)", context: "AIInsights")
            errorHandlingService.handlePreferenceSyncFailure(error) { [weak self] in
                Task { @MainActor in
                    self?.fallbackPreferenceSync()
                }
            }
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

        guard let imageFile = currentImageFile else { return }
        loadCurrentImage()
    }
    
    /// Update the AI analysis enabled state and synchronize UI
    private func updateAIAnalysisEnabled(_ enabled: Bool) {
        guard isAIAnalysisEnabled != enabled else { return }
        
        isAIAnalysisEnabled = enabled
        
        // Update AI Insights availability based on new preference
        updateAIInsightsAvailability()
        
        if !enabled {
            // Reset showAIInsights state when AI analysis is disabled
            showAIInsights = false
            
            // Cancel any ongoing AI analysis
            analysisTask?.cancel()
            
            // Clear AI analysis state
            Task { @MainActor [weak self] in
                self?.resetAnalysisState()
            }
        } else {
            // When AI analysis is re-enabled, trigger analysis for current image if available
            if let currentImage = currentImage {
                scheduleAIAnalysisIfNeeded(image: currentImage, file: currentImageFile)
            }
        }
    }
    
    /// Synchronize AI Insights state with current preferences
    private func syncAIInsightsWithPreferences() {
        do {
            let enabled = preferencesService.enableAIAnalysis
            updateAIAnalysisEnabled(enabled)
            Logger.info("AI Insights preferences synchronized successfully", context: "AIInsights")
        } catch let error as AIAnalysisError {
            Logger.error("AI-specific preference sync error: \(error.localizedDescription)", context: "AIInsights")
            
            switch error {
            case .preferenceSyncFailed:
                errorHandlingService.handlePreferenceSyncFailure(error) { [weak self] in
                    Task { @MainActor in
                        self?.fallbackPreferenceSync()
                    }
                }
            case .systemResourcesUnavailable:
                // Set to safe default state
                isAIAnalysisEnabled = false
                updateAIInsightsAvailability()
                Logger.warning("AI system resources unavailable, disabling AI analysis", context: "AIInsights")
            default:
                // For other AI errors, attempt fallback
                fallbackPreferenceSync()
            }
        } catch {
            Logger.error("Failed to sync AI Insights with preferences: \(error.localizedDescription)", context: "AIInsights")
            errorHandlingService.handlePreferenceSyncFailure(error) { [weak self] in
                Task { @MainActor in
                    self?.fallbackPreferenceSync()
                }
            }
        }
    }
    
    /// Fallback mechanism for preference synchronization failures
    private func fallbackPreferenceSync() {
        Logger.info("Attempting fallback preference synchronization", context: "AIInsights")
        
        // Use a simple polling mechanism as fallback with exponential backoff
        var retryCount = 0
        let maxRetries = 3
        
        func attemptSync() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(1 << retryCount)) { [weak self] in
                guard let self = self else { return }
                
                do {
                    // Re-read preferences directly with error handling
                    let currentEnabled = self.preferencesService.enableAIAnalysis
                    
                    // Update state if different
                    if self.isAIAnalysisEnabled != currentEnabled {
                        self.updateAIAnalysisEnabled(currentEnabled)
                        Logger.info("Fallback preference sync successful after \(retryCount + 1) attempts", context: "AIInsights")
                        return
                    }
                    
                    let currentEnhancements = self.preferencesService.enableImageEnhancements
                    if self.isEnhancedProcessingEnabled != currentEnhancements {
                        self.isEnhancedProcessingEnabled = currentEnhancements
                        if let imageFile = self.currentImageFile {
                            self.loadCurrentImage()
                        }
                        Logger.info("Fallback enhancement sync completed", context: "ImageEnhancements")
                        return
                    }

                    Logger.info("Fallback preference sync completed - no changes needed", context: "AIInsights")
                    
                } catch let error as AIAnalysisError {
                    Logger.error("Fallback preference sync failed (attempt \(retryCount + 1)): \(error.localizedDescription)", context: "AIInsights")
                    
                    retryCount += 1
                    if retryCount < maxRetries {
                        // Retry with exponential backoff
                        attemptSync()
                    } else {
                        // Final fallback - set to safe default state
                        Logger.error("All fallback attempts failed, setting safe defaults", context: "AIInsights")
                        self.isAIAnalysisEnabled = false
                        self.updateAIInsightsAvailability()
                        
                        // Notify user of persistent issue
                        self.errorHandlingService.showNotification(
                            "AI preferences sync failed - restart app if issues persist",
                            type: .warning
                        )
                    }
                } catch {
                    Logger.error("Fallback preference sync failed (attempt \(retryCount + 1)): \(error.localizedDescription)", context: "AIInsights")
                    
                    retryCount += 1
                    if retryCount < maxRetries {
                        // Retry with exponential backoff
                        attemptSync()
                    } else {
                        // Final fallback - set to safe default state
                        Logger.error("All fallback attempts failed, setting safe defaults", context: "AIInsights")
                        self.isAIAnalysisEnabled = false
                        self.updateAIInsightsAvailability()
                        
                        // Notify user of persistent issue
                        self.errorHandlingService.showNotification(
                            "AI preferences sync failed - restart app if issues persist",
                            type: .warning
                        )
                    }
                }
            }
        }
        
        attemptSync()
    }
    
    /// Initialize AI Insights state on app launch based on preferences and system availability
    private func initializeAIInsightsState() {
        // Ensure AI Insights availability is up to date
        updateAIInsightsAvailability()
        
        // Initialize showAIInsights to false by default
        // This will be restored from saved state later if applicable
        showAIInsights = false
        
        Logger.info("AI Insights initialized - Available: \(isAIInsightsAvailable), Analysis Enabled: \(isAIAnalysisEnabled)")
    }
    
    /// Handle AI Insights initialization completion from app launch
    private func handleAIInsightsInitializationComplete() {
        // Re-check availability after full app initialization
        updateAIInsightsAvailability()
        
        // Ensure preferences are properly synchronized
        syncAIInsightsWithPreferences()
        
        Logger.info("AI Insights initialization complete - Final state: Available: \(isAIInsightsAvailable), Analysis Enabled: \(isAIAnalysisEnabled)")
    }
    
    /// Initialize AI Insights state for a new folder session
    private func initializeAIInsightsForNewSession() {
        // Update availability for the new session
        updateAIInsightsAvailability()
        
        // Reset panel visibility to false for new sessions unless restored from saved state
        // The WindowStateManager will restore the proper state if needed
        if !preferencesService.rememberAIInsightsPanelState {
            showAIInsights = false
            Logger.info("AI Insights panel reset for new session (persistence disabled)")
        } else {
            Logger.info("AI Insights panel state will be restored from saved session if available")
        }
    }
    
    /// Reset AI Insights state when ending a session
    private func resetAIInsightsForSessionEnd() {
        showAIInsights = false
        
        // Cancel any ongoing AI analysis
        analysisTask?.cancel()
        
        // Clear AI analysis state
        Task { @MainActor [weak self] in
            self?.resetAnalysisState()
        }
        
        Logger.info("AI Insights state reset for session end")
    }

    private func shouldRunAIAnalysis(for file: ImageFile?) -> Bool {
        syncAIInsightsWithPreferences()
        guard isAIAnalysisEnabled else { return false }
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else { return false }
        guard file != nil else { return false }
        return true
    }

    private func scheduleAIAnalysisIfNeeded(image: NSImage, file: ImageFile?) {
        guard shouldRunAIAnalysis(for: file) else {
            analysisTask?.cancel()
            Task { @MainActor [weak self] in
                await self?.resetAnalysisState()
            }
            return
        }

        analysisTask?.cancel()
        let url = file?.url
        let expectedURL = url
        analysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.aiAnalysisService.analyzeImage(image, url: url)
                try Task.checkCancellation()
                await MainActor.run {
                    // Guard that the analysis result still corresponds to the currently displayed image
                    guard self.currentImageFile?.url == expectedURL else { return }
                    self.updateAnalysisState(with: result)
                }
            } catch is CancellationError {
                // Swallow cancellations triggered by task management
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    // Only surface the error if it still corresponds to the current image
                    guard self.currentImageFile?.url == expectedURL else { return }
                    self.handleAnalysisFailure(error)
                }
            }
        }
    }

    @MainActor
    private func updateAnalysisState(with result: ImageAnalysisResult) {
        currentAnalysis = result
        analysisTags = tags(from: result)
        analysisObjects = result.objects
        analysisScenes = result.scenes
        analysisText = result.text
        analysisError = nil
        
        // Generate insights using the AIBrain
        aiInsights = aiBrain.generateInsights(for: result)
    }

    @MainActor
    private func handleAnalysisFailure(_ error: Error) {
        analysisError = error
        currentAnalysis = nil
        analysisTags = []
        analysisObjects = []
        analysisScenes = []
        analysisText = []
        
        // Handle AI-specific errors with appropriate user feedback
        Logger.error("AI analysis failed: \(error.localizedDescription)", context: "AIAnalysis")
        errorHandlingService.handleAIAnalysisError(error) { [weak self] in
            self?.retryAIAnalysis()
        }
    }

    private func tags(from analysis: ImageAnalysisResult) -> [String] {
        var tagSet = Set<String>()
        tagSet.formUnion(analysis.classifications.map { $0.identifier })
        tagSet.formUnion(analysis.objects.map { $0.identifier })
        tagSet.formUnion(analysis.scenes.map { $0.identifier })
        let textTags = analysis.text
            .map { $0.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        tagSet.formUnion(textTags)
        return Array(tagSet).sorted()
    }

    private func loadCurrentImage() {
        analysisTask?.cancel()
        guard let imageFile = currentImageFile else {
            currentImage = nil
            expectedImageSize = nil
            resetAnalysisState()
            return
        }
        
        // Clear any previous error and state
        errorMessage = nil
        expectedImageSize = nil
        resetAnalysisState()

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
        if compatibilityService.isFeatureAvailable(.enhancedImageProcessing) && isEnhancedProcessingEnabled {
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
                    self.scheduleAIAnalysisIfNeeded(image: image, file: imageFile)
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
                        self.scheduleAIAnalysisIfNeeded(image: image, file: imageFile)
                    }
                    return
                }

                await MainActor.run {
                    self.currentImage = processedImage.currentImage
                    self.isLoading = false
                    self.loadingProgress = 1.0
                    
                    // Reset zoom to fit when loading new image
                    self.zoomToFit()
                    self.scheduleAIAnalysisIfNeeded(image: processedImage.currentImage, file: imageFile)
                }
            } catch {
                await MainActor.run {
                    // Fallback to standard image if processing fails
                    self.currentImage = image
                    self.isLoading = false
                    self.loadingProgress = 1.0
                    self.zoomToFit()
                    self.scheduleAIAnalysisIfNeeded(image: image, file: imageFile)
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
        
        // Favorites removed
        
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
        showImageInfo = false
        viewMode = .normal
        
        // Reset AI Insights state
        resetAIInsightsForSessionEnd()
        
        // Clear thumbnail cache
        thumbnailCache.removeAllObjects()
    }
    
    /// Navigate back to folder selection
    func navigateToFolderSelection() {
        shouldNavigateToFolderSelection = true
    }
    
    // MARK: - Image Info Methods
    
    /// Toggle the image info overlay
    func toggleImageInfo() {
        showImageInfo.toggle()
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
    
    /// Toggle between normal and grid view
    func toggleGridView() {
        switch viewMode {
        case .normal, .thumbnailStrip:
            viewMode = .grid
        case .grid:
            viewMode = .normal
        }
    }
    
    /// Toggle thumbnail strip visibility
    func toggleThumbnailStrip() {
        switch viewMode {
        case .normal, .grid:
            viewMode = .thumbnailStrip
        case .thumbnailStrip:
            viewMode = .normal
        }
    }
    
    /// Set specific view mode
    /// - Parameter mode: The view mode to set
    func setViewMode(_ mode: ViewMode) {
        viewMode = mode
    }
    
    /// Jump to specific image from thumbnail selection
    /// - Parameter index: The index of the image to jump to
    func jumpToImage(at index: Int) {
        guard index >= 0 && index < totalImages else { return }
        
        currentIndex = index
        
        // Load the image
        loadCurrentImage()
        
        // Close grid view after selection
        if viewMode == .grid {
            viewMode = .normal
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
    
    /// Get available sharing services for the current image
    var availableSharingServices: [NSSharingService] {
        guard let currentImageFile = currentImageFile else { return [] }
        // Use NSSharingService.sharingServices but suppress the deprecation warning
        // This is still the correct way to get available sharing services programmatically
        return NSSharingService.sharingServices(forItems: [currentImageFile.url])
    }
    
    /// Check if sharing is available for the current image
    var canShareCurrentImage: Bool {
        return currentImageFile != nil && !availableSharingServices.isEmpty
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
    
    deinit {
        analysisTask?.cancel()
    }
    
    // Favorites removed
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

// MARK: - Array Safe Subscript Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

