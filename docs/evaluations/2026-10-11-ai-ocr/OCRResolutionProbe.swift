import Foundation
import CoreGraphics
import ImageIO

@main struct OCRResolutionProbe {
    static func main() async throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        let files = ["tall-dense-receipt.png"]
        var records: [[String: Any]] = []
        for file in files {
            for dimension in [4096, 2048, 4096, 2048] {
                let started = ProcessInfo.processInfo.systemUptime
                let url = folder.appendingPathComponent(file)
                let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)!
                let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: dimension,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary)!
                let result = try await ImagePerceptionService().analyze(image: image)
                let record: [String: Any] = ["file": file, "dimension": dimension,
                    "decodedWidth": image.width, "decodedHeight": image.height,
                    "elapsedSeconds": ProcessInfo.processInfo.systemUptime - started,
                    "textWasTruncated": result.textWasTruncated,
                    "lines": result.textObservations.map { ["text": $0.text, "confidence": $0.confidence,
                        "box": ["x": $0.boundingBox.minX, "y": $0.boundingBox.minY,
                            "width": $0.boundingBox.width, "height": $0.boundingBox.height]] }]
                records.append(record)
                print("\(file) \(dimension): \(result.textObservations.count) lines")
            }
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys]).write(to: output)
    }
}
