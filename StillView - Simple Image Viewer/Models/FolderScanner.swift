import Foundation
import Combine
import UniformTypeIdentifiers

/// Handles scanning folders for image files
class FolderScanner: ObservableObject {
    @Published var imageFiles: [ImageFile] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Supported image file types
    private let supportedTypes: [UTType] = [
        .jpeg, .png, .gif, .heif, .heic, .webP, .tiff, .bmp, .svg
    ]
    
    /// Scan a folder for supported image files
    /// - Parameters:
    ///   - url: The folder URL to scan
    ///   - recursive: Whether to scan subfolders recursively
    /// - Returns: Array of ImageFile objects found in the folder
    func scanFolder(_ url: URL, recursive: Bool = false) async throws -> [ImageFile] {
        // Implementation will be added in a later task
        return []
    }
    
    /// Check if a file URL represents a supported image format
    /// - Parameter url: The file URL to check
    /// - Returns: True if the file is a supported image format
    func isSupportedImageFile(_ url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }
        return ImageFile.isSupportedImageType(type)
    }
}