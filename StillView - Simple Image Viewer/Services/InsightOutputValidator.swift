import Foundation

/// A small final guard for the only prose Foundation Models still generates. Structural fields,
/// titles, details, tags, and limitations are composed deterministically elsewhere.
enum InsightOutputValidator {
    private static let peopleWords: Set<String> = [
        "adult", "boy", "child", "children", "family", "friend", "friends", "girl", "group",
        "man", "men", "people", "person", "woman", "women"
    ]

    private static let unsupportedDetailWords: Set<String> = [
        "black", "blue", "brown", "celebrating", "celebration", "drinking", "driving", "eating",
        "gold", "golden", "green", "parked", "party", "purple", "race", "racing", "red", "running",
        "sitting", "smiling", "speeds", "standing", "walking", "wedding", "white", "yellow"
    ]

    private static let allowedCapitalizedWords: Set<String> = ["Apple", "Vision"]

    static func isAcceptable(summary: String, perception: ImagePerceptionResult) -> Bool {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (12...320).contains(trimmed.count) else { return false }

        let evidence = perception.evidence
        let summaryWords = normalizedWords(trimmed)
        let evidenceWords = evidenceTokens(evidence)
        guard !summaryWords.isDisjoint(with: evidenceWords) else { return false }

        if evidence.faceCount == 0, !summaryWords.isDisjoint(with: peopleWords) {
            return false
        }
        if evidence.recognizedText.isEmpty,
           trimmed.contains("\"") || trimmed.contains("“") || trimmed.contains("”") {
            return false
        }

        let unsupported = summaryWords.intersection(unsupportedDetailWords).subtracting(evidenceWords)
        guard unsupported.isEmpty else { return false }

        return hasNoUnsupportedProperNoun(in: trimmed, evidence: evidence)
    }

    private static func evidenceTokens(_ evidence: ImageInsightEvidence) -> Set<String> {
        let labels = (evidence.subjectLabels + evidence.sceneLabels)
            .flatMap { normalizedWords(displayLabel($0.identifier)) }
        let text = evidence.recognizedText.flatMap(normalizedWords)
        var tokens = Set(labels + text)

        if evidence.faceCount > 0 {
            tokens.formUnion(["face", "faces", "person", "people"])
        }
        if !evidence.recognizedText.isEmpty {
            tokens.formUnion(["text", "words", "visible", "recognized"])
        }
        return tokens
    }

    private static func hasNoUnsupportedProperNoun(
        in summary: String,
        evidence: ImageInsightEvidence
    ) -> Bool {
        let evidenceWords = Set(evidence.recognizedText.flatMap(normalizedWords))
        let rawWords = summary
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }

        for (index, word) in rawWords.enumerated() where index > 0 {
            guard word.first?.isUppercase == true else { continue }
            guard !allowedCapitalizedWords.contains(word), !evidenceWords.contains(word.lowercased()) else {
                continue
            }
            return false
        }
        return true
    }

    private static func normalizedWords(_ text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 2 }
        )
    }
}
