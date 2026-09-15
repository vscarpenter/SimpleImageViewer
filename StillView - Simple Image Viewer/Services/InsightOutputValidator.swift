import Foundation

/// Shape checks do not establish visual accuracy. Exact excerpts always resolve to Vision's
/// original observations, and literal quotes or numeric transcriptions must exist in that evidence.
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
        let narrative = [title, summary] + generated.details + generated.tags + generated.uncertainties
        guard !title.isEmpty, title.count <= 120,
              !summary.isEmpty, summary.count <= 800,
              generated.details.count <= 3, generated.tags.count <= 5, generated.uncertainties.count <= 2,
              narrative.allSatisfy({ $0.count <= 800 }),
              hasOnlySupportedTranscriptions(narrative, recognizedText: perception.recognizedText) else {
            throw ImageInsightError.invalidGeneratedContent
        }
        let allowedIndices = Set(modelTextLineIndices ?? Array(perception.textObservations.indices))
        let indices = validatedTextLineIndices(
            generated.selectedTextLineIndices, lineCount: perception.recognizedText.count
        ).flatMap { selected in selected.allSatisfy(allowedIndices.contains) ? selected : nil }
        // An invalid optional selection cannot rewrite or replace OCR; fall back to original reading order.
        let selected = indices?.map { perception.recognizedText[$0] }
            ?? Array(perception.recognizedText.prefix(3))
        var limitations = generated.uncertainties
        if perception.textWasTruncated {
            limitations.append("Text extraction was limited for this image. Some lines are not included.")
        }
        if allowedIndices.count < perception.textObservations.count {
            limitations.append("The description used limited text evidence. All extracted text is available below.")
        }
        return ImageInsightResult(
            title: title,
            summary: summary,
            usefulDetails: generated.details,
            tags: generated.tags,
            limitations: limitations,
            recognizedText: perception.recognizedText,
            selectedTextLines: selected,
            textSelectionSource: indices == nil ? .vision : .appleIntelligence,
            provenance: provenance
        )
    }

    private static func hasOnlySupportedTranscriptions(_ prose: [String], recognizedText: [String]) -> Bool {
        let quotedPatterns = [#"[\"“]([^\"”]+)[\"”]"#, #"(?<![\p{L}])['‘]([^'’]+)['’](?![\p{L}])"#]
        for pattern in quotedPatterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
            let quotes = prose.flatMap { excerpts(in: $0, matching: expression, capture: 1) }
            guard quotes.allSatisfy({ quote in recognizedText.contains { $0.contains(quote) } }) else { return false }
        }
        // Compare complete digit-bearing tokens: RX999, 12A, and $0058.00 cannot be accepted
        // through a partial digit match. Plain contractions are not treated as transcriptions.
        let tokenPattern = #"(?<![\p{L}\p{N}])[$€£]?[+-]?[\p{L}\p{N}]+(?:[.,:/%_\-][\p{L}\p{N}]+)*%?"#
        guard let expression = try? NSRegularExpression(pattern: tokenPattern) else { return false }
        let observed = Set(recognizedText.flatMap { excerpts(in: $0, matching: expression) })
        return prose.flatMap { excerpts(in: $0, matching: expression) }
            .filter { $0.rangeOfCharacter(from: .decimalDigits) != nil }
            .allSatisfy(observed.contains)
    }

    private static func excerpts(in text: String, matching expression: NSRegularExpression, capture: Int = 0) -> [String] {
        expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range(at: capture), in: text) else { return nil }
            return String(text[range])
        }
    }
}
