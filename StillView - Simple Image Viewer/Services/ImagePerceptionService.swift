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

enum ImagePerceptionError: LocalizedError, Equatable, Sendable {
    case imageDecodingFailed
    case visionRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageDecodingFailed:
            return "The image could not be read for analysis. Try reopening it or selecting another image."
        case .visionRequestFailed(let reason):
            return "Image analysis could not finish. \(reason)"
        }
    }
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

    private let performRequests: @Sendable (VNImageRequestHandler, [VNRequest]) throws -> Void

    init(
        performRequests: @escaping @Sendable (VNImageRequestHandler, [VNRequest]) throws -> Void = {
            try $0.perform($1)
        }
    ) {
        self.performRequests = performRequests
    }

    /// Large low-confidence face-shaped regions are rejected. Very small detections count only
    /// when Vision is exceptionally confident, which preserves distant faces without promoting noise.
    static func shouldCountFace(area: Double, confidence: Float) -> Bool {
        (area >= 0.003 && confidence >= 0.5)
            || (area >= 0.0005 && confidence >= 0.85)
    }

    func analyze(url: URL) async throws -> ImagePerceptionResult {
        try Task.checkCancellation()
        let cancellation = PerceptionCancellation()
        let worker = Task.detached(priority: .userInitiated) {
            try cancellation.checkCancellation()
            let loaded = Self.loadCGImage(at: url)
            try cancellation.checkCancellation()
            guard let loaded else {
                Logger.warning("Perception: could not decode image", context: "AIInsights")
                throw ImagePerceptionError.imageDecodingFailed
            }

            let result = try runRequests(
                on: loaded.image,
                orientation: loaded.orientation,
                cancellation: cancellation
            )
            try cancellation.checkCancellation()
            Self.log(result: result)
            return result
        }

        return try await withTaskCancellationHandler {
            do {
                let result = try await worker.value
                try Task.checkCancellation()
                return result
            } catch {
                try Task.checkCancellation()
                throw error
            }
        } onCancel: {
            worker.cancel()
            cancellation.cancel()
        }
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

    private func runRequests(
        on image: CGImage,
        orientation: CGImagePropertyOrientation,
        cancellation: PerceptionCancellation
    ) throws -> ImagePerceptionResult {
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

        let requests: [VNRequest] = [classification, textRecognition, faceDetection]
        try cancellation.register(requests)
        defer { cancellation.clearRequests() }
        do {
            try cancellation.checkCancellation()
            try performRequests(handler, requests)
        } catch {
            try cancellation.checkCancellation()
            if error is CancellationError { throw error }
            Logger.warning("Perception: Vision.perform failed: \(error.localizedDescription)", context: "AIInsights")
            throw ImagePerceptionError.visionRequestFailed(error.localizedDescription)
        }
        try cancellation.checkCancellation()

        let classifications = (classification.results ?? [])
            .prefix(12)
            .map { ImagePerceptionResult.Classification(identifier: $0.identifier, confidence: $0.confidence) }

        let textCandidates = (textRecognition.results ?? []).compactMap { observation -> OCRCleaner.Candidate? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRCleaner.Candidate(text: candidate.string, confidence: candidate.confidence)
        }

        let faceCount = (faceDetection.results ?? []).filter { observation in
            let area = observation.boundingBox.width * observation.boundingBox.height
            return Self.shouldCountFace(area: Double(area), confidence: observation.confidence)
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

/// Holds only the requests that the worker is currently performing. All mutable state is protected
/// by the lock; request cancellation runs outside the lock because Vision may invoke a completion.
private final class PerceptionCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var requests: [VNRequest] = []

    func register(_ requests: [VNRequest]) throws {
        lock.lock()
        if cancelled {
            lock.unlock()
            requests.forEach { $0.cancel() }
            throw CancellationError()
        }
        self.requests = requests
        lock.unlock()
    }

    func clearRequests() {
        lock.lock()
        requests.removeAll()
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let activeRequests = requests
        lock.unlock()
        activeRequests.forEach { $0.cancel() }
    }

    func checkCancellation() throws {
        try Task.checkCancellation()
        lock.lock()
        let wasCancelled = cancelled
        lock.unlock()
        if wasCancelled { throw CancellationError() }
    }
}
