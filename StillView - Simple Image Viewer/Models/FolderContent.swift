import Foundation

/// Represents the content of a folder containing images
struct FolderContent: Equatable {
    let folderURL: URL
    let imageFiles: [ImageFile]
    let currentIndex: Int
    
    /// Initialize folder content
    /// - Parameters:
    ///   - folderURL: The URL of the folder
    ///   - imageFiles: Array of image files in the folder
    ///   - currentIndex: The currently selected image index (default: 0)
    init(folderURL: URL, imageFiles: [ImageFile], currentIndex: Int = 0) {
        self.folderURL = folderURL
        self.imageFiles = imageFiles
        self.currentIndex = max(0, min(currentIndex, imageFiles.count - 1))
    }
    
    /// The currently selected image file, if any
    var currentImage: ImageFile? {
        guard !imageFiles.isEmpty && currentIndex >= 0 && currentIndex < imageFiles.count else {
            return nil
        }
        return imageFiles[currentIndex]
    }
    
    /// Total number of images in the folder
    var totalImages: Int {
        return imageFiles.count
    }
    
    /// Whether there are any images in the folder
    var hasImages: Bool {
        return !imageFiles.isEmpty
    }
    
    /// Whether there is a next image available
    var hasNext: Bool {
        return currentIndex < imageFiles.count - 1
    }
    
    /// Whether there is a previous image available
    var hasPrevious: Bool {
        return currentIndex > 0
    }
    
    /// Get the next image index, if available
    var nextIndex: Int? {
        return hasNext ? currentIndex + 1 : nil
    }
    
    /// Get the previous image index, if available
    var previousIndex: Int? {
        return hasPrevious ? currentIndex - 1 : nil
    }
    
    /// Create a new FolderContent with updated current index
    /// - Parameter newIndex: The new index to set
    /// - Returns: New FolderContent instance with updated index
    func withCurrentIndex(_ newIndex: Int) -> FolderContent {
        return FolderContent(
            folderURL: folderURL,
            imageFiles: imageFiles,
            currentIndex: newIndex
        )
    }
    
    /// Get folder name for display
    var folderName: String {
        return folderURL.lastPathComponent
    }
    
    /// Get formatted image counter string (e.g., "5 of 23")
    var imageCounterText: String {
        guard hasImages else { return "No images" }
        return "\(currentIndex + 1) of \(totalImages)"
    }
}