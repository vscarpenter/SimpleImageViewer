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
    @Published private(set) var includeSubfolders = false

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
        cancelScanning(keepingPartialResults: false)
        currentError = nil
        
        guard let record = preferencesService.recentFolderRecords.first(where: { $0.url == url }),
              let bookmarkData = record.bookmarkData else {
            guard FileManager.default.fileExists(atPath: url.path) else {
                currentError = .folderNotFound(url)
                // An unavailable provider may still have a legacy grant pending reconciliation.
                // Keep the recent record until the user explicitly removes it or clears the list.
                return
            }
            handleFolderSelection(url)
            return
        }
        guard let resolvedURL = fileSystemService.resolveSecurityScopedBookmark(bookmarkData) else {
            currentError = .bookmarkResolutionFailed(url)
            return
        }
        if resolvedURL != record.url {
            var records = preferencesService.recentFolderRecords
            if let index = records.firstIndex(where: { $0.url == record.url }) {
                records[index] = RecentFolderRecord(url: resolvedURL, bookmarkData: bookmarkData)
                // Keep the selected grant if the moved destination was already a recent folder.
                records = records.enumerated().filter { offset, entry in
                    offset == index || entry.url.standardizedFileURL != resolvedURL.standardizedFileURL
                }.map(\.element)
                preferencesService.recentFolderRecords = records
                preferencesService.savePreferences()
                loadRecentFolders()
            }
        }
        handleFolderSelection(resolvedURL, accessAlreadyStarted: true)
    }

    /// Remove a folder from the recent folders list
    /// - Parameter url: The folder URL to remove
    func removeRecentFolder(_ url: URL) {
        preferencesService.recentFolderRecords.removeAll { $0.url == url }
        preferencesService.savePreferences()
        loadRecentFolders()
    }

    /// Clear all recent folders
    func clearRecentFolders() {
        preferencesService.clearRecentFolders()
        loadRecentFolders()
    }
    
    /// Cancel the current folder scanning operation.
    /// - Parameter keepingPartialResults: Re-publishes the incomplete snapshot for an explicit user cancel.
    ///   Pass false when a new folder or the welcome screen replaces the scan, so the viewer
    ///   does not jump back to the previous folder.
    func cancelScanning(keepingPartialResults: Bool = true) {
        scanGeneration = UUID()
        scanTask?.cancel()
        // Retain the draining task so a subsequent root waits for its cursor's exit.
        isScanning = false
        scanProgress = 0.0
        if keepingPartialResults, let content = selectedFolderContent, !content.isComplete {
            selectedFolderContent = content
        }
    }
    
    func setIncludeSubfolders(_ included: Bool) {
        guard includeSubfolders != included else { return }
        includeSubfolders = included
        refreshCurrentFolder()
    }

    /// Applies a scope chosen from a control that shows the viewer's loaded scope. A scan canceled
    /// before its first batch can leave this flag ahead of the viewer; rescan instead of doing nothing.
    func applyIncludeSubfolders(_ included: Bool) {
        if includeSubfolders == included {
            refreshCurrentFolder()
        } else {
            setIncludeSubfolders(included)
        }
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
        // A failed bookmark is shown for explicit reauthorization rather than silently
        // destroying a recent entry or shifting another folder's grant into its place.
        recentFolders = preferencesService.recentFolderRecords.map(\.url)
    }

    private func rememberSuccessfulFolder(_ url: URL) {
        var records = preferencesService.recentFolderRecords
        let existing = records.first { $0.url == url }
        records.removeAll { $0.url == url }
        let bookmark = fileSystemService.createSecurityScopedBookmark(for: url) ?? existing?.bookmarkData
        records.insert(RecentFolderRecord(url: url, bookmarkData: bookmark), at: 0)
        preferencesService.recentFolderRecords = Array(records.prefix(10))
        preferencesService.lastSelectedFolder = url
        preferencesService.savePreferences()
        loadRecentFolders()
    }

    private func handleFolderSelection(_ url: URL, accessAlreadyStarted: Bool = false) {
        let previousTask = scanTask
        cancelScanning(keepingPartialResults: false)
        let generation = scanGeneration
        let recursive = includeSubfolders
        let previousContent = selectedFolderURL == url ? selectedFolderContent : nil
        let accessStarted = accessAlreadyStarted || url.startAccessingSecurityScopedResource()
        let fileSystemService = fileSystemService
        let accessManager = accessManager
        isScanning = true
        scanProgress = 0
        imageCount = 0
        currentError = nil

        scanTask = Task { [weak self] in
            var transferredAccess = false
            defer {
                if accessStarted && !transferredAccess { url.stopAccessingSecurityScopedResource() }
            }
            // Normally await a canceled cursor's exit before replacing its root grant. A worker blocked
            // on slow I/O keeps its own grant until it exits, and the generation check discards its
            // results, so it must not stall the next folder indefinitely.
            await Self.awaitPreviousScan(previousTask, timeout: Self.previousScanExitTimeout)
            guard !Task.isCancelled else { return }
            var found: [URL: ImageFile] = [:]
            var folders: Set<URL> = [url]
            var issues: [FolderScanIssue] = []
            var lastPublication = Date.distantPast
            var published = false
            do {
                for try await event in fileSystemService.scanEvents(url, recursive: recursive) {
                    try Task.checkCancellation()
                    guard let self, self.scanGeneration == generation else { return }
                    switch event {
                    case .batch(let images, let discoveredFolders):
                        for image in images { found[image.id] = image }
                        folders.formUnion(discoveredFolders)
                    case .issue(let issue):
                        issues.append(issue)
                    }
                    self.imageCount = found.count
                    // Keep the old usable snapshot during refresh. Reconcile removals only
                    // after completion; newly found revisions override the old records.
                    if Date().timeIntervalSince(lastPublication) >= 0.15 || !published && !found.isEmpty {
                        var snapshot = Dictionary(uniqueKeysWithValues:
                            (previousContent?.imageFiles ?? []).map { ($0.id, $0) })
                        snapshot.merge(found) { _, current in current }
                        if accessManager.currentURL != url {
                            transferredAccess = accessManager.startAccess(for: url)
                        }
                        self.selectedFolderURL = url
                        self.selectedFolderContent = FolderContent(
                            folderURL: url, imageFiles: Array(snapshot.values), includeSubfolders: recursive,
                            discoveredFolders: Array(folders), scanIssues: issues, isComplete: false)
                        lastPublication = Date()
                        published = true
                    }
                }
                try Task.checkCancellation()
                guard let self, self.scanGeneration == generation else { return }
                if accessManager.currentURL != url {
                    transferredAccess = accessManager.startAccess(for: url)
                }
                self.rememberSuccessfulFolder(url)
                self.selectedFolderURL = url
                self.selectedFolderContent = FolderContent(
                    folderURL: url, imageFiles: Array(found.values), includeSubfolders: recursive,
                    discoveredFolders: Array(folders), scanIssues: issues, isComplete: true)
                self.scanProgress = 1
                self.imageCount = found.count
                self.isScanning = false
                self.scanTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.scanGeneration == generation else { return }
                self.isScanning = false
                self.scanProgress = 0
                self.currentError = Self.scanError(error, folderURL: url)
                self.scanTask = nil
            }
        }
    }

    private static let previousScanExitTimeout: Duration = .seconds(1)

    /// Waits for the previous scan task, or for the timeout, whichever comes first.
    private static func awaitPreviousScan(_ task: Task<Void, Never>?, timeout: Duration) async {
        guard let task else { return }
        let gate = ScanWaitGate()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task.detached {
                await task.value
                if gate.claim() { continuation.resume() }
            }
            Task.detached {
                try? await Task.sleep(for: timeout)
                if gate.claim() { continuation.resume() }
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
    func restoreLastFolder(_ folderURL: URL, includeSubfolders: Bool = false) {
        self.includeSubfolders = includeSubfolders
        handleFolderSelection(folderURL)
    }
}

/// Lets exactly one of two racing tasks resume a continuation.
private final class ScanWaitGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.withLock {
            guard !claimed else { return false }
            claimed = true
            return true
        }
    }
}
