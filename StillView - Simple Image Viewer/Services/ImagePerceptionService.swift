import CoreGraphics
import Foundation
import ImageIO
import Vision

struct ImagePerceptionResult: Equatable, Sendable {
    struct Classification: Equatable, Sendable {
        let identifier: String
        let confidence: Float
    }

    let classifications: [Classification]
    let recognizedText: [String]
    let faceCount: Int

    static let empty = ImagePerceptionResult(
        classifications: [],
        recognizedText: [],
        faceCount: 0
    )
}

enum OCRCleaner {
    struct Candidate: Equatable, Sendable {
        let text: String
        let confidence: Float
    }

    private static let minimumConfidence: Float = 0.5
    private static let maximumLines = 16

    static func clean(_ candidates: [Candidate]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for candidate in candidates where candidate.confidence >= minimumConfidence {
            let trimmed = candidate.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 || isStandaloneCJK(trimmed) else { continue }

            let semanticCount = trimmed.unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .count
            let semanticRatio = Double(semanticCount) / Double(trimmed.count)
            guard semanticCount >= 2 || isStandaloneCJK(trimmed), semanticRatio >= 0.5 else { continue }

            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            output.append(trimmed)

            if output.count == maximumLines {
                break
            }
        }

        return output
    }

    private static func isStandaloneCJK(_ token: String) -> Bool {
        guard token.count == 1, let scalar = token.unicodeScalars.first else { return false }
        let value = scalar.value
        return (0x4E00...0x9FFF).contains(value)
            || (0x3400...0x4DBF).contains(value)
            || (0x3040...0x30FF).contains(value)
            || (0xAC00...0xD7A3).contains(value)
    }
}

/// Extracts only observations that can be made reliably with public, on-device Vision APIs.
/// Foundation Models on macOS 26 receives the filtered text representation, not image pixels.
struct ImagePerceptionService: Sendable {
    static let shared = ImagePerceptionService()

    /// Large low-confidence face-shaped regions are rejected. Very small detections count only
    /// when Vision is exceptionally confident, which preserves distant faces without promoting noise.
    static func shouldCountFace(area: Double, confidence: Float) -> Bool {
        (area >= 0.003 && confidence >= 0.5)
            || (area >= 0.0005 && confidence >= 0.85)
    }

    func analyze(url: URL) async -> ImagePerceptionResult {
        await Task.detached(priority: .userInitiated) {
            guard let loaded = Self.loadCGImage(at: url) else {
                Logger.warning("Perception: could not decode image", context: "AIInsights")
                return ImagePerceptionResult.empty
            }

            let result = Self.runRequests(on: loaded.image, orientation: loaded.orientation)
            Self.log(result: result)
            return result
        }.value
    }

    private static func loadCGImage(at url: URL) -> (image: CGImage, orientation: CGImagePropertyOrientation)? {
        let options: [CFString: Any] = [kCGImageSourceShouldCacheImmediately: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = (properties?[kCGImagePropertyOrientation] as? Int)
            .flatMap { UInt32(exactly: $0) } ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
        return (image, orientation)
    }

    private static func runRequests(
        on image: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> ImagePerceptionResult {
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])

        let classification = VNClassifyImageRequest()
        classification.revision = VNClassifyImageRequestRevision2

        let textRecognition = VNRecognizeTextRequest()
        textRecognition.recognitionLevel = .accurate
        textRecognition.usesLanguageCorrection = true
        textRecognition.automaticallyDetectsLanguage = true
        textRecognition.recognitionLanguages = [
            "en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "ja", "zh-Hans", "ko"
        ]

        let faceDetection = VNDetectFaceRectanglesRequest()
        faceDetection.revision = VNDetectFaceRectanglesRequestRevision3

        do {
            try handler.perform([classification, textRecognition, faceDetection])
        } catch {
            Logger.warning("Perception: Vision.perform failed: \(error.localizedDescription)", context: "AIInsights")
            return .empty
        }

        let classifications = (classification.results ?? [])
            .prefix(12)
            .map { ImagePerceptionResult.Classification(identifier: $0.identifier, confidence: $0.confidence) }

        let textCandidates = (textRecognition.results ?? []).compactMap { observation -> OCRCleaner.Candidate? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRCleaner.Candidate(text: candidate.string, confidence: candidate.confidence)
        }

        let faceCount = (faceDetection.results ?? []).filter { observation in
            let area = observation.boundingBox.width * observation.boundingBox.height
            return shouldCountFace(area: Double(area), confidence: observation.confidence)
        }.count

        return ImagePerceptionResult(
            classifications: classifications,
            recognizedText: OCRCleaner.clean(textCandidates),
            faceCount: faceCount
        )
    }

    private static func log(result: ImagePerceptionResult) {
        Logger.info(
            "Perception complete classifications=\(result.classifications.count) faces=\(result.faceCount) ocrLines=\(result.recognizedText.count)",
            context: "AIInsights"
        )
    }
}
