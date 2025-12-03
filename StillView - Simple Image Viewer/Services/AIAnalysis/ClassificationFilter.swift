import Foundation

/// Filters and merges image classifications
/// Removes misleading classifications (like "Optical Equipment" for people wearing glasses)
/// Prioritizes relevant subjects over generic/background classifications
final class ClassificationFilter {

    // MARK: - Public Interface

    /// Merge classifications from multiple sources (Vision + ResNet)
    /// Now includes background filtering, prioritization, and confidence boosting
    func mergeClassifications(
        visionResults: [ClassificationResult],
        resnetResults: [ClassificationResult],
        hasPersonDetection: Bool = false,
        hasVehicleDetection: Bool = false,
        hasForegroundSubjects: Bool = false
    ) -> [ClassificationResult] {
        var mergedDict: [String: ClassificationResult] = [:]

        // Add Vision results
        for result in visionResults {
            mergedDict[result.identifier] = result
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

        // Convert back to array and sort by confidence
        var merged = Array(mergedDict.values)
            .sorted { $0.confidence > $1.confidence }

        Logger.ai("Initial merged classifications: \(merged.prefix(5).map { "\($0.identifier)(\(String(format: "%.2f", $0.confidence)))" }.joined(separator: ", "))")

        // Apply new filtering and prioritization logic
        merged = filterBackgroundClassifications(merged, hasForegroundSubjects: hasForegroundSubjects)
        merged = prioritizeSubjectClassifications(merged)
        merged = boostSubjectConfidence(merged, hasPersonDetection: hasPersonDetection, hasVehicleDetection: hasVehicleDetection)
        merged = deprioritizeGenericTerms(merged)

        Logger.ai("Final processed classifications: \(merged.prefix(5).map { "\($0.identifier)(\(String(format: "%.2f", $0.confidence)))" }.joined(separator: ", "))")

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

    /// Filter out background scene classifications when foreground subjects exist
    /// More intelligent filtering - only filter truly generic background terms
    func filterBackgroundClassifications(
        _ classifications: [ClassificationResult],
        hasForegroundSubjects: Bool
    ) -> [ClassificationResult] {
        guard hasForegroundSubjects else {
            Logger.ai("No foreground subjects detected, keeping all classifications")
            return classifications
        }

        // Only filter truly generic background terms that add no value
        // Keep nature/landscape terms as they might be the main subject
        let genericBackgroundTerms: Set<String> = [
            // Surface/ground terms
            "ground", "land", "wall", "background", "backdrop", "floor", "pavement",
            // Indoor/outdoor generic
            "indoor", "inside", "outdoor", "outside",
            // Vegetation background terms
            "trees in background", "shrubbery", "lawn", "meadow", "vegetation",
            "hillside", "foliage", "greenery", "bush", "hedge",
            // Sky/weather background
            "skyline", "horizon", "overcast", "cloudy sky", "clear sky",
            // Generic scene terms
            "scenery", "setting", "environment", "surroundings", "area"
        ]

        let filtered = classifications.filter { classification in
            let identifier = classification.identifier.lowercased()
            let specificity = AIAnalysisConstants.getSpecificity(identifier)

            // Always keep classifications with specificity >= 2
            if specificity >= 2 {
                return true
            }

            // Check if this is a truly generic background term
            let isGenericBackground = genericBackgroundTerms.contains { identifier.contains($0) }

            if !isGenericBackground {
                // Not a generic background term, keep it
                return true
            }

            // It's a generic background term - keep only if very high confidence (>75%)
            if classification.confidence > 0.75 {
                Logger.ai("Keeping high-confidence generic background: \(identifier) (\(String(format: "%.2f", classification.confidence)))")
                return true
            }

            // Otherwise filter out
            Logger.ai("Filtered generic background: \(identifier) (\(String(format: "%.2f", classification.confidence)))")
            return false
        }

        return filtered
    }

    /// Prioritize person and vehicle classifications by reordering them first
    /// Groups classifications into: person/vehicle, objects, scenes
    func prioritizeSubjectClassifications(
        _ classifications: [ClassificationResult]
    ) -> [ClassificationResult] {
        // Separate into priority groups
        var personVehicle: [ClassificationResult] = []
        var objects: [ClassificationResult] = []
        var scenes: [ClassificationResult] = []

        for classification in classifications {
            let identifier = classification.identifier.lowercased()

            if identifier.contains("person") ||
               identifier.contains("face") ||
               identifier.contains("portrait") ||
               identifier.contains("car") ||
               identifier.contains("vehicle") ||
               identifier.contains("automobile") ||
               identifier.contains("truck") ||
               identifier.contains("bus") ||
               identifier.contains("motorcycle") ||
               identifier.contains("bicycle") ||
               identifier.contains("sports car") ||
               identifier.contains("ferrari") ||
               identifier.contains("porsche") ||
               identifier.contains("lamborghini") ||
               identifier.contains("convertible") ||
               identifier.contains("sedan") ||
               identifier.contains("suv") ||
               identifier.contains("coupe") {
                personVehicle.append(classification)
            } else if identifier.contains("sky") ||
                      identifier.contains("land") ||
                      identifier.contains("landscape") ||
                      identifier.contains("outdoor") ||
                      identifier.contains("indoor") ||
                      identifier.contains("scenery") {
                scenes.append(classification)
            } else {
                objects.append(classification)
            }
        }

        // Reorder: person/vehicle first, then objects, then scenes
        let prioritized = personVehicle + objects + scenes

        if !personVehicle.isEmpty {
            Logger.ai("Prioritized person/vehicle classifications: \(personVehicle.map { $0.identifier }.joined(separator: ", "))")
        }

        return prioritized
    }

    /// Boost confidence of person/vehicle detections to ensure they're prioritized
    /// Increases confidence by 30% (capped at 1.0) when corresponding detection exists
    func boostSubjectConfidence(
        _ classifications: [ClassificationResult],
        hasPersonDetection: Bool,
        hasVehicleDetection: Bool
    ) -> [ClassificationResult] {
        return classifications.map { classification in
            let identifier = classification.identifier.lowercased()
            var boostedConfidence = classification.confidence

            // Boost person classifications if person detected
            if hasPersonDetection && (identifier.contains("person") || identifier.contains("portrait") || identifier.contains("face")) {
                let originalConfidence = boostedConfidence
                boostedConfidence = min(1.0, boostedConfidence * 1.3)
                if boostedConfidence != originalConfidence {
                    Logger.ai("Boosted person classification: \(identifier) \(String(format: "%.2f", originalConfidence)) -> \(String(format: "%.2f", boostedConfidence))")
                }
            }

            // Boost vehicle classifications if vehicle detected
            if hasVehicleDetection && (identifier.contains("car") || identifier.contains("vehicle") || identifier.contains("automobile") || 
                identifier.contains("truck") || identifier.contains("bus") || identifier.contains("motorcycle") || 
                identifier.contains("bicycle") || identifier.contains("sports car") || identifier.contains("ferrari") ||
                identifier.contains("porsche") || identifier.contains("lamborghini") || identifier.contains("convertible") ||
                identifier.contains("sedan") || identifier.contains("suv") || identifier.contains("coupe")) {
                let originalConfidence = boostedConfidence
                boostedConfidence = min(1.0, boostedConfidence * 1.3)
                if boostedConfidence != originalConfidence {
                    Logger.ai("Boosted vehicle classification: \(identifier) \(String(format: "%.2f", originalConfidence)) -> \(String(format: "%.2f", boostedConfidence))")
                }
            }

            return ClassificationResult(
                identifier: classification.identifier,
                confidence: boostedConfidence
            )
        }
    }

    // MARK: - Private Helpers

    /// Deprioritize generic and background classifications
    private func deprioritizeGenericTerms(_ classifications: [ClassificationResult]) -> [ClassificationResult] {
        var specific: [ClassificationResult] = []
        var generic: [ClassificationResult] = []
        var background: [ClassificationResult] = []

        for classification in classifications {
            if AIAnalysisConstants.isBackground(classification.identifier) {
                background.append(classification)
            } else if AIAnalysisConstants.isGeneric(classification.identifier) {
                generic.append(classification)
            } else {
                specific.append(classification)
            }
        }

        // Return specific first, then generic, then background
        return specific + generic + background
    }
}
