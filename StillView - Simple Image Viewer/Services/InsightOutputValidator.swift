import Foundation

/// Shape checks do not establish visual accuracy. Exact excerpts always resolve to Vision's
/// original observations. Generated prose is not a transcription channel: neither quotes nor
/// digit-bearing values belong there, even when matching text appears elsewhere in the image.
enum InsightOutputValidator {
    static func validatedTextLineIndices(_ indices: [Int], lineCount: Int) -> [Int]? {
        guard lineCount > 0,
              (1...3).contains(indices.count),
              Set(indices).count == indices.count,
              indices.allSatisfy({ (0..<lineCount).contains($0) }) else {
            return nil
        }
        return indices.sorted()
    }

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
        let allowedIndices = Set(modelTextLineIndices ?? Array(perception.textObservations.indices))
        let indices = validatedTextLineIndices(
            generated.selectedTextLineIndices, lineCount: perception.recognizedText.count
        ).flatMap { selected in selected.allSatisfy(allowedIndices.contains) ? selected : nil }
        // An invalid optional selection cannot rewrite or replace OCR; fall back to original reading order.
        let selected = indices?.map { perception.recognizedText[$0] }
            ?? Array(perception.recognizedText.prefix(3))
        var limitations = uncertainties
        if perception.textWasTruncated {
            limitations.append("Text extraction was limited for this image. Some lines are not included.")
        }
        if allowedIndices.count < perception.textObservations.count {
            limitations.append("The description used limited text evidence. All extracted text is available below.")
        }
        return ImageInsightResult(
            title: title,
            summary: summary,
            usefulDetails: details,
            tags: generated.tags,
            limitations: limitations,
            recognizedText: perception.recognizedText,
            selectedTextLines: selected,
            textSelectionSource: indices == nil ? .vision : .appleIntelligence,
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
