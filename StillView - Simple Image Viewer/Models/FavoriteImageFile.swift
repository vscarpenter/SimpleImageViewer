import Foundation
import UniformTypeIdentifiers

/// Represents a favorited image file with metadata for persistence
struct FavoriteImageFile: Codable, Identifiable, Equatable {
    let id: UUID
    let originalURL: URL
    let name: String
    let dateAdded: Date
    let fileSize: Int64
    let imageType: String
    let lastValidated: Date
    
    /// Initialize from an existing ImageFile
    /// - Parameter imageFile: The ImageFile to create a favorite from
    init(from imageFile: ImageFile) {
        self.id = UUID()
        self.originalURL = imageFile.url
        self.name = imageFile.name
        self.dateAdded = Date()
        self.fileSize = imageFile.size
        self.imageType = imageFile.type.identifier
        self.lastValidated = Date()
    }
    
    /// Convert back to ImageFile if the original file still exists
    /// - Returns: ImageFile if the file exists and is valid, nil otherwise
    /// - Throws: FileSystemError if file access fails
    func toImageFile() throws -> ImageFile? {
        print("DEBUG: FavoriteImageFile.toImageFile() - Converting \(name) at \(originalURL.path)")
        
        // Check if file exists at original path
        guard FileManager.default.fileExists(atPath: originalURL.path) else {
            print("DEBUG: FavoriteImageFile.toImageFile() - File does not exist: \(originalURL.path)")
            return nil
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: originalURL.path) else {
            print("DEBUG: FavoriteImageFile.toImageFile() - File is not readable: \(originalURL.path)")
            return nil
        }
        
        print("DEBUG: FavoriteImageFile.toImageFile() - File exists and is readable, creating ImageFile with stored metadata")
        
        // Use stored metadata directly to avoid file system metadata reading issues
        // This is more reliable than trying to re-read metadata from the file system
        let utType = UTType(imageType) ?? .image
        
        // Get current file size (fallback to stored if reading fails)
        var currentFileSize = fileSize
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: originalURL.path)
            currentFileSize = attributes[.size] as? Int64 ?? fileSize
        } catch {
            print("DEBUG: FavoriteImageFile.toImageFile() - Could not read current file size, using stored: \(fileSize)")
        }
        
        // Create ImageFile using stored metadata
        let imageFile = ImageFile(
            url: originalURL,
            name: name,
            type: utType,
            size: currentFileSize,
            creationDate: dateAdded,
            modificationDate: lastValidated
        )
        
        print("DEBUG: FavoriteImageFile.toImageFile() - Successfully created ImageFile using stored metadata for \(name)")
        return imageFile
    }
    
    /// Check if the favorited file still exists and is accessible
    /// - Returns: True if the file exists and is accessible
    var isValid: Bool {
        let fileManager = FileManager.default
        
        // Check basic existence
        guard fileManager.fileExists(atPath: originalURL.path) else {
            return false
        }
        
        // Check readability
        guard fileManager.isReadableFile(atPath: originalURL.path) else {
            return false
        }
        
        return true
    }
    
    /// Perform comprehensive validation including image format verification
    /// - Returns: ValidationResult indicating the status and any issues
    func validateComprehensively() async -> ValidationResult {
        let fileManager = FileManager.default
        
        // Check basic existence
        guard fileManager.fileExists(atPath: originalURL.path) else {
            return .invalid(.fileNotFound)
        }
        
        // Check readability
        guard fileManager.isReadableFile(atPath: originalURL.path) else {
            return .invalid(.permissionDenied)
        }
        
        // Check if it's still a valid image file
        do {
            _ = try ImageFile(url: originalURL)
            return .valid
        } catch {
            return .invalid(.invalidImageFormat)
        }
    }
    
    /// Result of comprehensive validation
    enum ValidationResult {
        case valid
        case invalid(ValidationError)
        
        var isValid: Bool {
            switch self {
            case .valid:
                return true
            case .invalid:
                return false
            }
        }
    }
    
    /// Specific validation errors
    enum ValidationError {
        case fileNotFound
        case permissionDenied
        case invalidImageFormat
        case networkUnavailable
        
        var localizedDescription: String {
            switch self {
            case .fileNotFound:
                return "File not found"
            case .permissionDenied:
                return "Permission denied"
            case .invalidImageFormat:
                return "Invalid image format"
            case .networkUnavailable:
                return "Network unavailable"
            }
        }
    }
    
    /// Update the last validated timestamp
    /// - Returns: A new FavoriteImageFile with updated validation timestamp
    func updatingValidation() -> FavoriteImageFile {
        return FavoriteImageFile(
            id: self.id,
            originalURL: self.originalURL,
            name: self.name,
            dateAdded: self.dateAdded,
            fileSize: self.fileSize,
            imageType: self.imageType,
            lastValidated: Date()
        )
    }
    
    /// Private initializer for internal use (validation updates)
    private init(id: UUID, originalURL: URL, name: String, dateAdded: Date, fileSize: Int64, imageType: String, lastValidated: Date) {
        self.id = id
        self.originalURL = originalURL
        self.name = name
        self.dateAdded = dateAdded
        self.fileSize = fileSize
        self.imageType = imageType
        self.lastValidated = lastValidated
    }
    
    /// Equatable conformance based on original URL
    static func == (lhs: FavoriteImageFile, rhs: FavoriteImageFile) -> Bool {
        return lhs.originalURL == rhs.originalURL
    }
}