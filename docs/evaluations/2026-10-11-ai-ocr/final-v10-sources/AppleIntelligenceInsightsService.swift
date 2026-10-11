import CoreGraphics
import Foundation
import FoundationModels

struct AppleIntelligenceInsightsService: ImageInsightGenerating {
    typealias ResponseGenerator = @Sendable (
        SystemLanguageModel, CGImage, ImagePerceptionResult
    ) async throws -> ImageInsightModelResponse

    static let shared = AppleIntelligenceInsightsService()
    private let perceptionService: ImagePerceptionService
    private let availabilityProvider: @Sendable () -> ImageInsightAvailability
    private let responseGenerator: ResponseGenerator

    init(
        perceptionService: ImagePerceptionService = .shared,
        availabilityProvider: (@Sendable () -> ImageInsightAvailability)? = nil,
        responseGenerator: ResponseGenerator? = nil
    ) {
        self.perceptionService = perceptionService
        self.availabilityProvider = availabilityProvider ?? { Self.modelAvailability() }
        self.responseGenerator = responseGenerator ?? { model, image, perception in
            try await Self.respond(model: model, image: image, perception: perception)
        }
    }

    func availability() -> ImageInsightAvailability { availabilityProvider() }

    func makeInput(for imageFile: ImageFile) -> ImageInsightInput {
        var resourceURL = imageFile.url
        resourceURL.removeAllCachedResourceValues()
        let resourceValues = try? resourceURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let byteCount = resourceValues.flatMap { $0.fileSize }.map(Int64.init)
        let fileSize = byteCount.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
            ?? imageFile.formattedSize
        let metadata = ImageMetadataService().extractMetadata(from: imageFile.url)
        let model = SystemLanguageModel.default
        return ImageInsightInput(
            fileType: imageFile.type.localizedDescription ?? imageFile.type.identifier,
            dimensions: metadata.dimensions,
            fileSize: fileSize,
            colorProfile: metadata.colorSpace,
            imageURL: imageFile.url,
            fileByteCount: byteCount,
            fileModificationDate: resourceValues?.contentModificationDate,
            modelName: model.variant.displayName,
            contextSize: model.contextSize,
            promptVersion: ImageInsightPromptBuilder.version
        )
    }

    func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult {
        try await generateAnalysis(for: input).result
    }

    func generateInsight(
        for input: ImageInsightInput, onTextRecognized: @escaping ImageTextRecognitionHandler
    ) async throws -> ImageInsightResult {
        try await generateAnalysis(for: input, onTextRecognized: onTextRecognized).result
    }

    /// Vision extraction is independent of StillView's AI preference and model readiness.
    func extractText(for input: ImageInsightInput) async throws -> ImagePerceptionResult {
        try Task.checkCancellation()
        guard let imageURL = input.imageURL else { throw ImageInsightError.imageUnavailable }
        let resourceLease = SecurityScopedAccessManager.shared.acquireWorkerAccess(for: imageURL)
        defer { withExtendedLifetime(resourceLease) {} }
        let revision = try Self.fileRevision(at: imageURL)
        try Self.validateFileRevision(revision, input: input)
        let perception = try await perceptionService.analyze(url: imageURL, resourceLease: resourceLease)
        try Task.checkCancellation()
        guard let currentRevision = try? Self.fileRevision(at: imageURL), currentRevision == revision else {
            throw ImageInsightError.inputChanged
        }
        return perception
    }

    func generateAnalysis(
        for input: ImageInsightInput, onTextRecognized: ImageTextRecognitionHandler? = nil
    ) async throws -> ImageInsightAnalysis {
        try Task.checkCancellation()
        let currentAvailability = availability()
        guard currentAvailability.isAvailable else {
            throw ImageInsightError.unavailable(currentAvailability.message)
        }
        guard let imageURL = input.imageURL else { throw ImageInsightError.imageUnavailable }
        let resourceLease = SecurityScopedAccessManager.shared.acquireWorkerAccess(for: imageURL)
        defer { withExtendedLifetime(resourceLease) {} }
        let started = ProcessInfo.processInfo.systemUptime
        let revision = try Self.fileRevision(at: imageURL)
        let model = SystemLanguageModel.default
        let modelName = model.variant.displayName
        let contextSize = model.contextSize
        try Self.validateFileRevision(revision, input: input)
        guard input.modelName.map({ $0 == modelName }) ?? true,
              input.contextSize.map({ $0 == contextSize }) ?? true,
              input.promptVersion == ImageInsightPromptBuilder.version else {
            throw ImageInsightError.inputChanged
        }
        let image = try await ImagePerceptionService.loadImage(at: imageURL, resourceLease: resourceLease)
        let perception = try await perceptionService.analyze(
            url: imageURL, baseImage: image, resourceLease: resourceLease
        )
        try Task.checkCancellation()
        guard let recognizedRevision = try? Self.fileRevision(at: imageURL), recognizedRevision == revision else {
            throw ImageInsightError.inputChanged
        }
        await onTextRecognized?(perception)
        try Task.checkCancellation()
        do {
            let response = try await responseGenerator(model, image, perception)
            try Task.checkCancellation()
            let currentModel = SystemLanguageModel.default
            guard let currentRevision = try? Self.fileRevision(at: imageURL), currentRevision == revision,
                  currentModel.variant.displayName == modelName, currentModel.contextSize == contextSize else {
                throw ImageInsightError.inputChanged
            }
            let provenance = ImageInsightProvenance(
                modelName: modelName,
                contextSize: contextSize,
                promptVersion: ImageInsightPromptBuilder.version,
                durationSeconds: ProcessInfo.processInfo.systemUptime - started
            )
            let result = try InsightOutputValidator.result(
                from: response.content,
                perception: perception,
                provenance: provenance,
                modelTextLineIndices: response.textLineIndices
            )
            return ImageInsightAnalysis(
                result: result, perception: perception, modelTextLineIndices: response.textLineIndices
            )
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            if let insightError = error as? ImageInsightError { throw insightError }
            if let modelError = error as? LanguageModelError { throw Self.insightError(for: modelError) }
            let latestAvailability = availability()
            if !latestAvailability.isAvailable {
                throw ImageInsightError.unavailable(latestAvailability.message)
            }
            throw ImageInsightError.generationFailed("Try again in a moment or choose another image.")
        }
    }

    static func insightError(for error: LanguageModelError) -> ImageInsightError {
        let message: String
        switch error {
        case .contextSizeExceeded:
            message = "This image contains more detail or text than the on-device model can process. Try a crop."
        case .rateLimited:
            message = "The on-device model is busy. Try again in a moment."
        case .guardrailViolation, .refusal:
            message = "The on-device model declined to describe this image. Try another image."
        case .unsupportedLanguageOrLocale:
            message = "The on-device model does not support the current language or region."
        case .timeout:
            message = "Analysis took too long. Try again or choose a smaller image."
        case .unsupportedCapability:
            message = "The current on-device model cannot analyze images. Check Apple Intelligence in System Settings."
        case .unsupportedTranscriptContent, .unsupportedGenerationGuide:
            message = "The on-device model could not process this request. Try again after updating macOS."
        @unknown default:
            message = "Try again in a moment or choose another image."
        }
        return .generationFailed(message)
    }

    private static func validateFileRevision(_ revision: ImageInsightFileRevision, input: ImageInsightInput) throws {
        guard input.fileByteCount.map({ $0 == revision.byteCount }) ?? true,
              input.fileModificationDate.map({ $0 == revision.modificationDate }) ?? true else {
            throw ImageInsightError.inputChanged
        }
    }

    private static func fileRevision(at originalURL: URL) throws -> ImageInsightFileRevision {
        var url = originalURL
        url.removeAllCachedResourceValues()
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return ImageInsightFileRevision(
            byteCount: values.fileSize.map(Int64.init), modificationDate: values.contentModificationDate
        )
    }

    private static func modelAvailability() -> ImageInsightAvailability {
        let availability: ImageInsightModelAvailability
        switch SystemLanguageModel.default.availability {
        case .available: availability = .available
        case .unavailable(.deviceNotEligible): availability = .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): availability = .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady): availability = .modelNotReady
        @unknown default: availability = .unknownUnavailable
        }
        return ImageInsightAvailability.resolve(modelAvailability: availability)
    }

    private static func respond(
        model: SystemLanguageModel, image: CGImage, perception: ImagePerceptionResult
    ) async throws -> ImageInsightModelResponse {
        try await respondOnce(model: model, image: image, perception: perception, indices: [])
    }

    static func respondWithContextRecovery(
        indices: [Int], response: ([Int]) async throws -> ImageInsightModelResponse
    ) async throws -> ImageInsightModelResponse {
        do {
            return try await response(indices)
        } catch let error as LanguageModelError {
            guard case .contextSizeExceeded = error, !indices.isEmpty else { throw error }
            try Task.checkCancellation()
            return try await response([])
        }
    }

    private static func respondOnce(
        model: SystemLanguageModel, image: CGImage, perception: ImagePerceptionResult, indices: [Int]
    ) async throws -> ImageInsightModelResponse {
        try Task.checkCancellation()
        let session = LanguageModelSession(model: model, instructions: ImageInsightPromptBuilder.systemInstruction)
        let prompt = imagePrompt(image: image, perception: perception, indices: indices)
        let options = GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 350)
        let generated: GeneratedImageInsight
        if perception.hasProminentText {
            let response = try await session.respond(
                to: prompt, generating: GeneratedImageDocumentLayout.self, options: options
            )
            generated = GeneratedImageInsight(
                title: response.content.kind.title, summary: response.content.arrangement.summary(for: response.content.kind),
                additionalDetail: nil, tags: [], uncertainty: nil
            )
        } else {
            let response = try await session.respond(
                to: prompt, generating: GeneratedImageDescription.self, options: options
            )
            generated = GeneratedImageInsight(
                title: response.content.title, summary: response.content.summary,
                additionalDetail: nil, tags: [], uncertainty: nil
            )
        }
        return ImageInsightModelResponse(content: generated, textLineIndices: indices)
    }

    private static func imagePrompt(image: CGImage, perception: ImagePerceptionResult, indices: [Int]) -> Prompt {
        Prompt {
            ImageInsightPromptBuilder.prompt(for: perception, textLineIndices: indices)
            Attachment(image, orientation: .up)
        }
    }
}

private struct ImageInsightFileRevision: Equatable {
    let byteCount: Int64?
    let modificationDate: Date?
}

struct ImageInsightModelResponse: Sendable {
    let content: GeneratedImageInsight
    /// Original OCR indices actually supplied to this inference, without reindexing a subset.
    let textLineIndices: [Int]
}

@Generable(
    description: "A concise image description. Supplementary detail and uncertainty are normally nil.",
    representNilExplicitlyInGeneratedContent: true
)
struct GeneratedImageInsight: Equatable, Sendable {
    @Guide(description: "A short visible-subject title, at most eight words. No transcribed labels or digit-bearing tokens.")
    let title: String
    @Guide(description: "One or two brief sentences. For documents describe kind and layout, without labels or values.")
    let summary: String
    @Guide(description: "Normally nil. One visible fact absent from the summary that materially changes understanding.")
    let additionalDetail: String?
    @Guide(description: "Up to five short tags about visible content, without transcribed labels or values.", .count(0...5))
    let tags: [String]
    @Guide(description: "Normally nil. A visible ambiguity that changes the main interpretation, without speculation.")
    let uncertainty: String?
}

/// The production task has two reusable outputs; empty optional result sections stay omitted.
@Generable(description: "A concise description of visible content, with exact text handled separately.")
struct GeneratedImageDescription: Equatable, Sendable {
    @Guide(description: "At most eight words naming the visible subject. For documents or signs, use their broad kind.")
    let title: String
    @Guide(description: "One or two short sentences about visible pixels. For documents describe only visual organization.")
    let summary: String
}

@Generable(description: "The broad kind and arrangement of an image containing substantial writing.")
struct GeneratedImageDocumentLayout: Equatable, Sendable {
    @Guide(description: "Choose the broad visible kind. Do not use a source name, heading, or interpreted value.")
    let kind: ImageDocumentKind
    @Guide(description: "Choose only the broad visible arrangement. Exact alignment, counts, and values are not part of this task.")
    let arrangement: ImageDocumentArrangement
}

@Generable(description: "The broad visible kind of an image containing writing.")
enum ImageDocumentKind: Sendable {
    case receipt
    case table
    case chart
    case screenshot
    case page
    case sign
    case photograph
    case other

    var title: String {
        switch self {
        case .receipt: return "Receipt"
        case .table: return "Table"
        case .chart: return "Chart"
        case .screenshot: return "Screenshot"
        case .page: return "Text document"
        case .sign: return "Sign"
        case .photograph: return "Image with writing"
        case .other: return "Text in image"
        }
    }

    var subject: String {
        switch self {
        case .receipt: return "A receipt"
        case .table: return "A table"
        case .chart: return "A chart"
        case .screenshot: return "A screenshot"
        case .page: return "A document"
        case .sign: return "A sign"
        case .photograph, .other: return "The image"
        }
    }
}

@Generable(description: "Broad visual organization, without exact positions, counts, source wording, or values.")
enum ImageDocumentArrangement: Sendable {
    case textBlocks
    case grid
    case graphicalMarks
    case textAndFigures
    case writingInScene
    case unclear

    func summary(for kind: ImageDocumentKind) -> String {
        switch self {
        case .textBlocks: return "\(kind.subject) contains blocks of text."
        case .grid: return "\(kind.subject) contains text arranged in a grid."
        case .graphicalMarks: return "\(kind.subject) contains graphical marks and labels."
        case .textAndFigures: return "\(kind.subject) contains text."
        case .writingInScene: return "Text is visible in the image."
        case .unclear: return "Text is visible, but its organization could not be determined."
        }
    }
}
