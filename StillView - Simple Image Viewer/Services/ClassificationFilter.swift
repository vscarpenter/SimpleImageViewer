import Foundation

/// Filters and merges image classifications
/// Removes misleading classifications (like "Optical Equipment" for people wearing glasses)
/// Prioritizes relevant subjects over generic/background classifications
final class ClassificationFilter {

    // MARK: - Public Interface

    /// Merge classifications from multiple sources (Vision + ResNet)
    func mergeClassifications(
        visionResults: [ClassificationResult],
        resnetResults: [ClassificationResult]
    ) -> [ClassificationResult] {
        var mergedDict: [String: ClassificationResult] = [:]

        // Add Vision results (keep highest confidence if duplicates)
        for result in visionResults {
            if let existing = mergedDict[result.identifier] {
                // Keep higher confidence within Vision results too
                if result.confidence > existing.confidence {
                    mergedDict[result.identifier] = result
                }
            } else {
                mergedDict[result.identifier] = result
            }
        }

        // Merge ResNet results, preferring higher confidence
        for result in resnetResults {
            if let existing = mergedDict[result.identifier] {
                // Keep higher confidence
                if result.confidence > existing.confidence {
                    mergedDict[result.identifier] = result
                }
            } else {
                mergedDict[result.identifier] = result
            }
        }

        // Convert back to array and sort by ranking score (specificity × confidence)
        let merged = Array(mergedDict.values)
            .sorted { classification1, classification2 in
                let score1 = AIAnalysisConstants.calculateRankingScore(
                    identifier: classification1.identifier,
                    confidence: classification1.confidence
                )
                let score2 = AIAnalysisConstants.calculateRankingScore(
                    identifier: classification2.identifier,
                    confidence: classification2.confidence
                )
                return score1 > score2
            }

        return merged
    }

    /// Filter out clothing/accessory classifications when person detected
    func filterForPersonDetection(
        _ classifications: [ClassificationResult],
        hasPersonOrFace: Bool
    ) -> [ClassificationResult] {
        guard hasPersonOrFace else {
            return classifications
        }

        return classifications.filter { classification in
            !AIAnalysisConstants.isClothingOrAccessory(classification.identifier)
        }
    }

}
