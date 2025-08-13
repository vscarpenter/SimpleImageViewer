import Foundation
import Combine

/// Protocol defining the favorites management service
@MainActor
protocol FavoritesService: ObservableObject {
    /// All currently favorited images
    var favoriteImages: [FavoriteImageFile] { get }
    
    /// Publisher for favorite images changes
    var favoriteImagesPublisher: Published<[FavoriteImageFile]>.Publisher { get }
    
    /// Add an image to favorites
    /// - Parameter imageFile: The image file to add to favorites
    /// - Returns: True if successfully added, false if already favorited or failed
    func addToFavorites(_ imageFile: ImageFile) -> Bool
    
    /// Remove an image from favorites
    /// - Parameter imageFile: The image file to remove from favorites
    /// - Returns: True if successfully removed, false if not favorited or failed
    func removeFromFavorites(_ imageFile: ImageFile) -> Bool
    
    /// Check if an image is favorited
    /// - Parameter imageFile: The image file to check
    /// - Returns: True if the image is in favorites
    func isFavorite(_ imageFile: ImageFile) -> Bool
    
    /// Validate and clean up broken favorites
    /// Removes favorites that no longer exist or are inaccessible
    /// - Parameter showNotification: Whether to show user notification for cleanup results
    /// - Returns: Number of favorites that were removed during cleanup
    @discardableResult
    func validateFavorites(showNotification: Bool) async -> Int
    
    /// Perform comprehensive validation on app launch
    /// Includes batch processing and user notifications
    func validateFavoritesOnAppLaunch() async
    
    /// Manual refresh of favorites validation
    /// Provides immediate feedback to user
    func refreshFavoritesValidation() async
    
    /// Get all valid favorites as ImageFile array
    /// - Returns: Array of ImageFile objects for all valid favorites
    func getValidFavorites() async -> [ImageFile]
    
    /// Remove multiple images from favorites in batch
    /// - Parameter imageFiles: Array of image files to remove from favorites
    /// - Returns: Number of successfully removed favorites
    @discardableResult
    func batchRemoveFromFavorites(_ imageFiles: [ImageFile]) -> Int
    
    /// Clear all favorites
    func clearAllFavorites()
}

/// Default implementation of FavoritesService
@MainActor
final class DefaultFavoritesService: FavoritesService {
    static let shared = DefaultFavoritesService(
        preferencesService: DefaultPreferencesService.shared,
        errorHandlingService: ErrorHandlingService.shared
    )
    
    @Published private(set) var favoriteImages: [FavoriteImageFile] = []
    
    var favoriteImagesPublisher: Published<[FavoriteImageFile]>.Publisher {
        $favoriteImages
    }
    
    private let preferencesService: PreferencesService
    private let fileManager = FileManager.default
    private let errorHandlingService: ErrorHandlingService
    
    /// Batch size for processing favorites during validation
    private let validationBatchSize = 10
    
    /// Initialize with preferences service for persistence
    /// - Parameters:
    ///   - preferencesService: Service for storing favorites data
    ///   - errorHandlingService: Service for showing user notifications
    init(preferencesService: PreferencesService, errorHandlingService: ErrorHandlingService = ErrorHandlingService.shared) {
        self.preferencesService = preferencesService
        self.errorHandlingService = errorHandlingService
        loadFavorites()
    }
    
    func addToFavorites(_ imageFile: ImageFile) -> Bool {
        // Check if already favorited
        guard !isFavorite(imageFile) else {
            print("DEBUG: DefaultFavoritesService.addToFavorites() - Image already favorited: \(imageFile.name)")
            return false
        }
        
        let favoriteImage = FavoriteImageFile(from: imageFile)
        favoriteImages.append(favoriteImage)
        print("DEBUG: DefaultFavoritesService.addToFavorites() - Added favorite: \(imageFile.name), total count: \(favoriteImages.count)")
        
        // Ensure security-scoped access is maintained for this folder
        let folderURL = imageFile.url.deletingLastPathComponent()
        SecurityScopedAccessManager.shared.addFavoriteFolder(folderURL)
        
        saveFavorites()
        return true
    }
    
    func removeFromFavorites(_ imageFile: ImageFile) -> Bool {
        let initialCount = favoriteImages.count
        let folderURL = imageFile.url.deletingLastPathComponent()
        
        favoriteImages.removeAll { $0.originalURL == imageFile.url }
        
        if favoriteImages.count < initialCount {
            // Check if there are any remaining favorites in this folder
            let hasFavoritesInFolder = favoriteImages.contains { favorite in
                favorite.originalURL.deletingLastPathComponent() == folderURL
            }
            
            // If no more favorites in this folder, remove security-scoped access
            if !hasFavoritesInFolder {
                SecurityScopedAccessManager.shared.removeFavoriteFolder(folderURL)
            }
            
            saveFavorites()
            return true
        }
        return false
    }
    
    func isFavorite(_ imageFile: ImageFile) -> Bool {
        return favoriteImages.contains { $0.originalURL == imageFile.url }
    }
    
    @discardableResult
    func validateFavorites(showNotification: Bool = false) async -> Int {
        var validFavorites: [FavoriteImageFile] = []
        var removedCount = 0
        var removedFiles: [String] = []
        
        // Process favorites in batches to avoid blocking UI
        let batches = favoriteImages.chunked(into: validationBatchSize)
        
        for batch in batches {
            await withTaskGroup(of: (FavoriteImageFile?, String?).self) { group in
                for favorite in batch {
                    group.addTask {
                        await self.validateSingleFavorite(favorite)
                    }
                }
                
                for await result in group {
                    if let validFavorite = result.0 {
                        validFavorites.append(validFavorite)
                    } else if let removedFileName = result.1 {
                        removedCount += 1
                        removedFiles.append(removedFileName)
                    }
                }
            }
            
            // Small delay between batches to maintain UI responsiveness
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        // Update favorites list if any were removed
        if removedCount > 0 {
            self.favoriteImages = validFavorites
            self.saveFavorites()
            
            if showNotification {
                await showCleanupNotification(removedCount: removedCount, removedFiles: removedFiles)
            }
        }
        
        return removedCount
    }
    
    func validateFavoritesOnAppLaunch() async {
        guard !favoriteImages.isEmpty else { return }
        
        let removedCount = await validateFavorites(showNotification: false)
        
        // Show notification only if favorites were cleaned up
        if removedCount > 0 {
            await MainActor.run {
                errorHandlingService.showNotification("Cleaned up \(removedCount) unavailable favorite\(removedCount == 1 ? "" : "s")", type: .info)
            }
        }
    }
    
    func refreshFavoritesValidation() async {
        guard !favoriteImages.isEmpty else {
            await MainActor.run {
                errorHandlingService.showNotification("No favorites to validate", type: .info)
            }
            return
        }
        
        await MainActor.run {
            errorHandlingService.showNotification("Validating favorites...", type: .info)
        }
        
        let removedCount = await validateFavorites(showNotification: true)
        
        if removedCount == 0 {
            await MainActor.run {
                errorHandlingService.showNotification("All favorites are valid", type: .success)
            }
        }
    }
    
    func getValidFavorites() async -> [ImageFile] {
        var validImageFiles: [ImageFile] = []
        
        for favorite in favoriteImages {
            do {
                if let imageFile = try favorite.toImageFile() {
                    validImageFiles.append(imageFile)
                }
            } catch {
                // Skip invalid files - they'll be cleaned up in validateFavorites
                continue
            }
        }
        
        return validImageFiles
    }
    
    @discardableResult
    func batchRemoveFromFavorites(_ imageFiles: [ImageFile]) -> Int {
        let initialCount = favoriteImages.count
        let urlsToRemove = Set(imageFiles.map { $0.url })
        
        favoriteImages.removeAll { urlsToRemove.contains($0.originalURL) }
        
        let removedCount = initialCount - favoriteImages.count
        
        if removedCount > 0 {
            saveFavorites()
        }
        
        return removedCount
    }
    
    func clearAllFavorites() {
        favoriteImages.removeAll()
        saveFavorites()
    }
    
    // MARK: - Private Methods
    
    private func loadFavorites() {
        favoriteImages = preferencesService.favoriteImages
        print("DEBUG: DefaultFavoritesService.loadFavorites() - Loaded \(favoriteImages.count) favorites from preferences")
        
        // Restore security-scoped access for folders containing favorites
        let favoriteFolders = Set(favoriteImages.map { $0.originalURL.deletingLastPathComponent() })
        for folderURL in favoriteFolders {
            SecurityScopedAccessManager.shared.addFavoriteFolder(folderURL)
        }
    }
    
    nonisolated private func saveFavorites() {
        Task { @MainActor in
            preferencesService.updateFavorites(favoriteImages)
            preferencesService.saveFavorites()
            print("DEBUG: DefaultFavoritesService.saveFavorites() - Saved \(favoriteImages.count) favorites to preferences")
        }
    }
    
    /// Validate a single favorite file with comprehensive error handling
    /// - Parameter favorite: The favorite to validate
    /// - Returns: Tuple of (valid favorite with updated timestamp, removed file name)
    private func validateSingleFavorite(_ favorite: FavoriteImageFile) async -> (FavoriteImageFile?, String?) {
        // Check basic file existence
        guard fileManager.fileExists(atPath: favorite.originalURL.path) else {
            return (nil, favorite.name)
        }
        
        // Check file accessibility and permissions
        guard fileManager.isReadableFile(atPath: favorite.originalURL.path) else {
            return (nil, favorite.name)
        }
        
        // Handle network drives and external volumes
        if await isNetworkOrExternalVolume(favorite.originalURL) {
            // For network drives, try to access the file to verify connectivity
            do {
                // Try to access the file to verify connectivity
                _ = try favorite.originalURL.checkResourceIsReachable()
                // If we get here, the file is reachable
            } catch {
                // If we can't determine reachability, assume it's unavailable
                return (nil, favorite.name)
            }
        }
        
        // For validation, we only need to check if the file exists and is readable
        // We don't need to validate the ImageFile creation here since toImageFile() handles that
        return (favorite.updatingValidation(), nil)
    }
    
    /// Check if a URL points to a network drive or external volume
    /// - Parameter url: The URL to check
    /// - Returns: True if the URL is on a network drive or external volume
    private func isNetworkOrExternalVolume(_ url: URL) async -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .volumeIsLocalKey,
                .volumeIsInternalKey,
                .volumeIsRemovableKey
            ])
            
            // Consider it network/external if it's not local, not internal, or is removable
            let isLocal = resourceValues.volumeIsLocal ?? true
            let isInternal = resourceValues.volumeIsInternal ?? true
            let isRemovable = resourceValues.volumeIsRemovable ?? false
            
            return !isLocal || !isInternal || isRemovable
        } catch {
            // If we can't determine volume properties, assume it's local
            return false
        }
    }
    
    /// Show notification about cleanup results
    /// - Parameters:
    ///   - removedCount: Number of favorites removed
    ///   - removedFiles: Names of removed files
    private func showCleanupNotification(removedCount: Int, removedFiles: [String]) async {
        await MainActor.run {
            if removedCount == 1 {
                errorHandlingService.showNotification("Removed 1 unavailable favorite: \(removedFiles.first ?? "Unknown")", type: .warning)
            } else if removedCount <= 3 {
                let fileList = removedFiles.prefix(3).joined(separator: ", ")
                errorHandlingService.showNotification("Removed \(removedCount) unavailable favorites: \(fileList)", type: .warning)
            } else {
                errorHandlingService.showNotification("Removed \(removedCount) unavailable favorites", type: .warning)
            }
        }
    }
}

// MARK: - Array Extension for Batching

private extension Array {
    /// Split array into chunks of specified size
    /// - Parameter size: The maximum size of each chunk
    /// - Returns: Array of chunks
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}