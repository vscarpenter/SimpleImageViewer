import Foundation
import Combine
import SwiftUI
import AppKit

/// ViewModel for managing favorites-specific state and operations
@MainActor
final class FavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Array of favorite image files for display (accessible ones only)
    @Published private(set) var favoriteImageFiles: [ImageFile] = []
    
    /// Array of inaccessible favorites (for showing in UI with re-access option)
    @Published private(set) var inaccessibleFavorites: [FavoriteImageFile] = []
    
    /// Currently selected favorite image
    @Published var selectedFavoriteImage: ImageFile?
    
    /// Whether favorites are currently being loaded/validated
    @Published private(set) var isLoading: Bool = false
    
    /// Current error state, if any
    @Published var currentError: ImageViewerError?
    
    /// Whether there are any favorites available (accessible or inaccessible)
    var hasFavorites: Bool {
        return !favoriteImageFiles.isEmpty || !inaccessibleFavorites.isEmpty
    }
    
    /// Whether there are accessible favorites
    var hasAccessibleFavorites: Bool {
        return !favoriteImageFiles.isEmpty
    }
    
    /// Whether there are inaccessible favorites that could be re-granted access
    var hasInaccessibleFavorites: Bool {
        return !inaccessibleFavorites.isEmpty
    }
    
    // MARK: - Private Properties
    
    private let favoritesService: any FavoritesService
    private let errorHandlingService: ErrorHandlingService
    private var cancellables = Set<AnyCancellable>()
    private var isCurrentlyLoading = false
    
    // MARK: - Initialization
    
    /// Initialize with required services
    /// - Parameters:
    ///   - favoritesService: Service for managing favorites
    ///   - errorHandlingService: Service for handling errors
    init(favoritesService: (any FavoritesService)? = nil,
         errorHandlingService: ErrorHandlingService = ErrorHandlingService.shared) {
        self.favoritesService = favoritesService ?? DefaultFavoritesService.shared
        self.errorHandlingService = errorHandlingService
        
        setupBindings()
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    /// Load and validate all favorites
    func loadFavorites() {
        // Prevent multiple simultaneous loads
        guard !isCurrentlyLoading else {
            print("DEBUG: FavoritesViewModel.loadFavorites() - Already loading, skipping")
            return
        }
        
        print("DEBUG: FavoritesViewModel.loadFavorites() - Starting load")
        isCurrentlyLoading = true
        isLoading = true
        currentError = nil
        
        Task {
            do {
                // Get raw favorites from service
                let rawFavorites = favoritesService.favoriteImages
                print("DEBUG: FavoritesViewModel.loadFavorites() - Raw favorites count: \(rawFavorites.count)")
                
                // Separate accessible from inaccessible favorites
                var accessibleFavorites: [ImageFile] = []
                var inaccessibleFavoritesList: [FavoriteImageFile] = []
                
                for (index, favorite) in rawFavorites.enumerated() {
                    print("DEBUG: FavoritesViewModel.loadFavorites() - Processing favorite \(index + 1): \(favorite.name)")
                    do {
                        if let imageFile = try favorite.toImageFile() {
                            accessibleFavorites.append(imageFile)
                            print("DEBUG: FavoritesViewModel.loadFavorites() - Successfully converted favorite \(index + 1): \(favorite.name)")
                        } else {
                            print("DEBUG: FavoritesViewModel.loadFavorites() - Inaccessible favorite \(index + 1): \(favorite.name)")
                            inaccessibleFavoritesList.append(favorite)
                        }
                    } catch {
                        print("DEBUG: FavoritesViewModel.loadFavorites() - Error converting favorite \(index + 1): \(favorite.name) - \(error)")
                        inaccessibleFavoritesList.append(favorite)
                        continue
                    }
                }
                
                print("DEBUG: FavoritesViewModel.loadFavorites() - Accessible favorites: \(accessibleFavorites.count), Inaccessible: \(inaccessibleFavoritesList.count)")
                
                // Ensure UI update happens on main thread with explicit objectWillChange notification
                await MainActor.run {
                    print("DEBUG: FavoritesViewModel.loadFavorites() - About to update favorites on main thread")
                    self.objectWillChange.send()
                    self.favoriteImageFiles = accessibleFavorites
                    self.inaccessibleFavorites = inaccessibleFavoritesList
                    self.isCurrentlyLoading = false
                    self.isLoading = false
                    print("DEBUG: FavoritesViewModel.loadFavorites() - Set accessible favorites: \(self.favoriteImageFiles.count), inaccessible: \(self.inaccessibleFavorites.count)")
                }
            }
        }
    }
    
    /// Refresh favorites by reloading and validating with user feedback
    func refreshFavorites() {
        isLoading = true
        currentError = nil
        
        Task {
            // Use manual refresh validation which provides user feedback
            await favoritesService.refreshFavoritesValidation()
            
            // Get valid favorites as ImageFile array
            let validFavorites = await favoritesService.getValidFavorites()
            
            await MainActor.run {
                self.favoriteImageFiles = validFavorites
                self.isLoading = false
            }
        }
    }
    
    /// Select a favorite image
    /// - Parameter imageFile: The image file to select
    func selectFavorite(_ imageFile: ImageFile) {
        selectedFavoriteImage = imageFile
    }
    
    /// Remove an image from favorites
    /// - Parameter imageFile: The image file to remove from favorites
    func removeFromFavorites(_ imageFile: ImageFile) {
        let success = favoritesService.removeFromFavorites(imageFile)
        
        if success {
            // Remove from local array immediately for responsive UI
            favoriteImageFiles.removeAll { $0.url == imageFile.url }
            
            // Clear selection if the removed image was selected
            if selectedFavoriteImage?.url == imageFile.url {
                selectedFavoriteImage = nil
            }
            
            // Show success notification
            errorHandlingService.showNotification(
                "Removed from favorites",
                type: .success
            )
        } else {
            // Show error notification
            errorHandlingService.showNotification(
                "Failed to remove from favorites",
                type: .error
            )
        }
    }
    
    /// Remove multiple images from favorites in batch
    /// - Parameter imageFiles: Array of image files to remove from favorites
    /// - Returns: Number of successfully removed favorites
    @discardableResult
    func batchRemoveFromFavorites(_ imageFiles: [ImageFile]) -> Int {
        guard !imageFiles.isEmpty else {
            errorHandlingService.showNotification("No favorites selected for removal", type: .info)
            return 0
        }
        
        // Use the service's batch removal method for better performance
        let successCount = favoritesService.batchRemoveFromFavorites(imageFiles)
        
        // Update local array to reflect changes immediately for responsive UI
        let urlsToRemove = Set(imageFiles.map { $0.url })
        favoriteImageFiles.removeAll { urlsToRemove.contains($0.url) }
        
        // Clear selection if any removed image was selected
        if let selectedImage = selectedFavoriteImage,
           urlsToRemove.contains(selectedImage.url) {
            selectedFavoriteImage = nil
        }
        
        // Show appropriate notification based on results
        if successCount == imageFiles.count {
            // All succeeded
            let message = successCount == 1 ? "Removed 1 favorite" : "Removed \(successCount) favorites"
            errorHandlingService.showNotification(message, type: .success)
        } else if successCount > 0 {
            // Partial success
            let failedCount = imageFiles.count - successCount
            let message = "Removed \(successCount) of \(imageFiles.count) favorites (\(failedCount) failed)"
            errorHandlingService.showNotification(message, type: .warning)
        } else {
            // All failed
            errorHandlingService.showNotification("Failed to remove any favorites", type: .error)
        }
        
        return successCount
    }
    
    /// Remove all favorites with confirmation
    /// - Returns: Number of favorites that were removed
    @discardableResult
    func removeAllFavorites() -> Int {
        let allFavorites = favoriteImageFiles
        guard !allFavorites.isEmpty else {
            errorHandlingService.showNotification("No favorites to remove", type: .info)
            return 0
        }
        
        let removedCount = batchRemoveFromFavorites(allFavorites)
        
        if removedCount == allFavorites.count {
            errorHandlingService.showNotification("All favorites removed", type: .success)
        }
        
        return removedCount
    }
    
    /// Clear the current error state
    func clearError() {
        currentError = nil
    }
    
    /// Create a FolderContent object for favorites to enable navigation
    /// - Returns: FolderContent representing the favorites collection
    func createFavoritesContent() -> FolderContent? {
        guard !favoriteImageFiles.isEmpty else { return nil }
        
        // Create a virtual folder URL for favorites
        let favoritesURL = URL(string: "favorites://")!
        
        return FolderContent(folderURL: favoritesURL, imageFiles: favoriteImageFiles)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Listen for changes in favorites service
        favoritesService.favoriteImagesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Reload favorites when the service data changes
                self?.loadFavorites()
            }
            .store(in: &cancellables)
    }
    
    /// Request user to grant access to a folder containing inaccessible favorites
    /// - Parameter folderPath: The folder path to request access for
    func requestAccessToFolder(_ folderPath: String) {
        Task {
            // Use NSOpenPanel to let user grant access to the folder
            let openPanel = NSOpenPanel()
            openPanel.title = "Grant Access to Folder"
            openPanel.message = "Select the folder '\(URL(fileURLWithPath: folderPath).lastPathComponent)' to access your favorites from this location."
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.directoryURL = URL(fileURLWithPath: folderPath)
            
            let response = await openPanel.begin()
            if response == .OK, let selectedURL = openPanel.url {
                // Start security-scoped access for the selected folder
                _ = SecurityScopedAccessManager.shared.startAccess(for: selectedURL)
                
                // Reload favorites to check if any previously inaccessible ones are now accessible
                await MainActor.run {
                    self.loadFavorites()
                }
            }
        }
    }
}

// MARK: - ImageViewerError Extension

extension ImageViewerError {
    /// Error for favorites loading failures
    static func favoritesLoadingFailed(_ underlyingError: Error) -> ImageViewerError {
        return .folderScanningFailed(underlyingError)
    }
}