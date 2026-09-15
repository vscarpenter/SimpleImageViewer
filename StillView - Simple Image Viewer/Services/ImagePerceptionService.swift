import CoreGraphics
import Foundation
import ImageIO
import Vision

struct ImagePerceptionResult: Equatable, Sendable {
    struct TextObservation: Equatable, Sendable {
        let text: String
        let confidence: Float
        /// Normalized coordinates in the oriented image, with the origin at the bottom left.
        let boundingBox: CGRect

        init(text: String, confidence: Float, boundingBox: CGRect = .zero) {
            self.text = text
            self.confidence = confidence
            self.boundingBox = boundingBox
        }
    }

    let textObservations: [TextObservation]
    let textWasTruncated: Bool
    var recognizedText: [String] { textObservations.map(\.text) }

    init(textObservations: [TextObservation], textWasTruncated: Bool = false) {
        self.textObservations = textObservations
        self.textWasTruncated = textWasTruncated
    }

    static let empty = ImagePerceptionResult(textObservations: [])
}

enum ImagePerceptionError: LocalizedError, Equatable, Sendable {
    case imageDecodingFailed
    case visionRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageDecodingFailed:
            return "The image could not be read for analysis. Try reopening it or selecting another image."
        case .visionRequestFailed(let reason):
            return "Text recognition could not finish. \(reason)"
        }
    }
}

enum OCRCleaner {
    typealias Candidate = ImagePerceptionResult.TextObservation
    static let maximumLines = 128
    static let maximumCharacters = 6_000
    private static let minimumConfidence: Float = 0.5

    static func clean(_ candidates: [Candidate]) -> [String] {
        evidence(from: candidates).recognizedText
    }

    /// Preserve original text, positions, and repetition. Drop whole observations at the budget
    /// boundary so an amount or quoted line is never presented as a clipped transcription.
    static func evidence(from candidates: [Candidate]) -> ImagePerceptionResult {
        var output: [Candidate] = []
        var characterCount = 0
        var wasTruncated = false
        for candidate in candidates where candidate.confidence >= minimumConfidence {
            guard !candidate.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard output.count < maximumLines, characterCount + candidate.text.count <= maximumCharacters else {
                wasTruncated = true
                continue
            }
            output.append(candidate)
            characterCount += candidate.text.count
        }
        return ImagePerceptionResult(textObservations: output, textWasTruncated: wasTruncated)
    }
}

/// Decodes one bounded, oriented first frame for both the model attachment and exact OCR evidence.
struct ImagePerceptionService: Sendable {
    static let shared = ImagePerceptionService()
    static let maximumImageDimension = 2_048
    private let performRequests: @Sendable (VNImageRequestHandler, [VNRequest]) throws -> Void

    init(
        performRequests: @escaping @Sendable (VNImageRequestHandler, [VNRequest]) throws -> Void = {
            try $0.perform($1)
        }
    ) {
        self.performRequests = performRequests
    }

    static func loadImage(at url: URL) async throws -> CGImage {
        try Task.checkCancellation()
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            let thumbnailOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumImageDimension,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
                throw ImagePerceptionError.imageDecodingFailed
            }
            try Task.checkCancellation()
            return image
        }
        return try await withTaskCancellationHandler {
            do {
                let image = try await worker.value
                try Task.checkCancellation()
                return image
            } catch {
                try Task.checkCancellation()
                throw error
            }
        } onCancel: {
            worker.cancel()
        }
    }

    func analyze(url: URL) async throws -> ImagePerceptionResult {
        try await analyze(image: Self.loadImage(at: url))
    }

    func analyze(image: CGImage) async throws -> ImagePerceptionResult {
        try Task.checkCancellation()
        let cancellation = PerceptionCancellation()
        let worker = Task.detached(priority: .userInitiated) {
            try cancellation.checkCancellation()
            let result = try runRequests(on: image, cancellation: cancellation)
            try cancellation.checkCancellation()
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

    private func runRequests(
        on image: CGImage,
        cancellation: PerceptionCancellation
    ) throws -> ImagePerceptionResult {
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        let textRecognition = VNRecognizeTextRequest()
        textRecognition.recognitionLevel = .accurate
        textRecognition.usesLanguageCorrection = false
        textRecognition.automaticallyDetectsLanguage = true
        let requests: [VNRequest] = [textRecognition]
        try cancellation.register(requests)
        defer { cancellation.clearRequests() }
        do {
            try cancellation.checkCancellation()
            try performRequests(handler, requests)
        } catch {
            try cancellation.checkCancellation()
            if error is CancellationError { throw error }
            throw ImagePerceptionError.visionRequestFailed(error.localizedDescription)
        }
        try cancellation.checkCancellation()
        let candidates = (textRecognition.results ?? []).compactMap { observation -> OCRCleaner.Candidate? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRCleaner.Candidate(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox
            )
        }
        return OCRCleaner.evidence(from: candidates)
    }
}

/// All mutable state is protected by the lock; request cancellation runs outside the lock
/// because Vision may invoke a completion while cancelling.
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
