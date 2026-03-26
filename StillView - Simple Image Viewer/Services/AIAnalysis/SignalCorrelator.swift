import Foundation
import AppKit
import os.log

/// Cross-signal correlation engine that combines independent analysis results
/// to boost confidence when multiple sources agree and infer contextual signals
/// (e.g., "golden hour", "dining scene") that no single detector can determine alone.
///
/// Inserted into the pipeline after parallel analysis tasks complete but before
/// purpose detection, caption generation, and insight synthesis.
final class SignalCorrelator {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.vinny.stillview", category: "SignalCorrelator")

    // MARK: - Concept Mapping (ResNet ↔ Vision cross-model agreement)

    /// Shared concept map — single source of truth in AIAnalysisConstants
    private static var conceptMap: [String: String] { AIAnalysisConstants.conceptMap }

    // MARK: - Public Interface

    /// Correlate signals from multiple independent analysis sources.
    /// Returns boosted classifications and inferred contextual signals.
    func correlateSignals(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        scenes: [SceneClassification],
        colors: [DominantColor],
        text: [RecognizedText],
        enhancedVision: EnhancedVisionResult?,
        qualityMetrics: ImageQualityAssessment.Metrics
    ) -> CorrelatedSignals {

        // Step 1: Boost classifications via cross-model concept agreement
        let boostedClassifications = boostByConceptAgreement(classifications)

        // Step 2: Boost classifications confirmed by object detection
        let detectionBoosted = boostByDetectionAgreement(
            boostedClassifications,
            objects: objects,
            enhancedVision: enhancedVision
        )

        // Step 3: Calculate agreement score across all sources
        let agreementScore = calculateAgreementScore(
            classifications: detectionBoosted,
            objects: objects,
            scenes: scenes,
            enhancedVision: enhancedVision
        )

        // Step 4: Infer contextual signals from multi-source combinations
        let inferredContext = inferContext(
            scenes: scenes,
            colors: colors,
            objects: objects,
            text: text,
            qualityMetrics: qualityMetrics,
            enhancedVision: enhancedVision
        )

        logger.info("Correlation complete: agreementScore=\(String(format: "%.2f", agreementScore)), inferred \(inferredContext.count) context(s)")

        return CorrelatedSignals(
            boostedClassifications: detectionBoosted,
            inferredContext: inferredContext,
            agreementScore: agreementScore
        )
    }

    // MARK: - Step 1: Cross-Model Concept Agreement

    /// When ResNet says "golden_retriever" and Vision says "dog", both are correct
    /// at different specificity levels. Boost the more specific term's confidence.
    private func boostByConceptAgreement(
        _ classifications: [ClassificationResult]
    ) -> [ClassificationResult] {
        let classificationsByID = Dictionary(
            classifications.map { ($0.identifier.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var boosted = classifications
        var appliedBoosts: [(specific: String, general: String, newConfidence: Float)] = []

        for (index, classification) in boosted.enumerated() {
            let normalizedID = classification.identifier.lowercased()
                .replacingOccurrences(of: " ", with: "_")

            guard let generalConcept = Self.conceptMap[normalizedID] else { continue }

            // Check if the general concept also appears in classifications
            if let generalClassification = classificationsByID[generalConcept] {
                // Cross-model agreement: boost the specific term
                let agreementBoost = AIAnalysisConstants.conceptAgreementBoost
                let newConfidence = min(1.0, classification.confidence + agreementBoost)

                // Only boost if meaningful improvement
                if newConfidence > classification.confidence {
                    boosted[index] = ClassificationResult(
                        identifier: classification.identifier,
                        confidence: newConfidence
                    )
                    appliedBoosts.append((
                        specific: classification.identifier,
                        general: generalConcept,
                        newConfidence: newConfidence
                    ))
                }

                // Also check if general term should be boosted by specific agreement
                if let generalIndex = boosted.firstIndex(where: {
                    $0.identifier.lowercased() == generalConcept
                }) {
                    let generalBoost = AIAnalysisConstants.reverseConceptAgreementBoost
                    let newGeneralConfidence = min(1.0, generalClassification.confidence + generalBoost)
                    boosted[generalIndex] = ClassificationResult(
                        identifier: boosted[generalIndex].identifier,
                        confidence: newGeneralConfidence
                    )
                }
            }
        }

        #if DEBUG
        for boost in appliedBoosts {
            logger.debug("Concept agreement: '\(boost.specific)' ↔ '\(boost.general)' → confidence \(String(format: "%.2f", boost.newConfidence))")
        }
        #endif

        return boosted
    }

    // MARK: - Step 2: Detection Agreement

    /// Boost classification confidence when object detection independently confirms the subject.
    private func boostByDetectionAgreement(
        _ classifications: [ClassificationResult],
        objects: [DetectedObject],
        enhancedVision: EnhancedVisionResult?
    ) -> [ClassificationResult] {
        let objectIdentifiers = Set(objects.map { $0.identifier.lowercased() })
        let animalSpecies = Set((enhancedVision?.animals ?? []).map { $0.species.lowercased() })

        return classifications.map { classification in
            let id = classification.identifier.lowercased()
            var boost: Float = 0

            // Object detection confirms classification
            if objectIdentifiers.contains(where: { id.contains($0) || $0.contains(id) }) {
                boost += AIAnalysisConstants.detectionAgreementBoost
            }

            // Animal recognition confirms animal classification
            if !animalSpecies.isEmpty && animalSpecies.contains(where: { id.contains($0) || $0.contains(id) }) {
                boost += AIAnalysisConstants.detectionAgreementBoost
            }

            // Person/face detection confirms person classification
            let hasPersonDetection = objectIdentifiers.contains("person") || objectIdentifiers.contains("face")
            if hasPersonDetection && (id.contains("person") || id.contains("portrait") || id.contains("face")) {
                boost += AIAnalysisConstants.personDetectionBoost
            }

            guard boost > 0 else { return classification }

            let newConfidence = min(1.0, classification.confidence + boost)
            return ClassificationResult(
                identifier: classification.identifier,
                confidence: newConfidence
            )
        }
    }

    // MARK: - Step 3: Agreement Score

    /// Calculate how well different analysis sources agree on the primary subject.
    /// Higher scores mean more reliable identification. Range: 0.0 to 1.0
    private func calculateAgreementScore(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        scenes: [SceneClassification],
        enhancedVision: EnhancedVisionResult?
    ) -> Double {
        guard let topClassification = classifications.first else { return 0.0 }

        let topID = topClassification.identifier.lowercased()
        var sourcesAgreeing = 1 // Classification itself counts as 1
        let totalSources = 4   // classification, objects, scenes, enhancedVision

        // Check if objects agree
        let objectsAgree = objects.contains { obj in
            let objID = obj.identifier.lowercased()
            return topID.contains(objID) || objID.contains(topID) || shareConcept(topID, objID)
        }
        if objectsAgree { sourcesAgreeing += 1 }

        // Check if scenes are consistent (not contradictory)
        let scenesConsistent = !scenes.prefix(3).contains { scene in
            contradicts(classification: topID, scene: scene.identifier.lowercased())
        }
        if scenesConsistent && !scenes.isEmpty { sourcesAgreeing += 1 }

        // Check if enhanced vision agrees
        if let enhanced = enhancedVision {
            let animalsAgree = (enhanced.animals ?? []).contains { animal in
                topID.contains(animal.species.lowercased())
            }
            if animalsAgree { sourcesAgreeing += 1 }
        }

        return Double(sourcesAgreeing) / Double(totalSources)
    }

    // MARK: - Step 4: Context Inference

    /// Infer high-level contextual signals from multi-source combinations
    /// that no single detector can determine alone.
    private func inferContext(
        scenes: [SceneClassification],
        colors: [DominantColor],
        objects: [DetectedObject],
        text: [RecognizedText],
        qualityMetrics: ImageQualityAssessment.Metrics,
        enhancedVision: EnhancedVisionResult?
    ) -> [InferredContext] {
        let sceneIDs = Set(scenes.map { $0.identifier.lowercased() })
        let objectIDs = Set(objects.map { $0.identifier.lowercased() })
        let colorInfo = analyzeColorTemperature(colors)

        let isOutdoor = sceneIDs.contains(where: {
            $0.contains("outdoor") || $0.contains("nature") || $0.contains("landscape") ||
            $0.contains("beach") || $0.contains("park") || $0.contains("mountain")
        })
        let hasPerson = objectIDs.contains("person") || objectIDs.contains("face")
        let isIndoor = sceneIDs.contains(where: {
            $0.contains("indoor") || $0.contains("room") || $0.contains("restaurant") || $0.contains("office")
        })

        var inferred: [InferredContext] = []

        // Each check is a small focused method
        if let lighting = inferLighting(isOutdoor: isOutdoor, colorInfo: colorInfo, luminance: qualityMetrics.luminance) {
            inferred.append(lighting)
        }
        if let night = inferNightScene(isOutdoor: isOutdoor, luminance: qualityMetrics.luminance) {
            inferred.append(night)
        }
        if let dining = inferDining(hasPerson: hasPerson, objectIDs: objectIDs, sceneIDs: sceneIDs, isIndoor: isIndoor) {
            inferred.append(dining)
        }
        if let meeting = inferMeeting(hasPerson: hasPerson, isIndoor: isIndoor, text: text) {
            inferred.append(meeting)
        }
        if let pet = inferPetPortrait(hasPerson: hasPerson, enhancedVision: enhancedVision) {
            inferred.append(pet)
        }
        if let active = inferActiveScene(hasPerson: hasPerson, isOutdoor: isOutdoor, enhancedVision: enhancedVision) {
            inferred.append(active)
        }

        return inferred
    }

    // MARK: - Context Inference Helpers

    /// Infer golden hour or sunset — mutually exclusive, pick higher confidence
    private func inferLighting(isOutdoor: Bool, colorInfo: ColorTemperatureInfo, luminance: Double) -> InferredContext? {
        guard isOutdoor else { return nil }

        let ghRange = AIAnalysisConstants.goldenHourLuminanceRange
        let ssRange = AIAnalysisConstants.sunsetLuminanceRange

        var candidates: [(InferredContext.ContextType, Double, String)] = []

        if colorInfo.warmRatio > AIAnalysisConstants.goldenHourWarmRatio && ghRange.contains(luminance) {
            let confidence = min(0.85, 0.5 + colorInfo.warmRatio * 0.3)
            candidates.append((.goldenHour, confidence, "Golden hour lighting detected from warm tones and outdoor setting"))
        }

        if colorInfo.warmRatio > AIAnalysisConstants.sunsetWarmRatio && ssRange.contains(luminance) {
            let confidence = min(0.80, 0.4 + colorInfo.warmRatio * 0.35)
            candidates.append((.sunset, confidence, "Sunset conditions inferred from warm palette and diminishing light"))
        }

        // Pick the higher-confidence result to avoid golden hour + sunset overlap
        guard let best = candidates.max(by: { $0.1 < $1.1 }) else { return nil }
        return InferredContext(type: best.0, confidence: best.1, description: best.2)
    }

    private func inferNightScene(isOutdoor: Bool, luminance: Double) -> InferredContext? {
        guard isOutdoor, luminance < AIAnalysisConstants.nightSceneMaxLuminance else { return nil }
        return InferredContext(
            type: .nightScene,
            confidence: AIAnalysisConstants.nightSceneConfidence,
            description: "Night scene detected from low ambient light in outdoor setting"
        )
    }

    private func inferDining(hasPerson: Bool, objectIDs: Set<String>, sceneIDs: Set<String>, isIndoor: Bool) -> InferredContext? {
        let hasFood = objectIDs.contains(where: {
            $0.contains("food") || $0.contains("dish") || $0.contains("plate") || $0.contains("bowl")
        }) || sceneIDs.contains(where: {
            $0.contains("restaurant") || $0.contains("dining") || $0.contains("cafe") || $0.contains("kitchen")
        })
        guard hasPerson, hasFood else { return nil }
        let confidence = isIndoor ? AIAnalysisConstants.diningIndoorConfidence : AIAnalysisConstants.diningOutdoorConfidence
        return InferredContext(
            type: .dining,
            confidence: confidence,
            description: "Dining context from person and food in \(isIndoor ? "indoor" : "outdoor") setting"
        )
    }

    private func inferMeeting(hasPerson: Bool, isIndoor: Bool, text: [RecognizedText]) -> InferredContext? {
        let totalTextLength = text.reduce(0) { $0 + $1.text.count }
        guard hasPerson, isIndoor,
              text.count >= AIAnalysisConstants.meetingMinTextRegions,
              totalTextLength > AIAnalysisConstants.meetingMinTextLength else { return nil }
        return InferredContext(
            type: .meeting,
            confidence: AIAnalysisConstants.meetingConfidence,
            description: "Meeting or presentation context from people, text, and indoor setting"
        )
    }

    private func inferPetPortrait(hasPerson: Bool, enhancedVision: EnhancedVisionResult?) -> InferredContext? {
        let hasAnimal = !(enhancedVision?.animals ?? []).isEmpty
        guard hasAnimal, !hasPerson else { return nil }
        let animalName = enhancedVision?.animals?.first?.displayName ?? "animal"
        return InferredContext(
            type: .petPortrait,
            confidence: AIAnalysisConstants.petPortraitConfidence,
            description: "Pet portrait featuring \(animalName)"
        )
    }

    private func inferActiveScene(hasPerson: Bool, isOutdoor: Bool, enhancedVision: EnhancedVisionResult?) -> InferredContext? {
        guard hasPerson, isOutdoor,
              let pose = enhancedVision?.bodyPose,
              let activity = pose.detectedActivity,
              activity != "standing" && activity != "sitting" else { return nil }
        return InferredContext(
            type: .activeScene,
            confidence: Double(pose.confidence),
            description: "Active scene with person \(activity) outdoors"
        )
    }

    // MARK: - Helpers

    /// Analyze color temperature from dominant colors
    private func analyzeColorTemperature(_ colors: [DominantColor]) -> ColorTemperatureInfo {
        guard !colors.isEmpty else {
            return ColorTemperatureInfo(warmRatio: 0.5, coolRatio: 0.5)
        }

        var warmWeight: Double = 0
        var coolWeight: Double = 0

        for color in colors {
            guard let rgbColor = color.color.usingColorSpace(.deviceRGB) else { continue }
            let hue = rgbColor.hueComponent

            // Warm: reds, oranges, yellows (hue 0-60° or 300-360°)
            if hue < AIAnalysisConstants.warmHueUpperBound || hue > AIAnalysisConstants.warmHueLowerBound {
                warmWeight += color.percentage
            }
            // Cool: blues, cyans, some greens (hue 120-240°)
            else if hue > AIAnalysisConstants.coolHueLowerBound && hue < AIAnalysisConstants.coolHueUpperBound {
                coolWeight += color.percentage
            }
        }

        let total = max(warmWeight + coolWeight, 0.01)
        return ColorTemperatureInfo(
            warmRatio: warmWeight / total,
            coolRatio: coolWeight / total
        )
    }

    /// Check if two identifiers share a concept via the concept map
    private func shareConcept(_ a: String, _ b: String) -> Bool {
        let normalizedA = a.replacingOccurrences(of: " ", with: "_")
        let normalizedB = b.replacingOccurrences(of: " ", with: "_")

        let conceptA = Self.conceptMap[normalizedA]
        let conceptB = Self.conceptMap[normalizedB]

        // Same general concept
        if let cA = conceptA, let cB = conceptB, cA == cB { return true }
        // One is the general concept of the other
        if conceptA == b || conceptB == a { return true }

        return false
    }

    /// Contradiction pairs for scene/classification consistency checking
    private static let contradictionPairs: [(Set<String>, Set<String>)] = [
        (["indoor", "inside", "room"], ["outdoor", "outside", "nature", "landscape"]),
        (["day", "sunny", "bright"], ["night", "dark", "evening"]),
    ]

    /// Check if a classification contradicts a scene
    private func contradicts(classification: String, scene: String) -> Bool {
        for (groupA, groupB) in Self.contradictionPairs {
            let classInA = groupA.contains(where: { classification.contains($0) })
            let sceneInB = groupB.contains(where: { scene.contains($0) })
            if classInA && sceneInB { return true }

            let classInB = groupB.contains(where: { classification.contains($0) })
            let sceneInA = groupA.contains(where: { scene.contains($0) })
            if classInB && sceneInA { return true }
        }

        return false
    }
}

// MARK: - Supporting Types

/// Result of cross-signal correlation
struct CorrelatedSignals: Equatable {
    /// Classifications with confidence adjusted by multi-source agreement
    let boostedClassifications: [ClassificationResult]

    /// Contextual inferences derived from combining multiple signals
    let inferredContext: [InferredContext]

    /// How well different sources agree on the primary subject (0.0 to 1.0)
    /// Higher = more reliable identification
    let agreementScore: Double
}

/// A contextual inference that no single detector can determine alone
struct InferredContext: Equatable {
    /// Type of inferred context
    let type: ContextType

    /// Confidence in this inference (0.0 to 1.0)
    let confidence: Double

    /// Human-readable description of what was inferred and why
    let description: String

    enum ContextType: String {
        case goldenHour = "golden_hour"
        case sunset = "sunset"
        case nightScene = "night_scene"
        case dining = "dining"
        case meeting = "meeting"
        case petPortrait = "pet_portrait"
        case activeScene = "active_scene"
    }
}

/// Color temperature analysis result
private struct ColorTemperatureInfo {
    let warmRatio: Double
    let coolRatio: Double
}
