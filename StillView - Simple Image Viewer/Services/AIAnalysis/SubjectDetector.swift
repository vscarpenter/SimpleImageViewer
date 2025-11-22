import Foundation

/// Determines the primary subject of an image using unified scoring approach
/// Scores all candidates from all sources, then ranks by: specificity × confidence × source_weight
final class SubjectDetector {

    // MARK: - Source Weights

    /// Weight multipliers for different detection sources
    private enum SourceWeight {
        static let recognizedPerson: Double = 4.0  // Highest: Named people
        static let detectedPerson: Double = 3.5    // High: Anonymous people/faces
        static let detectedObject: Double = 2.5    // Medium-high: Detected objects
        static let classification: Double = 1.0    // Base: Classifications
    }

    // MARK: - Public Interface

    /// Determine primary subjects using unified scoring (returns up to 3 subjects)
    func determinePrimarySubjects(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        saliency: SaliencyAnalysis?,
        recognizedPeople: [RecognizedPerson]
    ) -> [PrimarySubject] {
        var allCandidates: [(subject: PrimarySubject, score: Double)] = []

        #if DEBUG
        Logger.ai("🔍 SubjectDetector: Starting unified scoring approach")
        #endif

        // Score all sources
        allCandidates += scoreRecognizedPeople(recognizedPeople)
        allCandidates += scoreDetectedPeople(objects)
        allCandidates += scoreDetectedObjects(objects, saliency: saliency)
        allCandidates += scoreClassifications(classifications)

        #if DEBUG
        Logger.ai("🔍 Total candidates before ranking: \(allCandidates.count)")
        for (subject, score) in allCandidates.prefix(10) {
            Logger.ai("  - \(subject.label): score=\(String(format: "%.3f", score)) (confidence: \(String(format: "%.1f%%", subject.confidence * 100)))")
        }
        #endif

        // Sort by score
        let sortedCandidates = allCandidates.sorted { $0.score > $1.score }

        // SMART SELECTION: Only include multiple subjects if they're meaningfully different scores
        // If top subject has a dominant score, only return that one
        var selectedSubjects: [PrimarySubject] = []

        if let topCandidate = sortedCandidates.first {
            selectedSubjects.append(topCandidate.subject)

            // Only add additional subjects if they have significant scores
            // Be more permissive for landscape/nature photos with multiple elements
            let scoreThreshold = topCandidate.score * 0.20  // Lowered from 0.25

            for candidate in sortedCandidates.dropFirst().prefix(2) {
                let shouldAdd: Bool
                
                if candidate.score >= scoreThreshold {
                    // Good score - add regardless of source
                    shouldAdd = true
                } else if candidate.subject.source == .object && candidate.score >= topCandidate.score * 0.4 {
                    // Allow objects with decent scores (lowered from 0.5)
                    shouldAdd = true
                } else if candidate.subject.source == .classification {
                    // For classifications, be more permissive for high-specificity terms
                    let specificity = AIAnalysisConstants.getSpecificity(candidate.subject.label)
                    shouldAdd = specificity >= 3 && candidate.score >= topCandidate.score * 0.3
                } else {
                    shouldAdd = false
                }
                
                if shouldAdd {
                    selectedSubjects.append(candidate.subject)
                }

                // Stop at 2 total subjects for cleaner captions
                if selectedSubjects.count >= 2 {
                    break
                }
            }
        }

        #if DEBUG
        Logger.ai("🔍 SubjectDetector: Initial \(selectedSubjects.count) subject(s) selected")
        #endif

        // Validate subject combinations to remove contradictions
        selectedSubjects = validateSubjectCombination(selectedSubjects)

        #if DEBUG
        Logger.ai("🔍 SubjectDetector: Final \(selectedSubjects.count) subject(s) after validation:")
        for (index, subject) in selectedSubjects.enumerated() {
            Logger.ai("  \(index + 1). \(subject.label) (confidence: \(String(format: "%.1f%%", subject.confidence * 100)), source: \(subject.source))")
        }
        #endif

        return selectedSubjects
    }

    /// Legacy method for backward compatibility - returns first subject
    func determinePrimarySubject(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        saliency: SaliencyAnalysis?,
        recognizedPeople: [RecognizedPerson]
    ) -> PrimarySubject? {
        let subjects = determinePrimarySubjects(
            classifications: classifications,
            objects: objects,
            saliency: saliency,
            recognizedPeople: recognizedPeople
        )
        return subjects.first
    }

    func humanReadableObjectName(_ identifier: String) -> String {
        let commonMappings: [String: String] = [
            "person": "person",
            "face": "face",
            "car": "car",
            "dog": "dog",
            "cat": "cat",
            "bird": "bird",
            "airplane": "airplane",
            "bicycle": "bicycle",
            "boat": "boat",
            "bottle": "bottle",
            "bus": "bus",
            "chair": "chair",
            "dining_table": "dining table",
            "potted_plant": "potted plant",
            "tv": "television",
            "laptop": "laptop",
            "cell_phone": "mobile phone",
            "sports_ball": "sports ball",
            "beer glass": "beer glass",
            "wine glass": "wine glass",
            "champagne glass": "champagne glass",
            "coffee cup": "coffee cup",
            "tea cup": "tea cup",
            "sports car, sport car": "sports car",
            "sport car": "sports car"
        ]

        let lowercased = identifier.lowercased()
        if let mapped = commonMappings[lowercased] {
            return mapped
        }

        // Default: replace underscores with spaces and convert to lowercase
        return identifier.replacingOccurrences(of: "_", with: " ").lowercased()
    }

    // MARK: - Scoring Methods

    /// Score recognized people (highest weight)
    private func scoreRecognizedPeople(_ people: [RecognizedPerson]) -> [(PrimarySubject, Double)] {
        return people.map { person in
            let subject = PrimarySubject(
                label: person.name,
                confidence: person.confidence,
                source: .face,
                detail: "Recognized person",
                boundingBox: nil
            )
            let score = person.confidence * SourceWeight.recognizedPerson

            #if DEBUG
            Logger.ai("  📝 Scoring recognized person '\(person.name)': \(String(format: "%.3f", score))")
            #endif

            return (subject, score)
        }
    }

    /// Score detected people/faces (high weight)
    private func scoreDetectedPeople(_ objects: [DetectedObject]) -> [(PrimarySubject, Double)] {
        // Separate faces and bodies
        let faceObjects = objects.filter { isFace($0.identifier) }
        let bodyObjects = objects.filter { isPerson($0.identifier) }

        // Use count of whichever is higher (they might detect the same people)
        let peopleCount = max(faceObjects.count, bodyObjects.count)

        guard peopleCount > 0 else { return [] }

        // Get the best detection (highest confidence)
        let bestDetection = (bodyObjects + faceObjects).max(by: { $0.confidence < $1.confidence })

        guard let detection = bestDetection else { return [] }

        let label: String
        if peopleCount == 1 {
            label = "Person"
        } else {
            label = "Group of \(peopleCount) people"
        }

        let avgConfidence = (bodyObjects + faceObjects).map { $0.confidence }.reduce(0, +) / Float(bodyObjects.count + faceObjects.count)

        let subject = PrimarySubject(
            label: label,
            confidence: Double(avgConfidence),
            source: .object,
            detail: peopleCount == 1 ? "Single person detected" : "Multiple people detected",
            boundingBox: peopleCount == 1 ? detection.boundingBox : nil
        )

        let score = Double(avgConfidence) * SourceWeight.detectedPerson

        #if DEBUG
        Logger.ai("  👤 Scoring people detection '\(label)': \(String(format: "%.3f", score)) (faces: \(faceObjects.count), bodies: \(bodyObjects.count))")
        #endif

        return [(subject, score)]
    }

    /// Score detected objects (medium-high weight, with saliency bonus)
    private func scoreDetectedObjects(_ objects: [DetectedObject], saliency: SaliencyAnalysis?) -> [(PrimarySubject, Double)] {
        // Filter out people (already scored) and irrelevant objects
        let filteredObjects = objects.filter { object in
            !isPerson(object.identifier) &&
            !isFace(object.identifier) &&
            !shouldSkipObject(object.identifier)
        }

        // Check if there's a person detected (for vehicle boosting)
        let hasPerson = objects.contains { isPerson($0.identifier) || isFace($0.identifier) }

        return filteredObjects.compactMap { object in
            var score = Double(object.confidence) * SourceWeight.detectedObject

            // Boost by bounding box size (larger objects are more prominent)
            let size = object.boundingBox.width * object.boundingBox.height
            score *= (1.0 + Double(size) * 0.5)

            // Boost by saliency overlap
            if let saliency = saliency {
                let overlapScore = calculateSaliencyOverlap(bbox: object.boundingBox, saliency: saliency)
                score *= (1.0 + overlapScore * 0.3)
            }


            // Boost vehicles significantly - they should be primary in most car+person photos
            // (Fixed: Red Ferrari was being missed when person also in scene)
            if isVehicle(object.identifier) {
                if hasPerson {
                    score *= 3.5  // MUCH higher when person present (car + person photos - car is usually primary)
                } else {
                    score *= 2.5  // Strong base boost for vehicles
                }
            }

            let subject = PrimarySubject(
                label: humanReadableObjectName(object.identifier).capitalized,
                confidence: Double(object.confidence),
                source: .object,
                detail: "Detected object",
                boundingBox: object.boundingBox
            )

            #if DEBUG
            Logger.ai("  🎯 Scoring object '\(object.identifier)': \(String(format: "%.3f", score))")
            #endif

            return (subject, score)
        }
    }

    /// Score classifications (base weight, multiplied by specificity)
    /// Only include classifications with specificity >= 2 and reasonable confidence
    private func scoreClassifications(_ classifications: [ClassificationResult]) -> [(PrimarySubject, Double)] {
        var scored: [(PrimarySubject, Double)] = []

        for classification in classifications {
            // Skip clothing/accessories
            guard !shouldSkipClassification(classification.identifier) else {
                continue
            }

            let specificity = AIAnalysisConstants.getSpecificity(classification.identifier)

            // Allow all classifications with reasonable specificity and confidence
            // Only skip truly generic/background terms (specificity 0)
            guard specificity >= 1 else {
                continue
            }

            // Tightened confidence thresholds for better precision (raised from 0.08/0.15/0.25/0.35)
            let minConfidence: Float = specificity >= 4 ? 0.15 : (specificity >= 3 ? 0.25 : (specificity >= 2 ? 0.35 : 0.45))
            guard classification.confidence >= minConfidence else {
                continue
            }

            // Calculate score: confidence × specificity × base_weight
            var score = Double(classification.confidence) * Double(specificity) * SourceWeight.classification

            if isVehicle(classification.identifier) {
                score *= 1.5
            }

            let subject = PrimarySubject(
                label: classification.identifier.replacingOccurrences(of: "_", with: " ").capitalized,
                confidence: Double(classification.confidence),
                source: .classification,
                detail: "Classification (specificity: \(specificity))",
                boundingBox: nil
            )

            #if DEBUG
            if specificity >= 3 {
                Logger.ai("  🏷️ Scoring classification '\(classification.identifier)': \(String(format: "%.3f", score)) (specificity: \(specificity), conf: \(String(format: "%.2f", classification.confidence)))")
            }
            #endif

            scored.append((subject, score))
        }

        return scored
    }

    /// Calculate overlap between bounding box and salient regions
    private func calculateSaliencyOverlap(bbox: CGRect, saliency: SaliencyAnalysis) -> Double {
        guard !saliency.attentionPoints.isEmpty else {
            // Fallback: center-weighted scoring
            let centerX = bbox.midX
            let centerY = bbox.midY
            let distanceFromCenter = sqrt(pow(centerX - 0.5, 2) + pow(centerY - 0.5, 2))
            return max(0, 1.0 - distanceFromCenter)
        }

        // Calculate weighted intensity of attention points within bounding box
        let pointsInBox = saliency.attentionPoints.filter { point in
            bbox.contains(point.location)
        }

        let totalIntensity = pointsInBox.reduce(0.0) { $0 + $1.intensity }
        let maxPossibleIntensity = saliency.attentionPoints.reduce(0.0) { $0 + $1.intensity }

        guard maxPossibleIntensity > 0 else { return 0 }

        return totalIntensity / maxPossibleIntensity
    }

    // MARK: - Helper Methods

    private func isPerson(_ identifier: String) -> Bool {
        let lowercased = identifier.lowercased()
        return lowercased == "person" || lowercased.contains("person")
    }

    private func isFace(_ identifier: String) -> Bool {
        let lowercased = identifier.lowercased()
        return lowercased == "face" || lowercased.contains("face")
    }

    private func isVehicle(_ identifier: String) -> Bool {
        let lowercased = identifier.lowercased()
        return lowercased.contains("car") ||
               lowercased.contains("vehicle") ||
               lowercased.contains("automobile") ||
               lowercased.contains("truck") ||
               lowercased.contains("bus") ||
               lowercased.contains("motorcycle") ||
               lowercased.contains("bicycle") ||
               lowercased.contains("taxi") ||
               lowercased.contains("limousine")
    }

    private func shouldSkipObject(_ identifier: String) -> Bool {
        let lowercased = identifier.lowercased()

        // Skip clothing, accessories, and background elements
        let skipTerms = [
            "cloth", "shirt", "optical", "hat", "shoe",
            "document", "rectangular object",
            "sky", "cloud", "ground", "grass", "land", "landscape",
            "tree", "foliage", "vegetation", "horizon", "plant", "flower"
        ]

        return skipTerms.contains(where: { lowercased.contains($0) })
    }

    private func shouldSkipClassification(_ identifier: String) -> Bool {
        AIAnalysisConstants.isClothingOrAccessory(identifier)
    }
    
    /// Validate subject combinations to remove contradictions and improve coherence
    private func validateSubjectCombination(_ subjects: [PrimarySubject]) -> [PrimarySubject] {
        guard subjects.count > 1 else { return subjects }
        
        var validated = subjects
        
        #if DEBUG
        Logger.ai("🔍 SubjectDetector: Validating \(subjects.count) subject combination")
        #endif
        
        // Remove contradictory subjects (indoor vs outdoor)
        let hasIndoor = subjects.contains { $0.label.lowercased().contains("indoor") }
        let hasOutdoor = subjects.contains { $0.label.lowercased().contains("outdoor") }
        
        if hasIndoor && hasOutdoor {
            #if DEBUG
            Logger.ai("  ⚠️ Found contradictory indoor/outdoor subjects, keeping higher confidence")
            #endif
            // Keep the one with higher confidence
            validated = validated.filter { subject in
                let label = subject.label.lowercased()
                if label.contains("indoor") {
                    // Keep indoor if no outdoor has higher confidence
                    return !subjects.contains { $0.label.lowercased().contains("outdoor") && $0.confidence > subject.confidence }
                }
                if label.contains("outdoor") {
                    // Keep outdoor if no indoor has higher confidence
                    return !subjects.contains { $0.label.lowercased().contains("indoor") && $0.confidence > subject.confidence }
                }
                return true
            }
        }
        
        // Remove overly generic subjects when specific ones exist
        if validated.count > 2 {
            let hasSpecific = validated.contains { !AIAnalysisConstants.isGeneric($0.label) }
            if hasSpecific {
                #if DEBUG
                let beforeCount = validated.count
                #endif
                validated = validated.filter { !AIAnalysisConstants.isGeneric($0.label) }
                #if DEBUG
                if validated.count < beforeCount {
                    Logger.ai("  ✓ Removed \(beforeCount - validated.count) generic subject(s)")
                }
                #endif
            }
        }
        
        #if DEBUG
        if validated.count != subjects.count {
            Logger.ai("  ✓ Validation reduced subjects from \(subjects.count) to \(validated.count)")
        } else {
            Logger.ai("  ✓ No validation changes needed")
        }
        #endif
        
        return validated
    }
}
