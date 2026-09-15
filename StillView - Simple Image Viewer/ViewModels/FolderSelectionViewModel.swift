import Foundation
import Combine
import AppKit

/// Presents the native picker independently of the view currently visible in the window.
@MainActor
protocol FolderPanelPresenting {
    func present(initialDirectory: URL?, completion: @escaping @MainActor (URL?) -> Void)
}

@MainActor
final class SystemFolderPanelPresenter: FolderPanelPresenting {
    func present(initialDirectory: URL?, completion: @escaping @MainActor (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "Select Image Folder"
        panel.message = "Choose a folder containing images to browse"
        panel.directoryURL = initialDirectory
        panel.begin { response in
            Task { @MainActor in
                completion(response == .OK ? panel.url : nil)
            }
        }
    }
}

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

    // MARK: - Private Properties

    private let fileSystemService: FileSystemService
    private var preferencesService: PreferencesService
    private let accessManager: SecurityScopedAccessManager
    private let panelPresenter: FolderPanelPresenting
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?
    private var scanGeneration = UUID()
    
    // MARK: - Initialization
    
    /// Initialize the view model with required services
    /// - Parameters:
    ///   - fileSystemService: Service for file system operations
    ///   - preferencesService: Service for managing user preferences
    init(fileSystemService: FileSystemService = DefaultFileSystemService(),
         preferencesService: PreferencesService = DefaultPreferencesService(),
         panelPresenter: FolderPanelPresenting? = nil,
         accessManager: SecurityScopedAccessManager = .shared) {
        self.fileSystemService = fileSystemService
        self.preferencesService = preferencesService
        self.panelPresenter = panelPresenter ?? SystemFolderPanelPresenter()
        self.accessManager = accessManager

        loadRecentFolders()
        setupBindings()
    }
    
    deinit {
        scanTask?.cancel()
        // The SecurityScopedAccessManager will handle cleanup
    }
    
    // MARK: - Public Methods
    
    /// Present the folder selection dialog
    func selectFolder() {
        // panel.begin is non-modal, so a second request (menu, button) while
        // the panel is up would open a duplicate.
        guard !isShowingFolderPicker else { return }
        isShowingFolderPicker = true
        currentError = nil
        
        let initialDirectory: URL?
        if let lastFolder = preferencesService.lastSelectedFolder,
           FileManager.default.fileExists(atPath: lastFolder.path) {
            initialDirectory = lastFolder
        } else {
            initialDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        }

        panelPresenter.present(initialDirectory: initialDirectory) { [weak self] selectedURL in
            guard let self else { return }
            self.isShowingFolderPicker = false
            if let selectedURL {
                self.handleFolderSelection(selectedURL)
            }
        }
    }
    
    /// Select a folder from the recent folders list
    /// - Parameter url: The folder URL to select
    func selectRecentFolder(_ url: URL) {
        // A newer request supersedes an in-flight scan even when its bookmark cannot be resolved.
        cancelScanning()
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
            removeRecentFolder(url)
            return
        }
        
        // The resolver already started this scope. The scan owns it until success or cancellation.
        handleFolderSelection(resolvedURL, accessAlreadyStarted: true)
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
        scanGeneration = UUID()
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
                if let resolvedURL = fileSystemService.resolveSecurityScopedBookmark(bookmarkData) {
                    defer { resolvedURL.stopAccessingSecurityScopedResource() }
                    if resolvedURL == folderURL {
                        validFolders.append(folderURL)
                        validBookmarks.append(bookmarkData)
                    }
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
    
    private func rememberSuccessfulFolder(_ url: URL) {
        // Check if this URL already exists in recent folders with a bookmark
        let storedFolders = preferencesService.recentFolders
        let storedBookmarks = preferencesService.folderBookmarks
        let existingIndex = storedFolders.firstIndex(of: url)
        
        // Create security-scoped bookmark for future access
        // Skip bookmark creation if we already have one and this URL has active security access
        let shouldCreateBookmark = existingIndex.map { $0 >= storedBookmarks.count } ?? true
        
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
        
    }

    private func handleFolderSelection(_ url: URL, accessAlreadyStarted: Bool = false) {
        cancelScanning()
        let generation = scanGeneration
        // Starting a tentative scan must not revoke access to the folder still on screen.
        let accessStarted = accessAlreadyStarted || url.startAccessingSecurityScopedResource()
        let fileSystemService = fileSystemService
        let accessManager = accessManager
        isScanning = true
        scanProgress = 0.1
        imageCount = 0
        currentError = nil

        scanTask = Task { [weak self] in
            var transferredAccess = false
            defer {
                // A canceled service may finish later; retain its grant until it actually returns.
                if accessStarted && !transferredAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let imageFiles = try await fileSystemService.scanFolder(url, recursive: false)
                guard !Task.isCancelled, let self, self.scanGeneration == generation else { return }

                if accessManager.currentURL != url {
                    transferredAccess = accessManager.startAccess(for: url)
                }
                self.rememberSuccessfulFolder(url)
                self.selectedFolderURL = url
                self.selectedFolderContent = FolderContent(folderURL: url, imageFiles: imageFiles)
                self.scanProgress = 1.0
                self.imageCount = imageFiles.count
                self.isScanning = false
                self.scanTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.scanGeneration == generation else { return }
                self.isScanning = false
                self.scanProgress = 0.0
                self.imageCount = 0
                self.currentError = Self.scanError(error, folderURL: url)
                self.scanTask = nil
            }
        }
    }

    private static func scanError(_ error: Error, folderURL: URL) -> ImageViewerError {
        guard let fileSystemError = error as? FileSystemError else {
            return .folderScanningFailed(error)
        }
        switch fileSystemError {
        case .folderAccessDenied:
            return .folderAccessDenied
        case .folderNotFound:
            return .folderNotFound(folderURL)
        case .noImagesFound:
            return .noImagesFound
        case .scanningFailed(let underlyingError):
            return .folderScanningFailed(underlyingError)
        default:
            return .folderScanningFailed(error)
        }
    }

    /// Restore through the same durable scan lifecycle, resolving a saved grant when available.
    func restoreLastFolder(_ folderURL: URL) {
        selectRecentFolder(folderURL)
    }
}
