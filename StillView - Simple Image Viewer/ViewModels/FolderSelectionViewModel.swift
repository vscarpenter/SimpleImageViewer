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
    
    // MARK: - Private Properties
    
    private let fileSystemService: FileSystemService
    private var preferencesService: PreferencesService
    private let errorHandlingService: ErrorHandlingService
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Initialize the view model with required services
    /// - Parameters:
    ///   - fileSystemService: Service for file system operations
    ///   - preferencesService: Service for managing user preferences
    ///   - errorHandlingService: Service for handling errors and user feedback
    init(fileSystemService: FileSystemService = DefaultFileSystemService(),
         preferencesService: PreferencesService = DefaultPreferencesService(),
         errorHandlingService: ErrorHandlingService = ErrorHandlingService.shared) {
        self.fileSystemService = fileSystemService
        self.preferencesService = preferencesService
        self.errorHandlingService = errorHandlingService
        
        loadRecentFolders()
        setupBindings()
    }
    
    deinit {
        scanTask?.cancel()
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
        
        // Check if folder still exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            let error = ImageViewerError.folderNotFound(url)
            currentError = error
            errorHandlingService.handleImageViewerError(error)
            removeRecentFolder(url)
            return
        }
        
        handleFolderSelection(url)
    }
    
    /// Remove a folder from the recent folders list
    /// - Parameter url: The folder URL to remove
    func removeRecentFolder(_ url: URL) {
        preferencesService.removeRecentFolder(url)
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
    }
    
    private func loadRecentFolders() {
        recentFolders = preferencesService.recentFolders
    }
    
    private func handleFolderSelection(_ url: URL) {
        selectedFolderURL = url
        
        // Add to recent folders
        preferencesService.addRecentFolder(url)
        preferencesService.lastSelectedFolder = url
        preferencesService.savePreferences()
        
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
                // Create security-scoped bookmark for sandboxed access
                if let bookmarkData = await self?.fileSystemService.createSecurityScopedBookmark(for: url) {
                    await MainActor.run {
                        var bookmarks = self?.preferencesService.folderBookmarks ?? []
                        bookmarks.append(bookmarkData)
                        self?.preferencesService.folderBookmarks = bookmarks
                    }
                }
                
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
}



