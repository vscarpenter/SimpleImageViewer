import UniformTypeIdentifiers

extension UTType {
    /// All image types supported by StillView - Simple Image Viewer
    static let supportedImageTypes: [UTType] = [
        // Primary formats
        .jpeg,
        .png,
        .gif,
        .heif,
        .heic,
        .webP,
        
        // Extended formats
        .tiff,
        .bmp,
        .svg
    ]
    
    /// Check if this UTType represents a supported image format
    var isSupportedImageType: Bool {
        return UTType.supportedImageTypes.contains { supportedType in
            self.conforms(to: supportedType)
        }
    }
    
    /// Check if this UTType represents an animated image format
    var isAnimatedImageType: Bool {
        return self.conforms(to: .gif)
    }
    
    /// Check if this UTType represents a vector image format
    var isVectorImageType: Bool {
        return self.conforms(to: .svg)
    }
    
    /// Check if this UTType represents a high-efficiency format
    var isHighEfficiencyFormat: Bool {
        return self.conforms(to: .heif) || self.conforms(to: .heic) || self.conforms(to: .webP)
    }
    
    /// Get a human-readable description of the image format
    var imageFormatDescription: String {
        switch self {
        case let type where type.conforms(to: .jpeg):
            return "JPEG Image"
        case let type where type.conforms(to: .png):
            return "PNG Image"
        case let type where type.conforms(to: .gif):
            return "GIF Image"
        case let type where type.conforms(to: .heif):
            return "HEIF Image"
        case let type where type.conforms(to: .heic):
            return "HEIC Image"
        case let type where type.conforms(to: .webP):
            return "WebP Image"
        case let type where type.conforms(to: .tiff):
            return "TIFF Image"
        case let type where type.conforms(to: .bmp):
            return "BMP Image"
        case let type where type.conforms(to: .svg):
            return "SVG Image"
        default:
            return localizedDescription ?? "Unknown Image"
        }
    }
    
    /// Get typical file extensions for this image type
    var commonFileExtensions: [String] {
        switch self {
        case let type where type.conforms(to: .jpeg):
            return ["jpg", "jpeg"]
        case let type where type.conforms(to: .png):
            return ["png"]
        case let type where type.conforms(to: .gif):
            return ["gif"]
        case let type where type.conforms(to: .heif):
            return ["heif"]
        case let type where type.conforms(to: .heic):
            return ["heic"]
        case let type where type.conforms(to: .webP):
            return ["webp"]
        case let type where type.conforms(to: .tiff):
            return ["tiff", "tif"]
        case let type where type.conforms(to: .bmp):
            return ["bmp"]
        case let type where type.conforms(to: .svg):
            return ["svg"]
        default:
            return []
        }
    }
}

extension UTType {
    /// Create UTType from file extension string
    /// - Parameter extension: File extension (with or without leading dot)
    /// - Returns: UTType if the extension is recognized, nil otherwise
    static func fromFileExtension(_ extension: String) -> UTType? {
        let cleanExtension = `extension`.hasPrefix(".") ? String(`extension`.dropFirst()) : `extension`
        
        switch cleanExtension.lowercased() {
        case "jpg", "jpeg":
            return .jpeg
        case "png":
            return .png
        case "gif":
            return .gif
        case "heif":
            return .heif
        case "heic":
            return .heic
        case "webp":
            return .webP
        case "tiff", "tif":
            return .tiff
        case "bmp":
            return .bmp
        case "svg":
            return .svg
        default:
            return nil
        }
    }
}