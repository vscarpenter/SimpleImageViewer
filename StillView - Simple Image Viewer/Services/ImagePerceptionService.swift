import Foundation
import Vision
import ImageIO
import CoreGraphics

/// Structured visual signals extracted from an image using on-device Apple Vision.
/// Every field is optional in spirit — when a signal returns nothing, the field stays empty
/// and is omitted from `asSignals`. This keeps the FM prompt honest: the model only sees
/// signals that actually exist.
struct ImagePerceptionResult: Equatable, Sendable {
    struct Classification: Equatable, Sendable {
        let identifier: String
        let confidence: Float
    }

    let classifications: [Classification]
    let recognizedText: [String]
    let faceCount: Int
    let salientObjectCount: Int
    let hasHorizon: Bool

    static let empty = ImagePerceptionResult(
        classifications: [],
        recognizedText: [],
        faceCount: 0,
        salientObjectCount: 0,
        hasHorizon: false
    )

    /// Renders perception observations as short, prompt-friendly strings.
    /// Confidence is included on classifications so the FM can weight strong vs weak signals.
    var asSignals: [String] {
        var signals: [String] = []

        if !classifications.isEmpty {
            let rendered = classifications
                .map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }
                .joined(separator: ", ")
            signals.append("Scene/object categories (Apple Vision, with confidence): \(rendered)")
        }

        if faceCount > 0 {
            let hint = faceCount == 1
                ? "likely a portrait or selfie"
                : faceCount <= 4 ? "likely a small group" : "likely a group photo"
            signals.append("Faces detected: \(faceCount) (\(hint))")
        }

        if !recognizedText.isEmpty {
            let joined = recognizedText.prefix(25).joined(separator: " | ")
            signals.append("Text visible in image (OCR — brand names, venue names, signage, banners): \(joined)")
        }

        if salientObjectCount > 0 {
            let descriptor = salientObjectCount == 1
                ? "1 distinct foreground subject"
                : "\(salientObjectCount) distinct foreground subjects (a more complex scene with multiple objects)"
            signals.append("Foreground subjects (Vision objectness): \(descriptor)")
        }

        if hasHorizon {
            signals.append("Horizon detected (likely outdoor or landscape composition)")
        }

        return signals
    }
}

/// OCR text from Vision is often a mix of clean words and noise (icon glyphs split
/// brand names, very short tokens from logos, decorative characters). We dedupe
/// case-insensitively and drop tokens that are too short or mostly non-alphabetic —
/// this stops the FM from distrusting the entire OCR field because of a few garbled
/// fragments.
private enum OCRCleaner {
    static func clean(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for token in raw {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else { continue }

            let letterCount = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            let alphaRatio = Double(letterCount) / Double(trimmed.count)
            guard alphaRatio >= 0.5 else { continue }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(trimmed)
        }

        return output
    }
}

/// Runs a focused set of on-device Vision requests against a local image and returns
/// structured observations. All work happens on a background priority Task, never on the main actor.
/// Runs entirely on-device — Apple Vision ships with macOS; no network calls, no remote model fetches.
struct ImagePerceptionService: Sendable {
    static let shared = ImagePerceptionService()

    /// Analyze the image at `url` and return on-device perception results.
    /// Returns `.empty` if the image cannot be decoded or if every request fails.
    func analyze(url: URL) async -> ImagePerceptionResult {
        await Task.detached(priority: .userInitiated) { () -> ImagePerceptionResult in
            guard let loaded = Self.loadCGImage(at: url) else {
                Logger.warning("Perception: could not decode image", context: "AIInsights")
                return .empty
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
        let rawOrientation = (properties?[kCGImagePropertyOrientation] as? Int).flatMap { UInt32(exactly: $0) } ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
        return (image, orientation)
    }

    private static func runRequests(on cgImage: CGImage, orientation: CGImagePropertyOrientation) -> ImagePerceptionResult {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        // Revision 2 has "improved accuracy, reduced latency and memory utilization" per the
        // macOS 26 SDK header. Same taxonomy, better recall — important for objects the
        // default revision misses or scores below threshold (e.g. cars, vehicles).
        let classification = VNClassifyImageRequest()
        classification.revision = VNClassifyImageRequestRevision2

        let textRecognition = VNRecognizeTextRequest()
        textRecognition.recognitionLevel = .accurate
        textRecognition.usesLanguageCorrection = true
        textRecognition.recognitionLanguages = ["en-US"]

        let faceDetection = VNDetectFaceRectanglesRequest()
        // Revision 1 (the default) is deprecated; Revision 3 is the most accurate available
        // and substantially better at finding faces in group photos.
        faceDetection.revision = VNDetectFaceRectanglesRequestRevision3
        // Objectness-based saliency counts distinct foreground OBJECTS (vs attention-based
        // which highlights where a viewer would look). For cars-and-people-style photos
        // this tells the FM "there are 2+ distinct subjects" even when the classifier
        // didn't name them.
        let saliency = VNGenerateObjectnessBasedSaliencyImageRequest()
        let horizonDetection = VNDetectHorizonRequest()

        do {
            try handler.perform([
                classification,
                textRecognition,
                faceDetection,
                saliency,
                horizonDetection
            ])
        } catch {
            Logger.warning("Perception: Vision.perform failed: \(error.localizedDescription)", context: "AIInsights")
            return .empty
        }

        // Confidence ≥ 0.15 + top-10 surfaces weaker labels (vehicles, secondary objects)
        // that the higher threshold filtered out. The model sees the confidence and can
        // decide what to lean on.
        let classifications: [ImagePerceptionResult.Classification] = (classification.results ?? [])
            .filter { $0.confidence >= 0.15 }
            .prefix(10)
            .map { .init(identifier: $0.identifier, confidence: $0.confidence) }

        let rawText: [String] = (textRecognition.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
        let recognizedText = OCRCleaner.clean(rawText)

        // Two-pronged face filter so we count real foreground subjects, not background
        // blurs or false positives:
        //   - Area ≥ 0.3% catches all reasonable foreground faces (even a 5-person group
        //     photo where each face occupies ~0.8-1% of the frame).
        //   - Confidence ≥ 0.7 rejects false positives that happen to be large (e.g. a
        //     face-shaped pattern in a poster, decoration, or reflection).
        // Either condition is enough to qualify; together they balance the rose-photo case
        // (tiny background figures → 0 faces) with the group-photo case (5 real subjects
        // → 5 faces).
        let faceCount = (faceDetection.results ?? [])
            .filter { observation in
                let area = observation.boundingBox.width * observation.boundingBox.height
                return area >= 0.003 && observation.confidence >= 0.7
            }
            .count
        let salientObjectCount = saliency.results?.first?.salientObjects?.count ?? 0
        let hasHorizon = (horizonDetection.results?.count ?? 0) > 0

        return ImagePerceptionResult(
            classifications: classifications,
            recognizedText: recognizedText,
            faceCount: faceCount,
            salientObjectCount: salientObjectCount,
            hasHorizon: hasHorizon
        )
    }

    private static func log(result: ImagePerceptionResult) {
        // Privacy: never log filenames, OCR text, or specific classification labels.
        // Counts and category flags are enough for diagnostics and contain no user content
        // that could end up in Console.app or sysdiagnose.
        Logger.info(
            "Perception complete classifications=\(result.classifications.count) faces=\(result.faceCount) ocrTokens=\(result.recognizedText.count) salientObjects=\(result.salientObjectCount) horizon=\(result.hasHorizon)",
            context: "AIInsights"
        )
    }
}
