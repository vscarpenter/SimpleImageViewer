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

    func generateAnalysis(for input: ImageInsightInput) async throws -> ImageInsightAnalysis {
        try Task.checkCancellation()
        let currentAvailability = availability()
        guard currentAvailability.isAvailable else {
            throw ImageInsightError.unavailable(currentAvailability.message)
        }
        guard let imageURL = input.imageURL else { throw ImageInsightError.imageUnavailable }
        let started = ProcessInfo.processInfo.systemUptime
        let revision = try Self.fileRevision(at: imageURL)
        let model = SystemLanguageModel.default
        let modelName = model.variant.displayName
        let contextSize = model.contextSize
        guard input.fileByteCount.map({ $0 == revision.byteCount }) ?? true,
              input.fileModificationDate.map({ $0 == revision.modificationDate }) ?? true,
              input.modelName.map({ $0 == modelName }) ?? true,
              input.contextSize.map({ $0 == contextSize }) ?? true,
              input.promptVersion == ImageInsightPromptBuilder.version else {
            throw ImageInsightError.inputChanged
        }
        let image = try await ImagePerceptionService.loadImage(at: imageURL)
        let perception = try await perceptionService.analyze(image: image)
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
        let maximumResponseTokens = 800
        let instructionTokens = try await model.tokenCount(for: Instructions(ImageInsightPromptBuilder.systemInstruction))
        let schemaTokens = try await model.tokenCount(for: GeneratedImageInsight.generationSchema)
        // The macOS 27 model can generate from attachments, but its token counter currently
        // rejects them. Count text with the supported API and reserve space for image tokens.
        // If the actual request still exceeds context, retry once with pixels alone.
        let availableTokens = ImageInsightPromptBudget.availableTextTokens(
            contextSize: model.contextSize, instructionTokens: instructionTokens,
            schemaTokens: schemaTokens, responseTokens: maximumResponseTokens
        )
        let indices = try await ImageInsightPromptBudget.fittingTextLineIndices(
            lineCount: perception.textObservations.count,
            availableTokens: availableTokens,
            tokenCount: { indices in
                try await model.tokenCount(for: ImageInsightPromptBuilder.prompt(
                    for: perception, textLineIndices: indices
                ))
            }
        )
        return try await respondWithContextRecovery(indices: indices) { selectedIndices in
            try await respondOnce(model: model, image: image, perception: perception, indices: selectedIndices)
        }
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
        let response = try await session.respond(
            to: imagePrompt(image: image, perception: perception, indices: indices),
            generating: GeneratedImageInsight.self,
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 800)
        )
        return ImageInsightModelResponse(content: response.content, textLineIndices: indices)
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
    @Guide(description: "Normally nil. One important visible fact absent from the summary; no repeated details.")
    let additionalDetail: String?
    @Guide(description: "Up to five short tags about visible content, without transcribed labels or values.", .count(0...5))
    let tags: [String]
    @Guide(description: "Normally nil. Only an ambiguity that changes the main interpretation; absent details do not count.")
    let uncertainty: String?
    @Guide(description: "Up to three different supplied OCR indices for exact excerpts. Empty if unnecessary.", .count(0...3))
    let selectedTextLineIndices: [Int]
}
