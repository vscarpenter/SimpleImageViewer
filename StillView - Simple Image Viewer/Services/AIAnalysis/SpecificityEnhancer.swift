import Foundation
import Vision
import os.log

/// Enhances caption specificity by selecting the most specific and accurate terms
/// from multiple classification sources (Vision, ResNet-50, animal/food recognition)
final class SpecificityEnhancer {
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.vinny.stillview", category: "SpecificityEnhancer")
    
    // MARK: - Constants
    
    private let highConfidenceThreshold: Float = 0.7
    private let mediumConfidenceThreshold: Float = 0.5
    private let lowConfidenceThreshold: Float = 0.3
    
    // MARK: - Public Methods
    
    /// Enhance specificity by selecting the best term from all available sources
    func enhanceSpecificity(
        classifications: [ClassificationResult],
        animals: [AnimalRecognition]?
    ) -> String {
        var candidates: [SpecificityCandidate] = []
        
        // Add animal-specific terms (highest specificity)
        if let animals = animals, let animal = animals.first {
            if let breed = animal.breed {
                // Breed is most specific (level 3)
                candidates.append(SpecificityCandidate(
                    term: animal.displayName,
                    confidence: animal.confidence,
                    specificityLevel: 3,
                    source: .animalRecognition
                ))
            }
            // Species is moderately specific (level 2)
            candidates.append(SpecificityCandidate(
                term: animal.species,
                confidence: animal.confidence,
                specificityLevel: 2,
                source: .animalRecognition
            ))
        }
        

        
        // Add general classifications with determined specificity levels
        for classification in classifications.prefix(10) {
            let level = determineSpecificityLevel(classification.identifier)
            candidates.append(SpecificityCandidate(
                term: classification.identifier,
                confidence: classification.confidence,
                specificityLevel: level,
                source: .classification
            ))
        }
        
        // Select best candidate
        let selectedTerm = selectBestCandidate(candidates)
        
        logger.info("Selected term: '\(selectedTerm)' from \(candidates.count) candidates")
        
        return selectedTerm
    }
    
    /// Enhance specificity with multiple top candidates for richer descriptions
    func enhanceSpecificityWithMultipleCandidates(
        classifications: [ClassificationResult],
        animals: [AnimalRecognition]?,
        maxCandidates: Int = 3
    ) -> [String] {
        var candidates: [SpecificityCandidate] = []
        
        // Add animal-specific terms
        if let animals = animals {
            for animal in animals.prefix(2) {
                if let breed = animal.breed {
                    candidates.append(SpecificityCandidate(
                        term: animal.displayName,
                        confidence: animal.confidence,
                        specificityLevel: 3,
                        source: .animalRecognition
                    ))
                }
                candidates.append(SpecificityCandidate(
                    term: animal.species,
                    confidence: animal.confidence,
                    specificityLevel: 2,
                    source: .animalRecognition
                ))
            }
        }
        

        
        // Add general classifications
        for classification in classifications.prefix(15) {
            let level = determineSpecificityLevel(classification.identifier)
            candidates.append(SpecificityCandidate(
                term: classification.identifier,
                confidence: classification.confidence,
                specificityLevel: level,
                source: .classification
            ))
        }
        
        // Sort by weighted score and return top candidates
        let sortedCandidates = candidates
            .sorted { $0.weightedScore > $1.weightedScore }
            .prefix(maxCandidates)
        
        return Array(sortedCandidates.map { $0.term })
    }
    
    // MARK: - Private Methods
    
    /// Determine specificity level for a classification term
    private func determineSpecificityLevel(_ term: String) -> Int {
        let lowercaseTerm = term.lowercased()
        
        // Level 3: Very specific (breeds, models, specific items)
        let verySpecificKeywords = [
            "golden retriever", "labrador", "siamese", "persian",
            "iphone", "macbook", "tesla", "ferrari",
            "oak tree", "maple tree", "rose", "tulip",
            "cappuccino", "espresso", "croissant", "baguette"
        ]
        
        for keyword in verySpecificKeywords {
            if lowercaseTerm.contains(keyword) {
                return 3
            }
        }
        
        // Level 2: Specific (species, categories, types)
        let specificKeywords = [
            "dog", "cat", "bird", "fish", "horse", "cow",
            "car", "truck", "bicycle", "motorcycle",
            "tree", "flower", "plant", "grass",
            "building", "house", "bridge", "tower",
            "food", "drink", "meal", "dish",
            "person", "man", "woman", "child",
            "mountain", "lake", "ocean", "river",
            "phone", "computer", "laptop", "tablet"
        ]
        
        for keyword in specificKeywords {
            if lowercaseTerm == keyword || lowercaseTerm.contains(" \(keyword)") || lowercaseTerm.contains("\(keyword) ") {
                return 2
            }
        }
        
        // Level 1: Generic (broad categories)
        let genericKeywords = [
            "animal", "mammal", "creature",
            "vehicle", "transportation",
            "object", "thing", "item",
            "nature", "outdoor", "indoor",
            "structure", "architecture",
            "scene", "view", "image"
        ]
        
        for keyword in genericKeywords {
            if lowercaseTerm.contains(keyword) {
                return 1
            }
        }
        
        // Default to level 2 for unknown terms
        return 2
    }
    
    /// Select the best candidate based on confidence and specificity
    private func selectBestCandidate(_ candidates: [SpecificityCandidate]) -> String {
        guard !candidates.isEmpty else {
            return "image"
        }
        
        // Sort by weighted score
        let sortedCandidates = candidates.sorted { $0.weightedScore > $1.weightedScore }
        
        guard let topCandidate = sortedCandidates.first else {
            return "image"
        }
        
        // High confidence: use specific term
        if topCandidate.confidence >= highConfidenceThreshold {
            return topCandidate.term
        }
        
        // Medium confidence: check if multiple candidates are close
        if topCandidate.confidence >= mediumConfidenceThreshold {
            let closeMatches = sortedCandidates.filter {
                abs($0.confidence - topCandidate.confidence) < 0.1
            }
            
            if closeMatches.count > 2 {
                // Multiple close matches: use common category
                return findCommonCategory(closeMatches.map { $0.term })
            }
            
            return topCandidate.term
        }
        
        // Low confidence: use generic term
        if topCandidate.confidence >= lowConfidenceThreshold {
            return getGenericTerm(topCandidate.term)
        }
        
        // Very low confidence: use observable fact
        return "image"
    }
    
    /// Find common category among multiple terms
    private func findCommonCategory(_ terms: [String]) -> String {
        let lowercaseTerms = terms.map { $0.lowercased() }
        
        // Check for common animal category
        let animalKeywords = ["dog", "cat", "bird", "fish", "horse", "animal"]
        for keyword in animalKeywords {
            if lowercaseTerms.contains(where: { $0.contains(keyword) }) {
                return "animal"
            }
        }
        
        // Check for common vehicle category
        let vehicleKeywords = ["car", "truck", "vehicle", "motorcycle", "bicycle"]
        for keyword in vehicleKeywords {
            if lowercaseTerms.contains(where: { $0.contains(keyword) }) {
                return "vehicle"
            }
        }
        
        // Check for common nature category
        let natureKeywords = ["tree", "flower", "plant", "nature", "landscape"]
        for keyword in natureKeywords {
            if lowercaseTerms.contains(where: { $0.contains(keyword) }) {
                return "nature scene"
            }
        }
        
        // Check for common food category
        let foodKeywords = ["food", "dish", "meal", "drink"]
        for keyword in foodKeywords {
            if lowercaseTerms.contains(where: { $0.contains(keyword) }) {
                return "food"
            }
        }
        
        // Check for common building category
        let buildingKeywords = ["building", "house", "structure", "architecture"]
        for keyword in buildingKeywords {
            if lowercaseTerms.contains(where: { $0.contains(keyword) }) {
                return "building"
            }
        }
        
        // Default to first term if no common category found
        return terms.first ?? "scene"
    }
    
    /// Get generic term for a specific term
    private func getGenericTerm(_ term: String) -> String {
        let lowercaseTerm = term.lowercased()
        
        // Animal mappings
        if lowercaseTerm.contains("dog") || lowercaseTerm.contains("cat") ||
           lowercaseTerm.contains("bird") || lowercaseTerm.contains("fish") {
            return "animal"
        }
        
        // Vehicle mappings
        if lowercaseTerm.contains("car") || lowercaseTerm.contains("truck") ||
           lowercaseTerm.contains("motorcycle") || lowercaseTerm.contains("bicycle") {
            return "vehicle"
        }
        
        // Nature mappings
        if lowercaseTerm.contains("tree") || lowercaseTerm.contains("flower") ||
           lowercaseTerm.contains("plant") {
            return "plant"
        }
        
        // Food mappings
        if lowercaseTerm.contains("food") || lowercaseTerm.contains("dish") ||
           lowercaseTerm.contains("meal") {
            return "food"
        }
        
        // Building mappings
        if lowercaseTerm.contains("building") || lowercaseTerm.contains("house") ||
           lowercaseTerm.contains("structure") {
            return "building"
        }
        
        // Person mappings
        if lowercaseTerm.contains("person") || lowercaseTerm.contains("man") ||
           lowercaseTerm.contains("woman") || lowercaseTerm.contains("child") {
            return "person"
        }
        
        // Default to object
        return "object"
    }
}

// MARK: - Supporting Types

/// Candidate term with specificity scoring
private struct SpecificityCandidate {
    let term: String
    let confidence: Float
    let specificityLevel: Int
    let source: CandidateSource
    
    /// Weighted score combining confidence and specificity
    var weightedScore: Float {
        // Weight specificity more heavily (60%) than confidence (40%)
        // This ensures we prefer specific terms when confidence is reasonable
        let specificityWeight: Float = 0.6
        let confidenceWeight: Float = 0.4
        
        let normalizedSpecificity = Float(specificityLevel) / 3.0
        return (normalizedSpecificity * specificityWeight) + (confidence * confidenceWeight)
    }
}

/// Source of classification candidate
private enum CandidateSource {
    case animalRecognition
    case classification
}
