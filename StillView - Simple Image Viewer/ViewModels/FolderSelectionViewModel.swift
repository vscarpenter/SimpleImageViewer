import Foundation
import Combine
import AppKit

/// ViewModel for managing folder selection and recent folders functionality
@MainActor
class FolderSelectionViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Currently selected folder URL
    @Published var selectedFolderURL: URL?
    
    /// List of recent folders for quick access
    @Published var recentFolders: [URL] = []
    
    /// Whether folder scanning is in progress
    @Published var isScanning: Bool = false
    
    /// Progress of folder scanning (0.0 to 1.0)
    @Published var scanProgress: Double = 0.0
    
    /// Current error state, if any
    @Published var currentError: ImageViewerError?
    
    /// Whether the folder picker is currently being shown
    @Published var isShowingFolderPicker: Bool = false
    
    /// Number of images found in the current scan
    @Published var imageCount: Int = 0
    
    /// The selected folder content ready for navigation
    @Published var selectedFolderContent: FolderContent?
    
    /// Whether to show the favorites view
    @Published var showingFavorites: Bool = false
    
    /// Whether favorites are available (has at least one favorite)
    @Published private(set) var hasFavorites: Bool = false
    
    // MARK: - Private Properties
    
    private let fileSystemService: FileSystemService
    private var preferencesService: PreferencesService
    private let errorHandlingService: ErrorHandlingService
    private let favoritesService: any FavoritesService
    private let accessManager = SecurityScopedAccessManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?
    private var currentSecurityScopedURL: URL?
    
    // MARK: - Initialization
    
    /// Initialize the view model with required services
    /// - Parameters:
    ///   - fileSystemService: Service for file system operations
    ///   - preferencesService: Service for managing user preferences
    ///   - errorHandlingService: Service for handling errors and user feedback
    ///   - favoritesService: Service for managing favorites
    init(fileSystemService: FileSystemService = DefaultFileSystemService(),
         preferencesService: PreferencesService = DefaultPreferencesService(),
         errorHandlingService: ErrorHandlingService = ErrorHandlingService.shared,
         favoritesService: (any FavoritesService)? = nil) {
        self.fileSystemService = fileSystemService
        self.preferencesService = preferencesService
        self.errorHandlingService = errorHandlingService
        self.favoritesService = favoritesService ?? DefaultFavoritesService.shared
        
        loadRecentFolders()
        setupBindings()
        checkFavoritesAvailability()
    }
    
    deinit {
        scanTask?.cancel()
        // The SecurityScopedAccessManager will handle cleanup
    }
    
    // MARK: - Public Methods
    
    /// Present the folder selection dialog
    func selectFolder() {
        isShowingFolderPicker = true
        currentError = nil
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = false
        openPanel.title = "Select Image Folder"
        openPanel.message = "Choose a folder containing images to browse"
        
        // Set initial directory to last selected folder or user's Pictures folder
        if let lastFolder = preferencesService.lastSelectedFolder,
           FileManager.default.fileExists(atPath: lastFolder.path) {
            openPanel.directoryURL = lastFolder
        } else {
            openPanel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        }
        
        openPanel.begin { [weak self] response in
            DispatchQueue.main.async {
                self?.isShowingFolderPicker = false
                
                if response == .OK, let selectedURL = openPanel.url {
                    self?.handleFolderSelection(selectedURL)
                }
            }
        }
    }
    
    /// Select a folder from the recent folders list
    /// - Parameter url: The folder URL to select
    func selectRecentFolder(_ url: URL) {
        currentError = nil
        
        // Find the corresponding bookmark for this URL
        let storedFolders = preferencesService.recentFolders
        let storedBookmarks = preferencesService.folderBookmarks
        
        guard let index = storedFolders.firstIndex(of: url),
              index < storedBookmarks.count else {
            // No bookmark found, try direct access
            guard FileManager.default.fileExists(atPath: url.path) else {
                let error = ImageViewerError.folderNotFound(url)
                currentError = error
                errorHandlingService.handleImageViewerError(error)
                removeRecentFolder(url)
                return
            }
            handleFolderSelection(url)
            return
        }
        
        // Try to resolve the security-scoped bookmark
        let bookmarkData = storedBookmarks[index]
        guard let resolvedURL = fileSystemService.resolveSecurityScopedBookmark(bookmarkData) else {
            // Bookmark resolution failed
            let error = ImageViewerError.bookmarkResolutionFailed(url)
            currentError = error
            errorHandlingService.handleImageViewerError(error)
            removeRecentFolder(url)
            return
        }
        
        // Use the resolved URL for folder selection
        // Important: resolvedURL already has security-scoped access started
        // handleFolderSelection will register this access with the SecurityScopedAccessManager
        handleFolderSelection(resolvedURL)
    }
    
    /// Remove a folder from the recent folders list
    /// - Parameter url: The folder URL to remove
    func removeRecentFolder(_ url: URL) {
        // Find the index of the folder to remove
        let storedFolders = preferencesService.recentFolders
        let storedBookmarks = preferencesService.folderBookmarks
        
        if let index = storedFolders.firstIndex(of: url) {
            // Remove both folder and corresponding bookmark
            var updatedFolders = storedFolders
            var updatedBookmarks = storedBookmarks
            
            updatedFolders.remove(at: index)
            if index < updatedBookmarks.count {
                updatedBookmarks.remove(at: index)
            }
            
            preferencesService.recentFolders = updatedFolders
            preferencesService.folderBookmarks = updatedBookmarks
            preferencesService.savePreferences()
        }
        
        loadRecentFolders()
    }
    
    /// Clear all recent folders
    func clearRecentFolders() {
        preferencesService.clearRecentFolders()
        loadRecentFolders()
    }
    
    /// Cancel the current folder scanning operation
    func cancelScanning() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress = 0.0
    }
    
    /// Refresh the current folder by rescanning it
    func refreshCurrentFolder() {
        guard let currentFolder = selectedFolderURL else { return }
        handleFolderSelection(currentFolder)
    }
    
    /// Clear the current error state
    func clearError() {
        currentError = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor changes to recent folders in preferences
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadRecentFolders()
                }
            }
            .store(in: &cancellables)
        
        // Monitor changes to favorites
        favoritesService.favoriteImagesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkFavoritesAvailability()
            }
            .store(in: &cancellables)
    }
    
    private func loadRecentFolders() {
        // Load both recent folders and their bookmarks
        let storedFolders = preferencesService.recentFolders
        let storedBookmarks = preferencesService.folderBookmarks
        
        var validFolders: [URL] = []
        var validBookmarks: [Data] = []
        
        // Try to resolve each bookmark to verify folder access
        for (index, folderURL) in storedFolders.enumerated() {
            if index < storedBookmarks.count {
                let bookmarkData = storedBookmarks[index]
                if let resolvedURL = fileSystemService.resolveSecurityScopedBookmark(bookmarkData),
                   resolvedURL == folderURL {
                    validFolders.append(folderURL)
                    validBookmarks.append(bookmarkData)
                    // Stop accessing the resource immediately after verification
                    // This is just for validation, not for actual use
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
            } else {
                // No bookmark for this folder, check if it exists normally
                if FileManager.default.fileExists(atPath: folderURL.path) {
                    validFolders.append(folderURL)
                    // Keep the valid bookmark data array in sync
                    if validBookmarks.count < validFolders.count {
                        // This folder doesn't have a bookmark, we'll handle it later
                    }
                }
            }
        }
        
        // Update preferences with only valid folders and bookmarks
        if validFolders.count != storedFolders.count {
            preferencesService.recentFolders = validFolders
            preferencesService.folderBookmarks = validBookmarks
            preferencesService.savePreferences()
        }
        
        recentFolders = validFolders
    }
    
    private func handleFolderSelection(_ url: URL) {
        // Let SecurityScopedAccessManager handle stopping previous access
        // It will stop any existing access and register the new one
        _ = accessManager.startAccess(for: url)
        
        selectedFolderURL = url
        
        // Track this URL for security-scoped access management
        // This ensures we maintain access throughout the session
        currentSecurityScopedURL = url
        
        // Check if this URL already exists in recent folders with a bookmark
        let storedFolders = preferencesService.recentFolders
        let storedBookmarks = preferencesService.folderBookmarks
        let existingIndex = storedFolders.firstIndex(of: url)
        
        // Create security-scoped bookmark for future access
        // Skip bookmark creation if we already have one and this URL has active security access
        let shouldCreateBookmark = existingIndex == nil || existingIndex! >= storedBookmarks.count
        
        if shouldCreateBookmark, let bookmarkData = fileSystemService.createSecurityScopedBookmark(for: url) {
            // Remove existing entry if it exists
            var updatedFolders = storedFolders
            var updatedBookmarks = storedBookmarks
            
            if let existingIndex = updatedFolders.firstIndex(of: url) {
                updatedFolders.remove(at: existingIndex)
                if existingIndex < updatedBookmarks.count {
                    updatedBookmarks.remove(at: existingIndex)
                }
            }
            
            // Add to beginning of list
            updatedFolders.insert(url, at: 0)
            updatedBookmarks.insert(bookmarkData, at: 0)
            
            // Limit to 10 entries
            updatedFolders = Array(updatedFolders.prefix(10))
            updatedBookmarks = Array(updatedBookmarks.prefix(10))
            
            // Update preferences
            preferencesService.recentFolders = updatedFolders
            preferencesService.folderBookmarks = updatedBookmarks
            preferencesService.lastSelectedFolder = url
            preferencesService.savePreferences()
        } else if let existingIndex = existingIndex, existingIndex < storedBookmarks.count {
            // We already have a bookmark for this URL, just reorder it
            var updatedFolders = storedFolders
            var updatedBookmarks = storedBookmarks
            
            // Move existing entry to the front
            let folder = updatedFolders.remove(at: existingIndex)
            let bookmark = updatedBookmarks.remove(at: existingIndex)
            
            updatedFolders.insert(folder, at: 0)
            updatedBookmarks.insert(bookmark, at: 0)
            
            // Update preferences
            preferencesService.recentFolders = updatedFolders
            preferencesService.folderBookmarks = updatedBookmarks
            preferencesService.lastSelectedFolder = url
            preferencesService.savePreferences()
        } else {
            // If bookmark creation failed, still update recent folders
            // This might happen if we already have active security-scoped access
            preferencesService.addRecentFolder(url)
            preferencesService.lastSelectedFolder = url
            preferencesService.savePreferences()
        }
        
        // Update recent folders list
        loadRecentFolders()
        
        // Start scanning the folder
        scanFolder(url)
    }
    
    private func scanFolder(_ url: URL) {
        // Cancel any existing scan
        cancelScanning()
        
        isScanning = true
        scanProgress = 0.0
        imageCount = 0
        currentError = nil
        
        scanTask = Task { [weak self] in
            do {
                // Update progress to show scanning started
                await MainActor.run {
                    self?.scanProgress = 0.1
                }
                
                // Perform the actual folder scan
                let imageFiles = try await self?.fileSystemService.scanFolder(url, recursive: false) ?? []
                
                // Check if task was cancelled
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self?.scanProgress = 1.0
                    self?.imageCount = imageFiles.count
                    self?.isScanning = false
                    
                    // Create folder content and post notification for navigation
                    let folderContent = FolderContent(folderURL: url, imageFiles: imageFiles)
                    self?.selectedFolderContent = folderContent
                    
                    // Post notification that folder was selected
                    NotificationCenter.default.post(
                        name: .folderSelected,
                        object: folderContent
                    )
                }
                
            } catch {
                // Check if task was cancelled
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self?.isScanning = false
                    self?.scanProgress = 0.0
                    self?.imageCount = 0
                    
                    // Convert error to ImageViewerError
                    if let fileSystemError = error as? FileSystemError {
                        switch fileSystemError {
                        case .folderAccessDenied:
                            self?.currentError = .folderAccessDenied
                        case .folderNotFound:
                            self?.currentError = .folderNotFound(url)
                        case .noImagesFound:
                            self?.currentError = .noImagesFound
                        case .scanningFailed(let underlyingError):
                            self?.currentError = .folderScanningFailed(underlyingError)
                        default:
                            self?.currentError = .folderScanningFailed(error)
                        }
                    } else {
                        self?.currentError = .folderScanningFailed(error)
                    }
                    
                    // Error is already set in currentError property
                }
            }
        }
    }
    
    /// Restore the last selected folder from preferences
    /// - Parameter folderURL: The folder URL to restore
    func restoreLastFolder(_ folderURL: URL) {
        // Check if we can still access this folder
        guard folderURL.startAccessingSecurityScopedResource() else {
            // Remove from recent folders if we can't access it
            removeRecentFolder(folderURL)
            return
        }
        
        defer {
            folderURL.stopAccessingSecurityScopedResource()
        }
        
        // Set as selected folder and scan it
        selectedFolderURL = folderURL
        scanFolder(folderURL)
    }
    
    /// Show the favorites view
    func showFavorites() {
        showingFavorites = true
    }
    
    /// Hide the favorites view and return to folder selection
    func hideFavorites() {
        showingFavorites = false
    }
    
    /// Check if favorites are available and update the published property
    private func checkFavoritesAvailability() {
        let favoritesCount = favoritesService.favoriteImages.count
        let newHasFavorites = favoritesCount > 0
        print("DEBUG: FolderSelectionViewModel.checkFavoritesAvailability() - Favorites count: \(favoritesCount), hasFavorites: \(newHasFavorites)")
        hasFavorites = newHasFavorites
    }
}



