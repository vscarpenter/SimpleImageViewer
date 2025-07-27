import Foundation
import ImageIO
import CoreLocation

/// Service for extracting and managing image metadata for accessibility descriptions
class ImageMetadataService {
    
    // MARK: - Data Models
    
    /// Comprehensive image metadata for accessibility descriptions
    struct ImageMetadata {
        let fileName: String
        let fileSize: String
        let dimensions: String
        let colorSpace: String?
        let camera: CameraInfo?
        let location: LocationInfo?
        let captureDate: Date?
        let description: String?
        let keywords: [String]
        
        /// Generate accessibility description from metadata
        var accessibilityDescription: String {
            var components: [String] = []
            
            // Basic file info
            components.append("Image: \(fileName)")
            components.append("Dimensions: \(dimensions)")
            
            // File size if significant
            if !fileSize.isEmpty {
                components.append("Size: \(fileSize)")
            }
            
            // Camera information
            if let camera = camera {
                var cameraDesc = "Captured"
                if !camera.make.isEmpty && !camera.model.isEmpty {
                    cameraDesc += " with \(camera.make) \(camera.model)"
                }
                if let settings = camera.settings {
                    cameraDesc += ", \(settings)"
                }
                components.append(cameraDesc)
            }
            
            // Date information
            if let date = captureDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                components.append("Taken on \(formatter.string(from: date))")
            }
            
            // Location information
            if let location = location {
                components.append("Location: \(location.description)")
            }
            
            // Keywords/tags
            if !keywords.isEmpty {
                components.append("Tags: \(keywords.joined(separator: ", "))")
            }
            
            // Custom description
            if let description = description, !description.isEmpty {
                components.append("Description: \(description)")
            }
            
            // Color space for technical users
            if let colorSpace = colorSpace {
                components.append("Color space: \(colorSpace)")
            }
            
            return components.joined(separator: ". ")
        }
    }
    
    /// Camera-specific metadata
    struct CameraInfo {
        let make: String
        let model: String
        let settings: String?
        
        init(make: String = "", model: String = "", settings: String? = nil) {
            self.make = make
            self.model = model
            self.settings = settings
        }
    }
    
    /// Location metadata
    struct LocationInfo {
        let latitude: Double
        let longitude: Double
        let altitude: Double?
        let description: String
        
        init(latitude: Double, longitude: Double, altitude: Double? = nil) {
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
            
            // Create human-readable location description
            let latDirection = latitude >= 0 ? "N" : "S"
            let lonDirection = longitude >= 0 ? "E" : "W"
            let latString = String(format: "%.2f°%@", abs(latitude), latDirection)
            let lonString = String(format: "%.2f°%@", abs(longitude), lonDirection)
            
            var desc = "\(latString), \(lonString)"
            if let alt = altitude {
                desc += ", altitude \(Int(alt))m"
            }
            self.description = desc
        }
    }
    
    // MARK: - Public Methods
    
    /// Extract comprehensive metadata from an image file
    /// - Parameter url: URL of the image file
    /// - Returns: ImageMetadata object with extracted information
    func extractMetadata(from url: URL) -> ImageMetadata {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return createBasicMetadata(for: url)
        }
        
        // Get basic file information
        let fileName = url.lastPathComponent
        let fileSize = formatFileSize(url: url)
        
        // Get image properties
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return createBasicMetadata(for: url, fileName: fileName, fileSize: fileSize)
        }
        
        // Extract dimensions
        let dimensions = extractDimensions(from: properties)
        
        // Extract color space
        let colorSpace = extractColorSpace(from: properties)
        
        // Extract EXIF data
        let camera = extractCameraInfo(from: properties)
        
        // Extract GPS data
        let location = extractLocationInfo(from: properties)
        
        // Extract date
        let captureDate = extractCaptureDate(from: properties)
        
        // Extract description and keywords
        let description = extractDescription(from: properties)
        let keywords = extractKeywords(from: properties)
        
        return ImageMetadata(
            fileName: fileName,
            fileSize: fileSize,
            dimensions: dimensions,
            colorSpace: colorSpace,
            camera: camera,
            location: location,
            captureDate: captureDate,
            description: description,
            keywords: keywords
        )
    }
    
    // MARK: - Private Methods
    
    private func createBasicMetadata(for url: URL, fileName: String? = nil, fileSize: String? = nil) -> ImageMetadata {
        return ImageMetadata(
            fileName: fileName ?? url.lastPathComponent,
            fileSize: fileSize ?? formatFileSize(url: url),
            dimensions: "Unknown dimensions",
            colorSpace: nil,
            camera: nil,
            location: nil,
            captureDate: nil,
            description: nil,
            keywords: []
        )
    }
    
    private func formatFileSize(url: URL) -> String {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let fileSize = resources.fileSize else { return "" }
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(fileSize))
        } catch {
            return ""
        }
    }
    
    private func extractDimensions(from properties: [String: Any]) -> String {
        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        
        if width > 0 && height > 0 {
            let megapixels = Double(width * height) / 1_000_000
            if megapixels >= 1.0 {
                return String(format: "%d × %d pixels (%.1f MP)", width, height, megapixels)
            } else {
                return "\(width) × \(height) pixels"
            }
        }
        
        return "Unknown dimensions"
    }
    
    private func extractColorSpace(from properties: [String: Any]) -> String? {
        if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
            switch colorModel {
            case String(kCGImagePropertyColorModelRGB):
                return "RGB"
            case String(kCGImagePropertyColorModelGray):
                return "Grayscale"
            case String(kCGImagePropertyColorModelCMYK):
                return "CMYK"
            case String(kCGImagePropertyColorModelLab):
                return "Lab"
            default:
                return colorModel
            }
        }
        return nil
    }
    
    private func extractCameraInfo(from properties: [String: Any]) -> CameraInfo? {
        guard let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
            return nil
        }
        
        let make = properties[kCGImagePropertyTIFFDictionary as String].flatMap { dict in
            (dict as? [String: Any])?[kCGImagePropertyTIFFMake as String] as? String
        } ?? ""
        
        let model = properties[kCGImagePropertyTIFFDictionary as String].flatMap { dict in
            (dict as? [String: Any])?[kCGImagePropertyTIFFModel as String] as? String
        } ?? ""
        
        // Extract camera settings
        var settings: [String] = []
        
        if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? Double {
            settings.append(String(format: "f/%.1f", fNumber))
        }
        
        if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? Double {
            if exposureTime < 1 {
                settings.append(String(format: "1/%.0f s", 1/exposureTime))
            } else {
                settings.append(String(format: "%.1f s", exposureTime))
            }
        }
        
        if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let isoValue = iso.first {
            settings.append("ISO \(isoValue)")
        }
        
        if let focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double {
            settings.append(String(format: "%.0fmm", focalLength))
        }
        
        let settingsString = settings.isEmpty ? nil : settings.joined(separator: ", ")
        
        return CameraInfo(make: make, model: model, settings: settingsString)
    }
    
    private func extractLocationInfo(from properties: [String: Any]) -> LocationInfo? {
        guard let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }
        
        guard let latValue = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let lonValue = gps[kCGImagePropertyGPSLongitude as String] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String else {
            return nil
        }
        
        let latitude = latRef == "S" ? -latValue : latValue
        let longitude = lonRef == "W" ? -lonValue : lonValue
        let altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double
        
        return LocationInfo(latitude: latitude, longitude: longitude, altitude: altitude)
    }
    
    private func extractCaptureDate(from properties: [String: Any]) -> Date? {
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            return formatter.date(from: dateString)
        }
        
        // Try TIFF date as fallback
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let dateString = tiff[kCGImagePropertyTIFFDateTime as String] as? String {
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            return formatter.date(from: dateString)
        }
        
        return nil
    }
    
    private func extractDescription(from properties: [String: Any]) -> String? {
        // Try various description fields
        if let iptc = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
            if let caption = iptc[kCGImagePropertyIPTCCaptionAbstract as String] as? String, !caption.isEmpty {
                return caption
            }
        }
        
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let description = tiff[kCGImagePropertyTIFFImageDescription as String] as? String, !description.isEmpty {
                return description
            }
        }
        
        return nil
    }
    
    private func extractKeywords(from properties: [String: Any]) -> [String] {
        if let iptc = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any],
           let keywords = iptc[kCGImagePropertyIPTCKeywords as String] as? [String] {
            return keywords.filter { !$0.isEmpty }
        }
        
        return []
    }
}