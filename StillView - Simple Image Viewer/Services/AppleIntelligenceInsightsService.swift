import Foundation
import ImageIO

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleIntelligenceInsightsService: ImageInsightGenerating {
    static let shared = AppleIntelligenceInsightsService()

    private let perceptionService: ImagePerceptionService

    init(perceptionService: ImagePerceptionService = .shared) {
        self.perceptionService = perceptionService
    }

    func availability() -> ImageInsightAvailability {
        let macOSMajorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return ImageInsightAvailability.resolve(
                macOSMajorVersion: macOSMajorVersion,
                foundationModelsAvailable: true,
                modelAvailability: Self.modelAvailability()
            )
        }
        #endif

        return ImageInsightAvailability.resolve(
            macOSMajorVersion: macOSMajorVersion,
            foundationModelsAvailable: false,
            modelAvailability: .unknownUnavailable
        )
    }

    func makeInput(for imageFile: ImageFile) -> ImageInsightInput {
        let metadata = ImageMetadataService().extractMetadata(from: imageFile.url)
        return ImageInsightInput(
            fileType: imageFile.type.localizedDescription ?? imageFile.type.identifier,
            dimensions: metadata.dimensions,
            fileSize: imageFile.formattedSize,
            colorProfile: colorProfileName(for: imageFile.url) ?? metadata.colorSpace,
            imageURL: imageFile.url
        )
    }

    func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult {
        let currentAvailability = availability()
        guard currentAvailability.isAvailable else {
            throw ImageInsightError.unavailable(currentAvailability.message)
        }
        guard let imageURL = input.imageURL else {
            throw ImageInsightError.imageUnavailable
        }

        let perception = await perceptionService.analyze(url: imageURL)
        try Task.checkCancellation()

        var generatedSummary: String?
        if perception.evidence.supportsNarrativeGeneration {
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                do {
                    generatedSummary = try await generateSummary(for: perception)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    Logger.warning(
                        "Apple Intelligence summary failed; using grounded local result",
                        context: "AIInsights"
                    )
                }
            }
            #endif
        }
        try Task.checkCancellation()

        return ImageInsightResultBuilder.build(
            input: input,
            perception: perception,
            generatedSummary: generatedSummary
        )
    }

    private func colorProfileName(for url: URL) -> String? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        return properties[kCGImagePropertyProfileName as String] as? String
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
private extension AppleIntelligenceInsightsService {
    static func modelAvailability() -> ImageInsightModelAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        @unknown default:
            return .unknownUnavailable
        }
    }

    func generateSummary(for perception: ImagePerceptionResult) async throws -> String {
        let session = LanguageModelSession(
            model: .default,
            instructions: ImageInsightPromptBuilder.systemInstruction
        )
        let options = GenerationOptions(
            sampling: .greedy,
            maximumResponseTokens: 120
        )
        let response = try await session.respond(
            to: ImageInsightPromptBuilder.prompt(for: perception),
            generating: GeneratedImageSummary.self,
            options: options
        )
        return response.content.summary
    }
}

@available(macOS 26.0, *)
@Generable(description: "One cautious sentence based only on the supplied on-device Vision observations.")
private struct GeneratedImageSummary {
    @Guide(description: "One sentence. Restate only supplied observations. Add no visual details or proper names.")
    let summary: String
}
#endif
