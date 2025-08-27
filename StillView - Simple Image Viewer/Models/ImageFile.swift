import Foundation
import UniformTypeIdentifiers

/// Represents an image file with metadata
struct ImageFile: Identifiable, Equatable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let type: UTType
    let size: Int64
    let creationDate: Date
    let modificationDate: Date
    
    /// Whether this image file is animated (e.g., GIF)
    var isAnimated: Bool {
        return type == .gif
    }
    
    /// Display name without file extension
    var displayName: String {
        return url.deletingPathExtension().lastPathComponent
    }
    
    /// File extension
    var fileExtension: String {
        return url.pathExtension.lowercased()
    }
    
    /// Human-readable file size
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Whether this is a vector image format
    var isVectorImage: Bool {
        return type.isVectorImageType
    }
    
    /// Whether this is a high-efficiency format
    var isHighEfficiencyFormat: Bool {
        return type.isHighEfficiencyFormat
    }
    
    /// Human-readable format description
    var formatDescription: String {
        return type.imageFormatDescription
    }
    
    /// Initialize an ImageFile from a file URL
    /// - Parameter url: The file URL
    /// - Throws: FileSystemError if the file cannot be accessed or is not a supported image
    init(url: URL) throws {
        self.url = url
        self.name = url.lastPathComponent
        
        // Get file attributes
        let resourceValues = try url.resourceValues(forKeys: [
            .contentTypeKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey
        ])
        
        guard let contentType = resourceValues.contentType else {
            let error = NSError(
                domain: "ImageFile",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Could not determine file type"
                ]
            )
            throw FileSystemError.scanningFailed(error)
        }
        
        self.type = contentType
        self.size = Int64(resourceValues.fileSize ?? 0)
        self.creationDate = resourceValues.creationDate ?? Date()
        self.modificationDate = resourceValues.contentModificationDate ?? Date()
        
        // Verify it's a supported image type
        guard Self.isSupportedImageType(contentType) else {
            let error = NSError(
                domain: "ImageFile",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unsupported image type: \(contentType.identifier)"
                ]
            )
            throw FileSystemError.scanningFailed(error)
        }
    }
    
    /// Initialize an ImageFile with all metadata (used for restoring saved state)
    /// - Parameters:
    ///   - url: The file URL
    ///   - name: The file name
    ///   - type: The UTType of the image
    ///   - size: The file size in bytes
    ///   - creationDate: The file creation date
    ///   - modificationDate: The file modification date
    init(url: URL, name: String, type: UTType, size: Int64, creationDate: Date, modificationDate: Date) {
        self.url = url
        self.name = name
        self.type = type
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }
    
    /// Check if a UTType represents a supported image format
    /// - Parameter type: The UTType to check
    /// - Returns: True if the type is supported
    static func isSupportedImageType(_ type: UTType) -> Bool {
        return type.isSupportedImageType
    }
    
    /// Equatable conformance based on URL
    static func == (lhs: ImageFile, rhs: ImageFile) -> Bool {
        return lhs.url == rhs.url
    }
    
    /// Hashable conformance based on URL
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
