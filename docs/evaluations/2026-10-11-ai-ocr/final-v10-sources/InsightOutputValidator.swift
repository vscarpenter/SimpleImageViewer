import Foundation

/// Shape checks do not establish visual accuracy. Exact excerpts always resolve to Vision's
/// original observations. Generated prose is not a transcription channel: neither quotes nor
/// digit-bearing values belong there, even when matching text appears elsewhere in the image.
enum InsightOutputValidator {
    static func result(
        from generated: GeneratedImageInsight,
        perception: ImagePerceptionResult,
        provenance: ImageInsightProvenance,
        modelTextLineIndices: [Int]? = nil
    ) throws -> ImageInsightResult {
        let title = generated.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = generated.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = [generated.additionalDetail].compactMap { $0 }
        let uncertainties = [generated.uncertainty].compactMap { $0 }
        let narrative = [title, summary] + details + generated.tags + uncertainties
        guard !title.isEmpty, title.count <= 120,
              !summary.isEmpty, summary.count <= 800,
              generated.tags.count <= 5,
              narrative.allSatisfy({ $0.count <= 800 }),
              hasNoTranscriptions(narrative) else {
            throw ImageInsightError.invalidGeneratedContent
        }
        // Keep the historical result shape, but never ask a language model to select source text.
        let selected = Array(perception.recognizedText.prefix(3))
        var limitations = uncertainties
        if perception.textWasTruncated {
            limitations.append(ImagePerceptionResult.incompleteTextMessage)
        }
        return ImageInsightResult(
            title: title,
            summary: summary,
            usefulDetails: details,
            tags: generated.tags,
            limitations: limitations,
            recognizedText: perception.recognizedText,
            selectedTextLines: selected,
            textSelectionSource: .vision,
            provenance: provenance
        )
    }

    private static func hasNoTranscriptions(_ prose: [String]) -> Bool {
        // Exact token matches cannot prove that a price belongs to a particular table row.
        // Keep every digit-bearing value in the separately displayed original OCR instead.
        guard prose.allSatisfy({ $0.rangeOfCharacter(from: .decimalDigits) == nil }) else { return false }
        let quotedPatterns = [
            #"[\"“]([^\"”]+)[\"”]"#,
            #"(?<![\p{L}])['‘]([^'’]+)['’](?![\p{L}])"#,
            #"[「『«]([^」』»]+)[」』»]"#
        ]
        return quotedPatterns.allSatisfy { pattern in
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
            return prose.allSatisfy {
                expression.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) == nil
            }
        }
    }
}
