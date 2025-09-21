import SwiftUI
import Combine

/// ViewModel for managing preferences state and integration with PreferencesService
@MainActor
class PreferencesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // General preferences
    @Published var showFileName: Bool = false
    @Published var showImageInfo: Bool = false
    @Published var slideshowInterval: Double = 3.0
    @Published var confirmDelete: Bool = true
    @Published var rememberLastFolder: Bool = true
    @Published var defaultZoomLevel: ZoomLevel = .fitToWindow
    @Published var loopSlideshow: Bool = true
    
    // Appearance preferences (to be extended)
    @Published var toolbarStyle: ToolbarStyle = .floating
    @Published var enableGlassEffects: Bool = true
    @Published var animationIntensity: AnimationIntensity = .normal
    @Published var enableHoverEffects: Bool = true
    @Published var thumbnailSize: ThumbnailSize = .medium
    @Published var showMetadataBadges: Bool = true
    
    // Validation state
    @Published var validationResults: [ValidationResult] = []
    @Published var hasUnsavedChanges: Bool = false
    
    // Undo/Redo state
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    
    // MARK: - Private Properties
    
    private var preferencesService: PreferencesService
    private let appearanceService = AppearanceService.shared
    private let backupService = PreferencesBackupService.shared
    private let validator = PreferencesValidator.shared
    private var cancellables = Set<AnyCancellable>()
    private var initialValues: [String: Any] = [:]
    
    // Undo/Redo system
    private var undoStack: [PreferencesSnapshot] = []
    private var redoStack: [PreferencesSnapshot] = []
    private let maxUndoSteps = 20
    
    // MARK: - Initialization
    
    init(preferencesService: PreferencesService = DefaultPreferencesService.shared) {
        self.preferencesService = preferencesService
        
        do {
            try loadPreferencesWithErrorHandling()
            storeInitialValues()
            setupBindings()
            updateValidation()
        } catch {
            // Handle corrupted preferences
            Logger.error("Failed to load preferences: \(error.localizedDescription)")
            recoverFromCorruption()
        }
    }
    
    // MARK: - Public Methods
    
    /// Save all preferences to persistent storage
    func savePreferences() {
        preferencesService.savePreferences()
    }
    
    /// Reset all preferences to default values
    func resetToDefaults() {
        Task {
            // Create backup before reset
            await backupService.createBackup(reason: "before_reset")
            
            await MainActor.run {
                showFileName = false
                showImageInfo = false
                slideshowInterval = 3.0
                confirmDelete = true
                rememberLastFolder = true
                defaultZoomLevel = .fitToWindow
                loopSlideshow = true
                
                toolbarStyle = .floating
                enableGlassEffects = true
                animationIntensity = .normal
                enableHoverEffects = true
                thumbnailSize = .medium
                showMetadataBadges = true
                
                // Reset AppearanceService to defaults
                appearanceService.updateSettings(
                    toolbarStyle: .floating,
                    enableGlassEffects: true,
                    animationIntensity: .normal,
                    enableHoverEffects: true,
                    thumbnailSize: .medium,
                    showMetadataBadges: true
                )
                
                savePreferences()
                storeInitialValues()
                updateValidation()
            }
        }
    }
    
    /// Recover from corrupted preferences
    func recoverFromCorruption() {
        Task {
            let recovered = await backupService.recoverFromCorruption()
            
            await MainActor.run {
                if recovered {
                    // Reload preferences after recovery
                    loadPreferences()
                    storeInitialValues()
                    updateValidation()
                }
            }
        }
    }
    
    /// Check if current values differ from initial values
    func checkForUnsavedChanges() {
        hasUnsavedChanges = !areValuesEqualToInitial()
    }
    
    /// Get validation result for a specific setting
    func getValidationResult(for setting: String) -> ValidationResult? {
        switch setting {
        case "slideshowInterval":
            return validator.validateSlideshowInterval(slideshowInterval)
        case "defaultZoomLevel":
            return validator.validateZoomLevel(defaultZoomLevel)
        case "animationIntensity":
            return validator.validateAnimationIntensity(animationIntensity)
        case "thumbnailSize":
            return validator.validateThumbnailSize(thumbnailSize)
        case "enableGlassEffects":
            return validator.validateGlassEffects(enableGlassEffects)
        case "enableHoverEffects":
            return validator.validateHoverEffects(enableHoverEffects)
        default:
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Load preferences from the service
    private func loadPreferences() {
        showFileName = preferencesService.showFileName
        showImageInfo = preferencesService.showImageInfo
        slideshowInterval = preferencesService.slideshowInterval
        
        // Load thumbnail size from existing service
        switch preferencesService.defaultThumbnailGridSize {
        case .small:
            thumbnailSize = .small
        case .medium:
            thumbnailSize = .medium
        case .large:
            thumbnailSize = .large
        }
        
        // Load other preferences from UserDefaults (extended preferences)
        loadExtendedPreferences()
    }
    
    /// Load preferences with error handling and validation
    private func loadPreferencesWithErrorHandling() throws {
        // Validate preferences service
        guard preferencesService.slideshowInterval >= 1.0 && preferencesService.slideshowInterval <= 30.0 else {
            throw PreferencesError.invalidSlideshowInterval
        }
        
        // Load with validation
        showFileName = preferencesService.showFileName
        showImageInfo = preferencesService.showImageInfo
        slideshowInterval = preferencesService.slideshowInterval
        
        // Validate slideshow interval
        if slideshowInterval < 1.0 || slideshowInterval > 30.0 {
            slideshowInterval = 3.0 // Reset to default
        }
        
        // Load thumbnail size from existing service
        switch preferencesService.defaultThumbnailGridSize {
        case .small:
            thumbnailSize = .small
        case .medium:
            thumbnailSize = .medium
        case .large:
            thumbnailSize = .large
        }
        
        // Load other preferences with validation
        try loadExtendedPreferencesWithValidation()
    }
    
    /// Load extended preferences that aren't in the main PreferencesService yet
    private func loadExtendedPreferences() {
        let userDefaults = UserDefaults.standard
        
        confirmDelete = userDefaults.object(forKey: "PreferencesConfirmDelete") as? Bool ?? true
        rememberLastFolder = userDefaults.object(forKey: "PreferencesRememberLastFolder") as? Bool ?? true
        loopSlideshow = userDefaults.object(forKey: "PreferencesLoopSlideshow") as? Bool ?? true
        
        // Default zoom level
        let zoomRawValue = userDefaults.string(forKey: "PreferencesDefaultZoomLevel") ?? "fitToWindow"
        defaultZoomLevel = ZoomLevel(rawValue: zoomRawValue) ?? .fitToWindow
        
        // Sync appearance settings from AppearanceService
        toolbarStyle = appearanceService.toolbarStyle
        enableGlassEffects = appearanceService.enableGlassEffects
        animationIntensity = appearanceService.animationIntensity
        enableHoverEffects = appearanceService.enableHoverEffects
        thumbnailSize = appearanceService.thumbnailSize
        showMetadataBadges = appearanceService.showMetadataBadges
    }
    
    /// Load extended preferences with validation and error handling
    private func loadExtendedPreferencesWithValidation() throws {
        let userDefaults = UserDefaults.standard
        
        // Load with type validation
        if let confirmDeleteValue = userDefaults.object(forKey: "PreferencesConfirmDelete") {
            guard let confirmDeleteBool = confirmDeleteValue as? Bool else {
                throw PreferencesError.invalidBooleanValue("PreferencesConfirmDelete")
            }
            confirmDelete = confirmDeleteBool
        } else {
            confirmDelete = true
        }
        
        if let rememberFolderValue = userDefaults.object(forKey: "PreferencesRememberLastFolder") {
            guard let rememberFolderBool = rememberFolderValue as? Bool else {
                throw PreferencesError.invalidBooleanValue("PreferencesRememberLastFolder")
            }
            rememberLastFolder = rememberFolderBool
        } else {
            rememberLastFolder = true
        }
        
        if let loopSlideshowValue = userDefaults.object(forKey: "PreferencesLoopSlideshow") {
            guard let loopSlideshowBool = loopSlideshowValue as? Bool else {
                throw PreferencesError.invalidBooleanValue("PreferencesLoopSlideshow")
            }
            loopSlideshow = loopSlideshowBool
        } else {
            loopSlideshow = true
        }
        
        // Default zoom level with validation
        let zoomRawValue = userDefaults.string(forKey: "PreferencesDefaultZoomLevel") ?? "fitToWindow"
        guard let zoomLevel = ZoomLevel(rawValue: zoomRawValue) else {
            throw PreferencesError.invalidEnumValue("PreferencesDefaultZoomLevel", zoomRawValue)
        }
        defaultZoomLevel = zoomLevel
        
        // Sync appearance settings from AppearanceService (these are validated in AppearanceService)
        toolbarStyle = appearanceService.toolbarStyle
        enableGlassEffects = appearanceService.enableGlassEffects
        animationIntensity = appearanceService.animationIntensity
        enableHoverEffects = appearanceService.enableHoverEffects
        thumbnailSize = appearanceService.thumbnailSize
        showMetadataBadges = appearanceService.showMetadataBadges
    }
    
    /// Set up bindings to automatically save changes
    private func setupBindings() {
        // Bind to existing PreferencesService properties
        $showFileName
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferencesService.showFileName = newValue
                self?.preferencesService.savePreferences()
            }
            .store(in: &cancellables)
        
        $showImageInfo
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferencesService.showImageInfo = newValue
                self?.preferencesService.savePreferences()
            }
            .store(in: &cancellables)
        
        $slideshowInterval
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferencesService.slideshowInterval = newValue
                self?.preferencesService.savePreferences()
            }
            .store(in: &cancellables)
        
        $thumbnailSize
            .dropFirst()
            .sink { [weak self] newValue in
                let gridSize: ThumbnailGridSize
                switch newValue {
                case .small:
                    gridSize = .small
                case .medium:
                    gridSize = .medium
                case .large:
                    gridSize = .large
                }
                self?.preferencesService.defaultThumbnailGridSize = gridSize
                self?.preferencesService.savePreferences()
            }
            .store(in: &cancellables)
        
        // Bind extended preferences to UserDefaults
        setupExtendedBindings()
    }
    
    /// Set up bindings for extended preferences
    private func setupExtendedBindings() {
        let userDefaults = UserDefaults.standard
        
        $confirmDelete
            .dropFirst()
            .sink { newValue in
                userDefaults.set(newValue, forKey: "PreferencesConfirmDelete")
            }
            .store(in: &cancellables)
        
        $rememberLastFolder
            .dropFirst()
            .sink { newValue in
                userDefaults.set(newValue, forKey: "PreferencesRememberLastFolder")
            }
            .store(in: &cancellables)
        
        $loopSlideshow
            .dropFirst()
            .sink { newValue in
                userDefaults.set(newValue, forKey: "PreferencesLoopSlideshow")
            }
            .store(in: &cancellables)
        
        $defaultZoomLevel
            .dropFirst()
            .sink { newValue in
                userDefaults.set(newValue.rawValue, forKey: "PreferencesDefaultZoomLevel")
            }
            .store(in: &cancellables)
        
        // Sync appearance settings with AppearanceService
        $toolbarStyle
            .dropFirst()
            .sink { [weak self] newValue in
                self?.appearanceService.toolbarStyle = newValue
            }
            .store(in: &cancellables)
        
        $enableGlassEffects
            .dropFirst()
            .sink { [weak self] newValue in
                self?.appearanceService.enableGlassEffects = newValue
            }
            .store(in: &cancellables)
        
        $enableHoverEffects
            .dropFirst()
            .sink { [weak self] newValue in
                self?.appearanceService.enableHoverEffects = newValue
            }
            .store(in: &cancellables)
        
        $showMetadataBadges
            .dropFirst()
            .sink { [weak self] newValue in
                self?.appearanceService.showMetadataBadges = newValue
            }
            .store(in: &cancellables)
        
        $animationIntensity
            .dropFirst()
            .sink { [weak self] newValue in
                self?.appearanceService.animationIntensity = newValue
            }
            .store(in: &cancellables)
        
        $thumbnailSize
            .dropFirst()
            .sink { [weak self] newValue in
                self?.appearanceService.thumbnailSize = newValue
            }
            .store(in: &cancellables)
        
        // Set up validation updates
        setupValidationBindings()
    }
    
    /// Store initial values for change detection
    private func storeInitialValues() {
        initialValues = [
            "showFileName": showFileName,
            "showImageInfo": showImageInfo,
            "slideshowInterval": slideshowInterval,
            "confirmDelete": confirmDelete,
            "rememberLastFolder": rememberLastFolder,
            "defaultZoomLevel": defaultZoomLevel.rawValue,
            "loopSlideshow": loopSlideshow,
            "toolbarStyle": toolbarStyle.rawValue,
            "enableGlassEffects": enableGlassEffects,
            "animationIntensity": animationIntensity.rawValue,
            "enableHoverEffects": enableHoverEffects,
            "thumbnailSize": thumbnailSize.rawValue,
            "showMetadataBadges": showMetadataBadges
        ]
    }
    
    /// Check if current values equal initial values
    private func areValuesEqualToInitial() -> Bool {
        let currentValues: [String: Any] = [
            "showFileName": showFileName,
            "showImageInfo": showImageInfo,
            "slideshowInterval": slideshowInterval,
            "confirmDelete": confirmDelete,
            "rememberLastFolder": rememberLastFolder,
            "defaultZoomLevel": defaultZoomLevel.rawValue,
            "loopSlideshow": loopSlideshow,
            "toolbarStyle": toolbarStyle.rawValue,
            "enableGlassEffects": enableGlassEffects,
            "animationIntensity": animationIntensity.rawValue,
            "enableHoverEffects": enableHoverEffects,
            "thumbnailSize": thumbnailSize.rawValue,
            "showMetadataBadges": showMetadataBadges
        ]
        
        return NSDictionary(dictionary: currentValues).isEqual(to: initialValues)
    }
    
    /// Update validation results
    private func updateValidation() {
        var results: [ValidationResult] = []
        
        // Validate individual settings
        let slideshowResult = validator.validateSlideshowInterval(slideshowInterval)
        if slideshowResult.message != nil { results.append(slideshowResult) }
        
        let zoomResult = validator.validateZoomLevel(defaultZoomLevel)
        if zoomResult.message != nil { results.append(zoomResult) }
        
        let animationResult = validator.validateAnimationIntensity(animationIntensity)
        if animationResult.message != nil { results.append(animationResult) }
        
        let thumbnailResult = validator.validateThumbnailSize(thumbnailSize)
        if thumbnailResult.message != nil { results.append(thumbnailResult) }
        
        let glassResult = validator.validateGlassEffects(enableGlassEffects)
        if glassResult.message != nil { results.append(glassResult) }
        
        let hoverResult = validator.validateHoverEffects(enableHoverEffects)
        if hoverResult.message != nil { results.append(hoverResult) }
        
        // Add performance and accessibility validation
        results.append(contentsOf: validator.validatePerformanceImpact(self))
        results.append(contentsOf: validator.validateAccessibility(self))
        
        validationResults = results
    }
    
    /// Set up validation bindings that update when values change
    private func setupValidationBindings() {
        // Update validation when any preference changes
        Publishers.CombineLatest4(
            $slideshowInterval,
            $defaultZoomLevel,
            $animationIntensity,
            $thumbnailSize
        )
        .dropFirst()
        .sink { [weak self] _, _, _, _ in
            self?.updateValidation()
            self?.checkForUnsavedChanges()
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest4(
            $enableGlassEffects,
            $enableHoverEffects,
            $showMetadataBadges,
            $toolbarStyle
        )
        .dropFirst()
        .sink { [weak self] _, _, _, _ in
            self?.updateValidation()
            self?.checkForUnsavedChanges()
        }
        .store(in: &cancellables)
        
        // Update for boolean preferences
        Publishers.CombineLatest4(
            $showFileName,
            $showImageInfo,
            $confirmDelete,
            $rememberLastFolder
        )
        .dropFirst()
        .sink { [weak self] _, _, _, _ in
            self?.checkForUnsavedChanges()
        }
        .store(in: &cancellables)
        
        $loopSlideshow
            .dropFirst()
            .sink { [weak self] _ in
                self?.checkForUnsavedChanges()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Undo/Redo Methods
    
    /// Create a snapshot of current preferences for undo/redo
    private func createSnapshot() -> PreferencesSnapshot {
        return PreferencesSnapshot(
            showFileName: showFileName,
            showImageInfo: showImageInfo,
            slideshowInterval: slideshowInterval,
            confirmDelete: confirmDelete,
            rememberLastFolder: rememberLastFolder,
            defaultZoomLevel: defaultZoomLevel,
            loopSlideshow: loopSlideshow,
            toolbarStyle: toolbarStyle,
            enableGlassEffects: enableGlassEffects,
            animationIntensity: animationIntensity,
            enableHoverEffects: enableHoverEffects,
            thumbnailSize: thumbnailSize,
            showMetadataBadges: showMetadataBadges
        )
    }
    
    /// Apply a snapshot to current preferences
    private func applySnapshot(_ snapshot: PreferencesSnapshot) {
        showFileName = snapshot.showFileName
        showImageInfo = snapshot.showImageInfo
        slideshowInterval = snapshot.slideshowInterval
        confirmDelete = snapshot.confirmDelete
        rememberLastFolder = snapshot.rememberLastFolder
        defaultZoomLevel = snapshot.defaultZoomLevel
        loopSlideshow = snapshot.loopSlideshow
        toolbarStyle = snapshot.toolbarStyle
        enableGlassEffects = snapshot.enableGlassEffects
        animationIntensity = snapshot.animationIntensity
        enableHoverEffects = snapshot.enableHoverEffects
        thumbnailSize = snapshot.thumbnailSize
        showMetadataBadges = snapshot.showMetadataBadges
        
        // Update appearance service
        appearanceService.updateSettings(
            toolbarStyle: toolbarStyle,
            enableGlassEffects: enableGlassEffects,
            animationIntensity: animationIntensity,
            enableHoverEffects: enableHoverEffects,
            thumbnailSize: thumbnailSize,
            showMetadataBadges: showMetadataBadges
        )
        
        savePreferences()
        updateValidation()
    }
    
    /// Push current state to undo stack before making changes
    func pushUndoState() {
        let snapshot = createSnapshot()
        undoStack.append(snapshot)
        
        // Limit undo stack size
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        
        // Clear redo stack when new changes are made
        redoStack.removeAll()
        
        updateUndoRedoState()
    }
    
    /// Undo the last change
    func undo() {
        guard !undoStack.isEmpty else { return }
        
        // Push current state to redo stack
        let currentSnapshot = createSnapshot()
        redoStack.append(currentSnapshot)
        
        // Apply previous state
        let previousSnapshot = undoStack.removeLast()
        applySnapshot(previousSnapshot)
        
        updateUndoRedoState()
    }
    
    /// Redo the last undone change
    func redo() {
        guard !redoStack.isEmpty else { return }
        
        // Push current state to undo stack
        let currentSnapshot = createSnapshot()
        undoStack.append(currentSnapshot)
        
        // Apply next state
        let nextSnapshot = redoStack.removeLast()
        applySnapshot(nextSnapshot)
        
        updateUndoRedoState()
    }
    
    /// Revert to initial values (when preferences window was opened)
    func revertToInitial() {
        guard !areValuesEqualToInitial() else { return }
        
        // Push current state to undo stack
        pushUndoState()
        
        // Revert to initial values
        if let showFileNameInitial = initialValues["showFileName"] as? Bool {
            showFileName = showFileNameInitial
        }
        if let showImageInfoInitial = initialValues["showImageInfo"] as? Bool {
            showImageInfo = showImageInfoInitial
        }
        if let slideshowIntervalInitial = initialValues["slideshowInterval"] as? Double {
            slideshowInterval = slideshowIntervalInitial
        }
        if let confirmDeleteInitial = initialValues["confirmDelete"] as? Bool {
            confirmDelete = confirmDeleteInitial
        }
        if let rememberLastFolderInitial = initialValues["rememberLastFolder"] as? Bool {
            rememberLastFolder = rememberLastFolderInitial
        }
        if let defaultZoomLevelRaw = initialValues["defaultZoomLevel"] as? String,
           let zoomLevel = ZoomLevel(rawValue: defaultZoomLevelRaw) {
            defaultZoomLevel = zoomLevel
        }
        if let loopSlideshowInitial = initialValues["loopSlideshow"] as? Bool {
            loopSlideshow = loopSlideshowInitial
        }
        if let toolbarStyleRaw = initialValues["toolbarStyle"] as? String,
           let style = ToolbarStyle(rawValue: toolbarStyleRaw) {
            toolbarStyle = style
        }
        if let enableGlassEffectsInitial = initialValues["enableGlassEffects"] as? Bool {
            enableGlassEffects = enableGlassEffectsInitial
        }
        if let animationIntensityRaw = initialValues["animationIntensity"] as? String,
           let intensity = AnimationIntensity(rawValue: animationIntensityRaw) {
            animationIntensity = intensity
        }
        if let enableHoverEffectsInitial = initialValues["enableHoverEffects"] as? Bool {
            enableHoverEffects = enableHoverEffectsInitial
        }
        if let thumbnailSizeRaw = initialValues["thumbnailSize"] as? String,
           let size = ThumbnailSize(rawValue: thumbnailSizeRaw) {
            thumbnailSize = size
        }
        if let showMetadataBadgesInitial = initialValues["showMetadataBadges"] as? Bool {
            showMetadataBadges = showMetadataBadgesInitial
        }
        
        // Update appearance service
        appearanceService.updateSettings(
            toolbarStyle: toolbarStyle,
            enableGlassEffects: enableGlassEffects,
            animationIntensity: animationIntensity,
            enableHoverEffects: enableHoverEffects,
            thumbnailSize: thumbnailSize,
            showMetadataBadges: showMetadataBadges
        )
        
        savePreferences()
        updateValidation()
        updateUndoRedoState()
    }
    
    /// Clear undo/redo history
    func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoState()
    }
    
    /// Update undo/redo state flags
    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

// MARK: - Preferences Snapshot

/// Snapshot of preferences state for undo/redo functionality
private struct PreferencesSnapshot {
    let showFileName: Bool
    let showImageInfo: Bool
    let slideshowInterval: Double
    let confirmDelete: Bool
    let rememberLastFolder: Bool
    let defaultZoomLevel: ZoomLevel
    let loopSlideshow: Bool
    let toolbarStyle: ToolbarStyle
    let enableGlassEffects: Bool
    let animationIntensity: AnimationIntensity
    let enableHoverEffects: Bool
    let thumbnailSize: ThumbnailSize
    let showMetadataBadges: Bool
}

// MARK: - Error Types

/// Errors that can occur during preferences loading and validation
enum PreferencesError: LocalizedError {
    case invalidSlideshowInterval
    case invalidBooleanValue(String)
    case invalidEnumValue(String, String)
    case corruptedPreferences
    
    var errorDescription: String? {
        switch self {
        case .invalidSlideshowInterval:
            return "Slideshow interval is out of valid range"
        case .invalidBooleanValue(let key):
            return "Invalid boolean value for preference key: \(key)"
        case .invalidEnumValue(let key, let value):
            return "Invalid enum value '\(value)' for preference key: \(key)"
        case .corruptedPreferences:
            return "Preferences data is corrupted"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidSlideshowInterval:
            return "The slideshow interval will be reset to the default value of 3 seconds."
        case .invalidBooleanValue, .invalidEnumValue:
            return "The invalid preference will be reset to its default value."
        case .corruptedPreferences:
            return "Preferences will be restored from backup or reset to defaults."
        }
    }
}

// Note: Enums are now defined in PreferencesEnums.swift to avoid duplication