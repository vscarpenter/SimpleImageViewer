import Foundation
import os.log

/// Evaluates confidence levels and handles low-confidence scenarios gracefully
/// to ensure accurate and appropriate term selection for image captions
final class ConfidenceEvaluator {
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.vinny.stillview", category: "ConfidenceEvaluator")
    
    // MARK: - Confidence Thresholds
    
    /// High confidence threshold (>70%): Use specific term
    private let highConfidenceThreshold: Float = 0.7
    
    /// Medium confidence threshold (50-70%): Use specific term with qualifier
    private let mediumConfidenceThreshold: Float = 0.5
    
    /// Low confidence threshold (30-50%): Use generic category
    private let lowConfidenceThreshold: Float = 0.3
    
    /// Very low confidence (<30%): Use observable facts only
    
    /// Threshold for detecting close confidence matches
    private let closeMatchThreshold: Float = 0.1
    
    // MARK: - Public Methods
    
    /// Select the best term based on confidence levels and multiple candidates
    /// - Parameters:
    ///   - candidates: Array of classification results sorted by confidence
    ///   - threshold: Minimum confidence threshold (default: 0.5)
    /// - Returns: Selected term appropriate for the confidence level
    func selectTerm(
        from candidates: [ClassificationResult],
        threshold: Float = 0.5
    ) -> String {
        guard !candidates.isEmpty else {
            logger.warning("No candidates provided, returning default term")
            return "image"
        }
        
        guard let topCandidate = candidates.first else {
            return "image"
        }
        
        logger.debug("Evaluating \(candidates.count) candidates, top: '\(topCandidate.identifier)' (\(topCandidate.confidence))")
        
        // High confidence: use specific term directly
        if topCandidate.confidence >= highConfidenceThreshold {
            logger.info("High confidence (\(topCandidate.confidence)): using specific term '\(topCandidate.identifier)'")
            return topCandidate.identifier
        }
        
        // Medium confidence: check for multiple close matches
        if topCandidate.confidence >= mediumConfidenceThreshold {
            let closeMatches = detectCloseMatches(candidates)
            
            if closeMatches.count > 2 {
                // Multiple close matches: use broader category
                let commonCategory = findCommonCategory(closeMatches)
                logger.info("Medium confidence with \(closeMatches.count) close matches: using common category '\(commonCategory)'")
                return commonCategory
            }
            
            logger.info("Medium confidence (\(topCandidate.confidence)): using specific term '\(topCandidate.identifier)'")
            return topCandidate.identifier
        }
        
        // Low confidence: use generic term
        if topCandidate.confidence >= lowConfidenceThreshold {
            let genericTerm = getGenericTerm(topCandidate.identifier)
            logger.info("Low confidence (\(topCandidate.confidence)): using generic term '\(genericTerm)'")
            return genericTerm
        }
        
        // Very low confidence: use observable fact
        logger.info("Very low confidence (\(topCandidate.confidence)): using observable fact 'image'")
        return "image"
    }
    
    /// Select term with qualifier based on confidence level
    /// - Parameters:
    ///   - candidates: Array of classification results
    ///   - includeQualifier: Whether to include confidence qualifiers
    /// - Returns: Term with appropriate qualifier (e.g., "appears to be a dog")
    func selectTermWithQualifier(
        from candidates: [ClassificationResult],
        includeQualifier: Bool = true
    ) -> String {
        guard !candidates.isEmpty else {
            return "image"
        }
        
        guard let topCandidate = candidates.first else {
            return "image"
        }
        
        let term = selectTerm(from: candidates)
        
        // Don't add qualifier if not requested or if confidence is high
        if !includeQualifier || topCandidate.confidence >= highConfidenceThreshold {
            return term
        }
        
        // Add qualifier for medium confidence
        if topCandidate.confidence >= mediumConfidenceThreshold {
            return "appears to be \(addArticle(term))"
        }
        
        // Add qualifier for low confidence
        if topCandidate.confidence >= lowConfidenceThreshold {
            return "possibly \(addArticle(term))"
        }
        
        // Very low confidence: just return the term without qualifier
        return term
    }
    
    /// Evaluate confidence level category
    /// - Parameter confidence: Confidence value (0.0 to 1.0)
    /// - Returns: Confidence level category
    func evaluateConfidenceLevel(_ confidence: Float) -> ConfidenceLevel {
        if confidence >= highConfidenceThreshold {
            return .high
        } else if confidence >= mediumConfidenceThreshold {
            return .medium
        } else if confidence >= lowConfidenceThreshold {
            return .low
        } else {
            return .veryLow
        }
    }
    
    /// Check if multiple candidates have similar confidence scores
    /// - Parameter candidates: Array of classification results
    /// - Returns: True if multiple close matches exist
    func hasMultipleCloseMatches(_ candidates: [ClassificationResult]) -> Bool {
        let closeMatches = detectCloseMatches(candidates)
        return closeMatches.count > 2
    }
    
    /// Get confidence-appropriate terms for multiple candidates
    /// - Parameters:
    ///   - candidates: Array of classification results
    ///   - maxTerms: Maximum number of terms to return
    /// - Returns: Array of confidence-appropriate terms
    func selectMultipleTerms(
        from candidates: [ClassificationResult],
        maxTerms: Int = 3
    ) -> [String] {
        guard !candidates.isEmpty else {
            return ["image"]
        }
        
        var selectedTerms: [String] = []
        
        // Group candidates by confidence level
        let highConfidenceCandidates = candidates.filter { $0.confidence >= highConfidenceThreshold }
        let mediumConfidenceCandidates = candidates.filter {
            $0.confidence >= mediumConfidenceThreshold && $0.confidence < highConfidenceThreshold
        }
        
        // Prioritize high confidence terms
        for candidate in highConfidenceCandidates.prefix(maxTerms) {
            selectedTerms.append(candidate.identifier)
        }
        
        // Add medium confidence terms if we have room
        if selectedTerms.count < maxTerms {
            let remaining = maxTerms - selectedTerms.count
            for candidate in mediumConfidenceCandidates.prefix(remaining) {
                selectedTerms.append(candidate.identifier)
            }
        }
        
        // If still empty, use the top candidate with appropriate handling
        if selectedTerms.isEmpty {
            selectedTerms.append(selectTerm(from: candidates))
        }
        
        return selectedTerms
    }
    
    // MARK: - Private Methods
    
    /// Detect candidates with confidence scores close to the top candidate
    private func detectCloseMatches(_ candidates: [ClassificationResult]) -> [ClassificationResult] {
        guard let topCandidate = candidates.first else {
            return []
        }
        
        return candidates.filter {
            abs($0.confidence - topCandidate.confidence) < closeMatchThreshold
        }
    }
    
    /// Find common category among multiple classification terms
    private func findCommonCategory(_ candidates: [ClassificationResult]) -> String {
        let terms = candidates.map { $0.identifier }
        let lowercaseTerms = terms.map { $0.lowercased() }
        
        // Check for common animal category
        let animalKeywords = ["dog", "cat", "bird", "fish", "horse", "cow", "animal", "pet"]
        if lowercaseTerms.contains(where: { term in
            animalKeywords.contains(where: { term.contains($0) })
        }) {
            return "animal"
        }
        
        // Check for common vehicle category
        let vehicleKeywords = ["car", "truck", "vehicle", "motorcycle", "bicycle", "bus", "van"]
        if lowercaseTerms.contains(where: { term in
            vehicleKeywords.contains(where: { term.contains($0) })
        }) {
            return "vehicle"
        }
        
        // Check for common nature category
        let natureKeywords = ["tree", "flower", "plant", "nature", "landscape", "forest", "garden"]
        if lowercaseTerms.contains(where: { term in
            natureKeywords.contains(where: { term.contains($0) })
        }) {
            return "nature scene"
        }
        
        // Check for common food category
        let foodKeywords = ["food", "dish", "meal", "drink", "beverage", "cuisine"]
        if lowercaseTerms.contains(where: { term in
            foodKeywords.contains(where: { term.contains($0) })
        }) {
            return "food"
        }
        
        // Check for common building category
        let buildingKeywords = ["building", "house", "structure", "architecture", "tower", "bridge"]
        if lowercaseTerms.contains(where: { term in
            buildingKeywords.contains(where: { term.contains($0) })
        }) {
            return "building"
        }
        
        // Check for common person category
        let personKeywords = ["person", "man", "woman", "child", "people", "human"]
        if lowercaseTerms.contains(where: { term in
            personKeywords.contains(where: { term.contains($0) })
        }) {
            return "person"
        }
        
        // Check for common technology category
        let techKeywords = ["phone", "computer", "laptop", "tablet", "device", "electronics"]
        if lowercaseTerms.contains(where: { term in
            techKeywords.contains(where: { term.contains($0) })
        }) {
            return "electronic device"
        }
        
        // Default to first term if no common category found
        logger.debug("No common category found for terms: \(terms.joined(separator: ", "))")
        return terms.first ?? "object"
    }
    
    /// Get generic term for a specific classification
    private func getGenericTerm(_ term: String) -> String {
        let lowercaseTerm = term.lowercased()
        
        // Animal mappings
        if lowercaseTerm.contains("dog") || lowercaseTerm.contains("cat") ||
           lowercaseTerm.contains("bird") || lowercaseTerm.contains("fish") ||
           lowercaseTerm.contains("horse") || lowercaseTerm.contains("cow") {
            return "animal"
        }
        
        // Vehicle mappings
        if lowercaseTerm.contains("car") || lowercaseTerm.contains("truck") ||
           lowercaseTerm.contains("motorcycle") || lowercaseTerm.contains("bicycle") ||
           lowercaseTerm.contains("bus") || lowercaseTerm.contains("van") {
            return "vehicle"
        }
        
        // Nature mappings
        if lowercaseTerm.contains("tree") || lowercaseTerm.contains("flower") ||
           lowercaseTerm.contains("plant") || lowercaseTerm.contains("forest") {
            return "plant"
        }
        
        // Food mappings
        if lowercaseTerm.contains("food") || lowercaseTerm.contains("dish") ||
           lowercaseTerm.contains("meal") || lowercaseTerm.contains("drink") {
            return "food"
        }
        
        // Building mappings
        if lowercaseTerm.contains("building") || lowercaseTerm.contains("house") ||
           lowercaseTerm.contains("structure") || lowercaseTerm.contains("architecture") {
            return "building"
        }
        
        // Person mappings
        if lowercaseTerm.contains("person") || lowercaseTerm.contains("man") ||
           lowercaseTerm.contains("woman") || lowercaseTerm.contains("child") ||
           lowercaseTerm.contains("people") {
            return "person"
        }
        
        // Technology mappings
        if lowercaseTerm.contains("phone") || lowercaseTerm.contains("computer") ||
           lowercaseTerm.contains("laptop") || lowercaseTerm.contains("tablet") {
            return "device"
        }
        
        // Landscape mappings
        if lowercaseTerm.contains("mountain") || lowercaseTerm.contains("lake") ||
           lowercaseTerm.contains("ocean") || lowercaseTerm.contains("river") ||
           lowercaseTerm.contains("landscape") {
            return "landscape"
        }
        
        // Default to object
        return "object"
    }
    
    /// Add appropriate article (a/an) to a term
    private func addArticle(_ term: String) -> String {
        let lowercaseTerm = term.lowercased()
        let vowels = ["a", "e", "i", "o", "u"]
        
        if vowels.contains(where: { lowercaseTerm.hasPrefix($0) }) {
            return "an \(term)"
        } else {
            return "a \(term)"
        }
    }
}

// MARK: - Supporting Types

/// Confidence level categories
enum ConfidenceLevel: String {
    case high = "high"           // >70%: Use specific term
    case medium = "medium"       // 50-70%: Use specific term with qualifier
    case low = "low"            // 30-50%: Use generic category
    case veryLow = "very_low"   // <30%: Use observable facts only
    
    var description: String {
        switch self {
        case .high:
            return "High confidence (>70%)"
        case .medium:
            return "Medium confidence (50-70%)"
        case .low:
            return "Low confidence (30-50%)"
        case .veryLow:
            return "Very low confidence (<30%)"
        }
    }
    
    var shouldUseQualifier: Bool {
        return self == .medium || self == .low
    }
}
