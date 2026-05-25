import Foundation
import ImageIO
import UniformTypeIdentifiers

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
        let dateFormatter = Self.dateFormatter

        return ImageInsightInput(
            fileName: imageFile.name,
            fileType: imageFile.type.localizedDescription ?? imageFile.type.identifier,
            dimensions: metadata.dimensions,
            fileSize: imageFile.formattedSize,
            creationDate: dateFormatter.string(from: imageFile.creationDate),
            modificationDate: dateFormatter.string(from: imageFile.modificationDate),
            colorProfile: colorProfileName(for: imageFile.url) ?? metadata.colorSpace,
            metadataDescription: metadata.description,
            keywords: metadata.keywords,
            visualSignals: [],
            cameraSignals: cameraSignals(from: metadata),
            imageURL: imageFile.url
        )
    }

    func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult {
        let currentAvailability = availability()
        guard currentAvailability.isAvailable else {
            throw ImageInsightError.unavailable(currentAvailability.message)
        }

        // Run on-device Vision perception lazily, only when the user actually requests
        // an insight. This avoids paying perception cost on every image navigation.
        let perception: ImagePerceptionResult
        let enrichedInput: ImageInsightInput
        if let url = input.imageURL {
            perception = await perceptionService.analyze(url: url)
            enrichedInput = input.withVisualSignals(perception.asSignals)
        } else {
            perception = .empty
            enrichedInput = input
        }

        let contentType = ImageContentTypeClassifier.classify(perception)
        let profile = GenerationProfile.profile(for: contentType)

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let result = try await generate(input: enrichedInput, type: contentType, profile: profile)

            let validation = InsightOutputValidator.validate(result, input: enrichedInput)
            if case .passed = validation {
                return result
            }

            if case .failed(let reasons) = validation {
                let retryResult = try await generate(
                    input: enrichedInput,
                    type: contentType,
                    profile: profile.retryProfile,
                    correctionHint: InsightOutputValidator.correctionHint(for: reasons)
                )
                return retryResult
            }

            return result
        }
        #endif

        throw ImageInsightError.unavailable("AI Insights require macOS 26 and the Foundation Models framework.")
    }

    /// Builds the "context only" camera/EXIF/GPS bucket. These signals must never become
    /// the title or subject — the prompt enforces that — but they may appear in
    /// `usefulDetails` when genuinely informative.
    private func cameraSignals(from metadata: ImageMetadataService.ImageMetadata) -> [String] {
        var signals: [String] = []

        if let camera = metadata.camera {
            let cameraName = [camera.make, camera.model]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            if !cameraName.isEmpty {
                signals.append("Camera: \(cameraName)")
            }

            if let settings = camera.settings, !settings.isEmpty {
                signals.append("Camera settings: \(settings)")
            }
        }

        if let captureDate = metadata.captureDate {
            signals.append("Capture date: \(Self.dateFormatter.string(from: captureDate))")
        }

        if let location = metadata.location {
            signals.append("GPS metadata: \(location.description)")
        }

        if let colorSpace = metadata.colorSpace, !colorSpace.isEmpty {
            signals.append("Color space: \(colorSpace)")
        }

        return signals
    }

    private func colorProfileName(for url: URL) -> String? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }

        return properties[kCGImagePropertyProfileName as String] as? String
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
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

    /// Runs a single FoundationModels generation pass with the given profile and optional
    /// correction hint. Extracted so the first attempt and validation retry share one path.
    func generate(
        input: ImageInsightInput,
        type: ImageContentType,
        profile: GenerationProfile,
        correctionHint: String? = nil
    ) async throws -> ImageInsightResult {
        let session = LanguageModelSession(
            model: .default,
            instructions: ImageInsightPromptBuilder.systemInstruction
        )

        var prompt = ImageInsightPromptBuilder.prompt(for: input, type: type)
        if let hint = correctionHint {
            prompt += "\n\nCORRECTION: \(hint)"
        }

        // .random(top:) gives the model just enough freedom to weave weaker signals
        // (lower-confidence classifications, OCR text) into its output. .greedy ignores
        // temperature entirely and produces overly-conservative argmax descriptions
        // that miss anything not in the top-1 classification.
        let options = GenerationOptions(
            sampling: .random(top: profile.topK),
            temperature: profile.temperature,
            maximumResponseTokens: profile.maxTokens
        )

        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedImageInsight.self,
                options: options
            )
            return response.content.result
        } catch let generationError as LanguageModelSession.GenerationError {
            throw Self.mapGenerationError(generationError)
        }
    }

    /// Maps Foundation Models generation errors to user-facing `ImageInsightError` cases.
    /// Apple's `localizedDescription` is often technical or empty for these cases; the panel
    /// surfaces whatever message we put here verbatim, so it needs to be reader-friendly.
    static func mapGenerationError(_ error: LanguageModelSession.GenerationError) -> ImageInsightError {
        switch error {
        case .guardrailViolation:
            return .generationFailed("Apple Intelligence won't summarize this image's content.")
        case .unsupportedLanguageOrLocale:
            return .generationFailed("Apple Intelligence doesn't support this language yet.")
        case .assetsUnavailable:
            return .generationFailed("Apple Intelligence is still preparing its on-device model. Try again in a few minutes.")
        case .exceededContextWindowSize:
            return .generationFailed("This image has too many visual signals for Apple Intelligence to summarize.")
        case .rateLimited:
            return .generationFailed("Apple Intelligence is busy. Try again in a moment.")
        case .concurrentRequests:
            return .generationFailed("Another insight is already being generated. Please wait for it to finish.")
        case .decodingFailure:
            return .invalidGeneratedContent
        case .unsupportedGuide:
            return .generationFailed("Apple Intelligence couldn't follow the response format.")
        case .refusal:
            return .generationFailed("Apple Intelligence declined to describe this image.")
        @unknown default:
            return .generationFailed(error.localizedDescription)
        }
    }
}

@available(macOS 26.0, *)
@Generable(description: "A concise image insight describing the visible content of a local image, grounded in on-device Vision analysis. Camera and EXIF metadata are supplementary context only and must not drive the title or subject.")
private struct GeneratedImageInsight {
    @Guide(description: "A short title naming what the image shows — its subject, scene, or activity. Never use the camera model, lens, or shooting settings as the title. A title like 'iPhone 13 Pro Max Capture' is forbidden; describe the photograph's content instead.")
    let title: String

    @Guide(description: "One or two sentences describing the visible content of the image, drawn from the on-device Vision signals (scene categories, recognized text, faces). Do not describe the camera or shooting settings.")
    let summary: String

    @Guide(description: "A cautious description of what the image likely depicts, based on the primary visual signals. If the visual signals are sparse or empty, say so plainly rather than guessing from EXIF.")
    let likelyContent: String

    @Guide(description: "Up to 4 short bullet points of useful details about the image. Lead with content; include camera or EXIF only when genuinely helpful (e.g. capture date for a memory). Never repeat the camera model as a detail.")
    let usefulDetails: [String]

    @Guide(description: "Up to 6 short content-focused tags describing the image (e.g. 'group photo', 'indoor', 'sports venue', 'celebration'). Avoid camera-model or EXIF-only tags.")
    let tags: [String]

    @Guide(description: "Required. What this insight cannot determine from local signals (e.g. 'specific names of people', 'precise location', 'event identity').")
    let limitations: [String]

    var result: ImageInsightResult {
        ImageInsightResult(
            title: title,
            summary: summary,
            likelyContent: likelyContent,
            usefulDetails: usefulDetails,
            tags: tags,
            limitations: limitations
        )
    }
}
#endif
