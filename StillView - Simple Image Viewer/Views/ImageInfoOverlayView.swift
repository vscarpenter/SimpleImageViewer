import SwiftUI
import Foundation

/// Overlay view displaying image metadata and file information
struct ImageInfoOverlayView: View {
    let imageFile: ImageFile
    let currentImage: NSImage?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let metadataService = ImageMetadataService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Image Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            // File Information
            VStack(alignment: .leading, spacing: 4) {
                InfoRow(label: "File Name", value: imageFile.displayName)
                InfoRow(label: "File Size", value: formatFileSize(imageFile.size))
                InfoRow(label: "Dimensions", value: imageDimensions)
                InfoRow(label: "Format", value: imageFormat)
                
                InfoRow(label: "Created", value: formatDate(imageFile.creationDate))
                InfoRow(label: "Modified", value: formatDate(imageFile.modificationDate))
            }
            
            // Image Metadata (if available)
            if let metadata = getImageMetadata() {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.bottom, 2)
                    
                    if let colorSpace = metadata.colorSpace {
                        InfoRow(label: "Color Space", value: colorSpace)
                    }
                    
                    if let camera = metadata.camera {
                        if !camera.make.isEmpty || !camera.model.isEmpty {
                            InfoRow(label: "Camera", value: "\(camera.make) \(camera.model)".trimmingCharacters(in: .whitespaces))
                        }
                        
                        if let settings = camera.settings, !settings.isEmpty {
                            InfoRow(label: "Settings", value: settings)
                        }
                    }
                    
                    if let captureDate = metadata.captureDate {
                        InfoRow(label: "Captured", value: formatDate(captureDate))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(colorScheme == .dark ? NSColor.controlBackgroundColor : NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .frame(maxWidth: 280)
    }
    
    // MARK: - Helper Views
    
    private struct InfoRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack(alignment: .top) {
                Text(label + ":")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                
                Text(value)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var imageDimensions: String {
        guard let image = currentImage else { return "Unknown" }
        let size = image.size
        return "\(Int(size.width)) × \(Int(size.height))"
    }
    
    private var imageFormat: String {
        let pathExtension = imageFile.url.pathExtension.uppercased()
        
        // Map common extensions to readable format names
        switch pathExtension {
        case "JPG", "JPEG":
            return "JPEG"
        case "PNG":
            return "PNG"
        case "GIF":
            return "GIF"
        case "HEIC", "HEIF":
            return "HEIF"
        case "WEBP":
            return "WebP"
        case "TIFF", "TIF":
            return "TIFF"
        case "BMP":
            return "BMP"
        case "SVG":
            return "SVG"
        default:
            return pathExtension.isEmpty ? "Unknown" : pathExtension
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getImageMetadata() -> ImageMetadataService.ImageMetadata? {
        return metadataService.extractMetadata(from: imageFile.url)
    }
    
}

// MARK: - Preview
#Preview {
    // Create a temporary file URL for preview
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sample.jpg")
    
    // Create a mock ImageFile (this will fail in preview, but shows the UI structure)
    if let sampleImageFile = try? ImageFile(url: tempURL) {
        ImageInfoOverlayView(
            imageFile: sampleImageFile,
            currentImage: NSImage(systemSymbolName: "photo", accessibilityDescription: "Sample image")
        )
        .padding()
        .background(Color.black.opacity(0.1))
    } else {
        // Fallback preview structure
        VStack {
            Text("Image Info Overlay Preview")
            Text("(Requires actual image file for full preview)")
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}