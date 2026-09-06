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
        var resourceURL = imageFile.url
        resourceURL.removeAllCachedResourceValues()
        let resourceValues = try? resourceURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let byteCount = resourceValues.flatMap { $0.fileSize }.map(Int64.init)
        let fileSize = byteCount.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
            ?? imageFile.formattedSize
        let metadata = ImageMetadataService().extractMetadata(from: imageFile.url)
        return ImageInsightInput(
            fileType: imageFile.type.localizedDescription ?? imageFile.type.identifier,
            dimensions: metadata.dimensions,
            fileSize: fileSize,
            colorProfile: colorProfileName(for: imageFile.url) ?? metadata.colorSpace,
            imageURL: imageFile.url,
            fileByteCount: byteCount,
            fileModificationDate: resourceValues?.contentModificationDate
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

        let perception = try await perceptionService.analyze(url: imageURL)
        try Task.checkCancellation()

        var selectedTextLineIndices: [Int]?
        if perception.evidence.supportsTextSelection {
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                do {
                    selectedTextLineIndices = try await selectTextLines(for: perception)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    Logger.warning(
                        "Apple Intelligence text selection failed; using original reading order",
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
            selectedTextLineIndices: selectedTextLineIndices
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

    func selectTextLines(for perception: ImagePerceptionResult) async throws -> [Int] {
        let session = LanguageModelSession(
            model: .default,
            instructions: ImageInsightPromptBuilder.systemInstruction
        )
        let options = GenerationOptions(
            sampling: .greedy,
            maximumResponseTokens: 64
        )
        let response = try await session.respond(
            to: ImageInsightPromptBuilder.prompt(for: perception),
            generating: SelectedImageTextLines.self,
            options: options
        )
        return response.content.lineIndices
    }
}

@available(macOS 26.0, *)
@Generable(description: "Indices of useful recognized text lines. Never rewritten text or a description.")
private struct SelectedImageTextLines {
    @Guide(description: "One to three different zero-based indices from the supplied OCR lines.", .count(1...3))
    let lineIndices: [Int]
}
#endif
