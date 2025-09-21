import SwiftUI
import Combine

/// Coordinates the overall application flow and manages app-level state
@MainActor
class AppCoordinator: ObservableObject {
    @Published var currentView: AppView = .folderSelection
    @Published var selectedFolderURL: URL?
    @Published var showingError: Bool = false
    @Published var currentError: ImageViewerError?
    
    private let preferencesService: PreferencesService
    private let fileSystemService: FileSystemService
    private var cancellables = Set<AnyCancellable>()
    
    enum AppView {
        case folderSelection
        case imageViewer
    }
    
    init(
        preferencesService: PreferencesService = DefaultPreferencesService(),
        fileSystemService: FileSystemService = DefaultFileSystemService()
    ) {
        self.preferencesService = preferencesService
        self.fileSystemService = fileSystemService
        
        setupBindings()
        restoreWindowState()
    }
    
    private func setupBindings() {
        // Listen for folder selection changes
        $selectedFolderURL
            .compactMap { $0 }
            .sink { [weak self] url in
                self?.handleFolderSelection(url)
            }
            .store(in: &cancellables)
    }
    
    private func restoreWindowState() {
        // Window state restoration is handled by WindowAccessor
        // This method can be extended for additional app state restoration
    }
    
    func selectFolder(_ url: URL) {
        selectedFolderURL = url
        preferencesService.addRecentFolder(url)
    }
    
    private func handleFolderSelection(_ url: URL) {
        Task {
            do {
                let imageFiles = try await fileSystemService.scanFolder(url, recursive: false)
                
                if imageFiles.isEmpty {
                    await MainActor.run {
                        showError(.noImagesFound)
                    }
                } else {
                    await MainActor.run {
                        currentView = .imageViewer
                    }
                }
            } catch {
                await MainActor.run {
                    if let imageViewerError = error as? ImageViewerError {
                        showError(imageViewerError)
                    } else {
                        showError(.folderAccessDenied)
                    }
                }
            }
        }
    }
    
    func showError(_ error: ImageViewerError) {
        currentError = error
        showingError = true
    }
    
    func dismissError() {
        showingError = false
        currentError = nil
    }
    
    func returnToFolderSelection() {
        selectedFolderURL = nil
        currentView = .folderSelection
        dismissError()
    }
    
    func handleAppTermination() {
        // Save any final state before app terminates
        // Window state is automatically saved by WindowAccessor
    }
}

/// Extension for handling app lifecycle events
extension AppCoordinator {
    func handleAppDidBecomeActive() {
        // Handle app becoming active
        // Could refresh folder contents if needed
    }
    
    func handleAppWillResignActive() {
        // Handle app becoming inactive
        // Could pause any ongoing operations
    }

    func handleAppWillTerminate() {
        handleAppTermination()
    }
}