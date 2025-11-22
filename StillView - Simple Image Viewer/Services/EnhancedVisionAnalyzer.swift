import Foundation
import Vision
import CoreGraphics
import os.log

/// Enhanced Vision analyzer that integrates additional Vision framework capabilities
/// for richer image understanding including animal recognition, food detection,
/// body pose analysis, and feature print generation.
@MainActor
final class EnhancedVisionAnalyzer {
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.vinny.stillview", category: "EnhancedVisionAnalyzer")
    
    // MARK: - Public Methods
    
    /// Perform enhanced Vision analysis with all available Vision requests
    func performEnhancedAnalysis(_ cgImage: CGImage) async throws -> EnhancedVisionResult {
        // Run all enhanced Vision requests in parallel for optimal performance
        async let animals = recognizeAnimals(cgImage)
        // async let food = recognizeFood(cgImage)
        async let bodyPose = detectBodyPose(cgImage)
        async let featurePrint = generateFeaturePrint(cgImage)
        
        // Collect results with graceful error handling
        let animalResults = await animals
        // let foodResults = await food
        let bodyPoseResult = await bodyPose
        let featurePrintResult = await featurePrint
        
        return EnhancedVisionResult(
            animals: animalResults,
            bodyPose: bodyPoseResult,
            featurePrint: featurePrintResult
        )
    }
    
    /// Recognize animals with breed/species detection
    func recognizeAnimals(_ cgImage: CGImage) async -> [AnimalRecognition]? {
        do {
            let request = VNRecognizeAnimalsRequest()
            request.revision = VNRecognizeAnimalsRequestRevision2
            
            let results: [VNRecognizedObjectObservation] = try await performVisionRequest(request, on: cgImage)
            
            guard !results.isEmpty else {
                return nil
            }
            
            var recognitions: [AnimalRecognition] = []
            
            for observation in results {
                // Get the top labels for this animal
                let labels = observation.labels.prefix(3)
                
                for label in labels {
                    let identifier = label.identifier.lowercased()
                    
                    // Try to extract species and breed information
                    let (species, breed) = parseAnimalIdentifier(identifier)
                    
                    recognitions.append(AnimalRecognition(
                        species: species,
                        breed: breed,
                        confidence: label.confidence,
                        boundingBox: observation.boundingBox
                    ))
                }
            }
            
            logger.info("Recognized \(recognitions.count) animals")
            return recognitions.isEmpty ? nil : recognitions
            
        } catch {
            logger.error("Animal recognition failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Recognize food items with cuisine detection
    /// Note: Uses classification-based food detection as VNRecognizeFoodRequest is not available in current SDK
    func recognizeFood(_ cgImage: CGImage) async -> [FoodRecognition]? {
        do {
            // Use classification request to detect food items
            let request = VNClassifyImageRequest()
            
            let results: [VNClassificationObservation] = try await performVisionRequest(request, on: cgImage)
            
            // Filter for food-related classifications
            let foodClassifications = results.filter { observation in
                let identifier = observation.identifier.lowercased()
                return identifier.contains("food") || 
                       identifier.contains("dish") ||
                       identifier.contains("meal") ||
                       detectCuisine(from: identifier) != nil
            }
            
            guard !foodClassifications.isEmpty else {
                return nil
            }
            
            var recognitions: [FoodRecognition] = []
            
            for classification in foodClassifications.prefix(5) {
                let foodItem = classification.identifier
                let cuisine = detectCuisine(from: foodItem)
                
                recognitions.append(FoodRecognition(
                    foodItem: foodItem,
                    cuisine: cuisine,
                    confidence: classification.confidence,
                    boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1) // Full image
                ))
            }
            
            logger.info("Recognized \(recognitions.count) food items")
            return recognitions.isEmpty ? nil : recognitions
            
        } catch {
            logger.error("Food recognition failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Detect human body pose for activity recognition
    func detectBodyPose(_ cgImage: CGImage) async -> BodyPoseResult? {
        do {
            let request = VNDetectHumanBodyPoseRequest()
            
            let results: [VNHumanBodyPoseObservation] = try await performVisionRequest(request, on: cgImage)
            
            guard let firstObservation = results.first else {
                return nil
            }
            
            // Analyze the pose to detect activity
            let activity = detectActivity(from: firstObservation)
            
            // Calculate confidence based on recognized joint points
            let recognizedPoints = try? firstObservation.recognizedPoints(VNHumanBodyPoseObservation.JointsGroupName.all)
            let confidence = Float(recognizedPoints?.values.filter { $0.confidence > 0.5 }.count ?? 0) / 
                           Float(recognizedPoints?.count ?? 1)
            
            logger.info("Detected body pose with activity: \(activity ?? "unknown")")
            
            return BodyPoseResult(
                pose: firstObservation,
                detectedActivity: activity,
                confidence: confidence
            )
            
        } catch {
            logger.error("Body pose detection failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Generate feature print for image similarity
    func generateFeaturePrint(_ cgImage: CGImage) async -> VNFeaturePrintObservation? {
        do {
            let request = VNGenerateImageFeaturePrintRequest()
            
            let results: [VNFeaturePrintObservation] = try await performVisionRequest(request, on: cgImage)
            
            guard let observation = results.first else {
                return nil
            }
            
            logger.info("Generated feature print successfully")
            return observation
            
        } catch {
            logger.error("Feature print generation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Perform a Vision request asynchronously
    private func performVisionRequest<T>(_ request: VNRequest, on cgImage: CGImage) async throws -> [T] {
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    
                    if let results = request.results as? [T] {
                        continuation.resume(returning: results)
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Parse animal identifier to extract species and breed
    private func parseAnimalIdentifier(_ identifier: String) -> (species: String, breed: String?) {
        // Common patterns: "dog", "cat", "golden_retriever", "siamese_cat"
        let components = identifier.components(separatedBy: "_")
        
        if components.count > 1 {
            // Has breed information
            let breed = components.dropLast().joined(separator: " ").capitalized
            let species = components.last?.capitalized ?? "Animal"
            return (species, breed)
        } else {
            // Just species
            return (identifier.capitalized, nil)
        }
    }
    
    /// Detect cuisine type from food item name
    private func detectCuisine(from foodItem: String) -> String? {
        let item = foodItem.lowercased()
        
        // Simple cuisine detection based on common food items
        let cuisineKeywords: [String: String] = [
            "sushi": "Japanese",
            "ramen": "Japanese",
            "tempura": "Japanese",
            "pizza": "Italian",
            "pasta": "Italian",
            "risotto": "Italian",
            "taco": "Mexican",
            "burrito": "Mexican",
            "enchilada": "Mexican",
            "curry": "Indian",
            "naan": "Indian",
            "biryani": "Indian",
            "croissant": "French",
            "baguette": "French",
            "crepe": "French",
            "dim sum": "Chinese",
            "dumpling": "Chinese",
            "noodles": "Asian",
            "pad thai": "Thai",
            "pho": "Vietnamese",
            "kebab": "Middle Eastern",
            "falafel": "Middle Eastern",
            "paella": "Spanish",
            "tapas": "Spanish"
        ]
        
        for (keyword, cuisine) in cuisineKeywords {
            if item.contains(keyword) {
                return cuisine
            }
        }
        
        return nil
    }
    
    /// Detect activity from body pose observation
    private func detectActivity(from observation: VNHumanBodyPoseObservation) -> String? {
        do {
            // Get key joint points
            let allPoints = try observation.recognizedPoints(VNHumanBodyPoseObservation.JointsGroupName.all)
            
            guard let leftShoulder = allPoints[.leftShoulder],
                  let rightShoulder = allPoints[.rightShoulder],
                  let leftHip = allPoints[.leftHip],
                  let rightHip = allPoints[.rightHip],
                  leftShoulder.confidence > 0.5,
                  rightShoulder.confidence > 0.5,
                  leftHip.confidence > 0.5,
                  rightHip.confidence > 0.5 else {
                return nil
            }
            
            // Calculate body orientation and posture
            let shoulderMidY = (leftShoulder.location.y + rightShoulder.location.y) / 2
            let hipMidY = (leftHip.location.y + rightHip.location.y) / 2
            let torsoLength = abs(shoulderMidY - hipMidY)
            
            // Detect standing vs sitting based on torso length
            if torsoLength > 0.3 {
                // Check for raised arms (waving, reaching)
                if let leftWrist = allPoints[.leftWrist],
                   let rightWrist = allPoints[.rightWrist],
                   leftWrist.confidence > 0.5 || rightWrist.confidence > 0.5 {
                    
                    let leftArmRaised = leftWrist.location.y > leftShoulder.location.y
                    let rightArmRaised = rightWrist.location.y > rightShoulder.location.y
                    
                    if leftArmRaised || rightArmRaised {
                        return "reaching or waving"
                    }
                }
                
                return "standing"
            } else if torsoLength > 0.15 {
                return "sitting"
            } else {
                return "lying down"
            }
            
        } catch {
            logger.error("Failed to analyze body pose for activity: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Data Models

/// Result of enhanced Vision analysis
struct EnhancedVisionResult: Equatable {
    let animals: [AnimalRecognition]?
    let bodyPose: BodyPoseResult?
    let featurePrint: VNFeaturePrintObservation?
    
    /// Whether any enhanced data was successfully collected
    var hasEnhancedData: Bool {
        return animals != nil || bodyPose != nil || featurePrint != nil
    }
    
    static func == (lhs: EnhancedVisionResult, rhs: EnhancedVisionResult) -> Bool {
        return lhs.animals == rhs.animals &&
               lhs.bodyPose == rhs.bodyPose &&
               lhs.featurePrint?.elementCount == rhs.featurePrint?.elementCount
    }
}

/// Animal recognition result with species and breed information
struct AnimalRecognition: Equatable {
    let species: String
    let breed: String?
    let confidence: Float
    let boundingBox: CGRect
    
    var displayName: String {
        if let breed = breed {
            return "\(breed) \(species)"
        }
        return species
    }
}

/// Food recognition result with cuisine information
struct FoodRecognition: Equatable {
    let foodItem: String
    let cuisine: String?
    let confidence: Float
    let boundingBox: CGRect
    
    var displayName: String {
        if let cuisine = cuisine {
            return "\(cuisine) - \(foodItem)"
        }
        return foodItem
    }
}

/// Body pose detection result with activity inference
struct BodyPoseResult: Equatable {
    let pose: VNHumanBodyPoseObservation
    let detectedActivity: String?
    let confidence: Float
    
    static func == (lhs: BodyPoseResult, rhs: BodyPoseResult) -> Bool {
        return lhs.detectedActivity == rhs.detectedActivity &&
               lhs.confidence == rhs.confidence
    }
}
