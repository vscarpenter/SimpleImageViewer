
//
//  AIBrain.swift
//  StillView
//
//  Created by Vinny Carpenter on 10/11/25.
//

import Foundation

/// The AIBrain is responsible for orchestrating AI analysis and generating sophisticated, context-aware insights.
/// It acts as a layer on top of the AIImageAnalysisService, transforming raw analysis data into meaningful and actionable insights.
@MainActor
class AIBrain: ObservableObject {
    
    static let shared = AIBrain()
    
    private let analysisService = AIImageAnalysisService.shared
    
    private init() {}
    
    /// Generates a comprehensive set of insights for a given image analysis result.
    /// - Parameter result: The raw analysis result from `AIImageAnalysisService`.
    /// - Returns: An array of `AIInsight` objects, prioritized and filtered for relevance.
    func generateInsights(for result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Generate insights from different domains
        insights.append(contentsOf: generateCompositionalInsights(from: result))
        insights.append(contentsOf: generateQualityInsights(from: result))
        insights.append(contentsOf: generateContentInsights(from: result))
        
        // Phase 3: New insight categories
        insights.append(contentsOf: generateTechnicalInsights(from: result))
        insights.append(contentsOf: generateAccessibilityInsights(from: result))
        insights.append(contentsOf: generatePrivacyInsights(from: result))
        insights.append(contentsOf: generateOrganizationInsights(from: result))
        insights.append(contentsOf: generateEnhancementInsights(from: result))
        insights.append(contentsOf: generateContextInsights(from: result))
        insights.append(contentsOf: generateDiscoveryInsights(from: result))
        insights.append(contentsOf: generateActionInsights(from: result))
        
        // Prioritize and filter insights
        let prioritizedInsights = prioritizeAndFilter(insights)
        
        return prioritizedInsights
    }
    
    private func generateCompositionalInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        if let saliency = result.saliencyAnalysis, !saliency.croppingSuggestions.isEmpty,
           let firstCrop = saliency.croppingSuggestions.first {
            let insight = AIInsight(type: .compositional, title: "Composition Suggestion", description: "Improve framing by focusing on the main subject. \(saliency.visualBalance.feedback)", confidence: firstCrop.confidence, action: .crop, priority: .high)
            insights.append(insight)
        }
        
        return insights
    }
    
    private func generateQualityInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        for issue in result.qualityAssessment.issues {
            let insight: AIInsight?
            switch issue.kind {
            case .softFocus:
                insight = AIInsight(type: .quality, title: "Sharpness Enhancement", description: issue.detail, confidence: 0.9, action: .enhance, priority: .high)
            case .underexposed, .overexposed:
                insight = AIInsight(type: .quality, title: "Exposure Adjustment", description: issue.detail, confidence: 0.85, action: .enhance, priority: .high)
            case .lowResolution:
                insight = AIInsight(type: .quality, title: "Resolution Notice", description: issue.detail, confidence: 1.0, action: .none, priority: .medium)
            }
            
            if let insight = insight {
                insights.append(insight)
            }
        }
        
        return insights
    }
    
    private func generateContentInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Primary description insight (what's in the image)
        if let caption = result.caption {
            let descriptionText = caption.shortCaption.trimmingCharacters(in: .whitespacesAndNewlines)
            if !descriptionText.isEmpty && descriptionText.lowercased() != "image." {
                let insight = AIInsight(
                    type: .content,
                    title: "What's in this image",
                    description: descriptionText,
                    confidence: max(0.6, caption.confidence),
                    action: .none
                )
                insights.append(insight)
            }
        } else {
            let narrative = result.narrativeSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !narrative.isEmpty && narrative.lowercased() != "image." {
                let insight = AIInsight(
                    type: .content,
                    title: "What's in this image",
                    description: narrative,
                    confidence: max(0.55, result.primaryContentConfidence),
                    action: .none
                )
                insights.append(insight)
            }
        }

        // Text extraction insight
        let totalCharacterCount = result.text.reduce(0) { $0 + $1.text.count }
        if totalCharacterCount >= 30 {
            let sampleSnippet = result.text
                .map { $0.text }
                .joined(separator: " ")
                .prefix(60)
            
            let insight = AIInsight(type: .content, title: "Text Content Detected", description: "Detected readable text across \(result.text.count) regions. Extract for editing or copying.", confidence: min(0.95, Double(totalCharacterCount) / 120.0), action: .copy, priority: .medium)
            insights.append(insight)
        }
        
        // Portrait insight
        if result.objects.contains(where: { object in
            let lower = object.identifier.lowercased()
            return lower.contains("face") || lower.contains("person")
        }) {
            let description: String
            if let person = result.recognizedPeople.first {
                description = "Potentially depicts \(person.name). Confirm and tag to keep your library organised."
            } else {
                let detectedCount = max(
                    result.objects.filter { $0.identifier.lowercased().contains("person") }.count,
                    result.objects.filter { $0.identifier.lowercased().contains("face") }.count
                )
                if detectedCount > 1 {
                    description = "Detected multiple people in frame. Add names to improve organisation."
                } else {
                    description = "This appears to be a portrait. Tag people to keep your library organised."
                }
            }

            let insight = AIInsight(type: .content, title: "People Detected", description: description, confidence: max(0.85, result.recognizedPeople.first?.confidence ?? 0.85), action: .tag, priority: .high)
            insights.append(insight)
        }
        
        return insights
    }
    
    // MARK: - Phase 3: Advanced Insight Generators
    
    /// Generate technical insights (EXIF, metrics, camera settings)
    private func generateTechnicalInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Resolution/quality metrics
        let megapixels = result.qualityAssessment.metrics.megapixels
        if megapixels > 12 {
            insights.append(AIInsight(
                type: .technical,
                title: "High Resolution",
                description: String(format: "%.1fMP resolution ideal for printing and detailed viewing", megapixels),
                confidence: 1.0,
                action: .viewMetadata,
                priority: .low,
                metadata: ["megapixels": String(format: "%.1f", megapixels)]
            ))
        } else if megapixels < 2 {
            insights.append(AIInsight(
                type: .technical,
                title: "Low Resolution",
                description: String(format: "%.1fMP may limit print quality and zoom capability", megapixels),
                confidence: 1.0,
                action: .viewMetadata,
                priority: .medium,
                metadata: ["megapixels": String(format: "%.1f", megapixels)]
            ))
        }
        
        return insights
    }
    
    /// Generate accessibility insights (contrast, readability)
    private func generateAccessibilityInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Text readability
        if !result.text.isEmpty {
            let avgConfidence = result.text.map { $0.confidence }.reduce(0, +) / Float(result.text.count)
            if avgConfidence < 0.7 {
                insights.append(AIInsight(
                    type: .accessibility,
                    title: "Text Readability",
                    description: "Some text may be difficult to read. Consider enhancing contrast or clarity",
                    confidence: Double(1.0 - avgConfidence),
                    action: .enhance,
                    priority: .medium
                ))
            }
        }
        
        // Color contrast for people with vision impairments
        if result.colors.count >= 2 {
            let dominantColors = Array(result.colors.prefix(2))
            // Simple contrast check based on brightness difference
            if let color1 = dominantColors[0].color.usingColorSpace(.deviceRGB),
               let color2 = dominantColors[1].color.usingColorSpace(.deviceRGB) {
                let brightness1 = color1.brightnessComponent
                let brightness2 = color2.brightnessComponent
                let contrast = abs(brightness1 - brightness2)
                
                if contrast < 0.3 {
                    insights.append(AIInsight(
                        type: .accessibility,
                        title: "Low Color Contrast",
                        description: "Limited contrast may affect visibility. Consider this for accessibility-critical uses",
                        confidence: 0.75,
                        action: .enhance,
                        priority: .low
                    ))
                }
            }
        }
        
        return insights
    }
    
    /// Generate privacy insights (faces, text, sensitive information)
    private func generatePrivacyInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Face detection privacy warning
        let faceCount = result.objects.filter { $0.identifier.lowercased().contains("face") }.count
        if faceCount > 0 {
            insights.append(AIInsight(
                type: .privacy,
                title: "Faces Detected",
                description: "Image contains \(faceCount) \(faceCount == 1 ? "face" : "faces"). Consider privacy before sharing publicly",
                confidence: 0.95,
                action: .none,
                priority: .critical,
                category: "Privacy",
                metadata: ["faceCount": "\(faceCount)"],
                icon: "eye.trianglebadge.exclamationmark"
            ))
        }
        
        // Text privacy check
        let totalTextLength = result.text.reduce(0) { $0 + $1.text.count }
        if totalTextLength > 50 {
            insights.append(AIInsight(
                type: .privacy,
                title: "Readable Text Present",
                description: "Image contains substantial text. Review for sensitive information before sharing",
                confidence: 0.85,
                action: .copy,
                priority: .high,
                category: "Privacy"
            ))
        }
        
        return insights
    }
    
    /// Generate organization insights (auto-tags, collections)
    private func generateOrganizationInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Smart tag suggestions
        if !result.smartTags.isEmpty {
            let topTags = Array(result.smartTags.prefix(3))
            let tagNames = topTags.map { $0.name }.joined(separator: ", ")
            insights.append(AIInsight(
                type: .organization,
                title: "Smart Tag Suggestions",
                description: "Consider tags: \(tagNames) for easier organization and search",
                confidence: Double(topTags.map { $0.confidence }.reduce(0, +)) / Double(topTags.count),
                action: .tag,
                priority: .medium,
                metadata: ["tags": tagNames]
            ))
        }
        
        // Collection suggestion based on content
        if let scene = result.scenes.first(where: { $0.confidence > 0.6 }) {
            let sceneName = scene.identifier.replacingOccurrences(of: "_", with: " ").capitalized
            insights.append(AIInsight(
                type: .organization,
                title: "Collection Suggestion",
                description: "Add to '\(sceneName)' collection for better organization",
                confidence: Double(scene.confidence),
                action: .addToCollection,
                priority: .low,
                metadata: ["collection": sceneName]
            ))
        }
        
        return insights
    }
    
    /// Generate enhancement insights (specific editing recommendations)
    private func generateEnhancementInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Specific enhancement based on quality metrics
        let metrics = result.qualityAssessment.metrics
        
        if metrics.sharpness < 0.5 {
            insights.append(AIInsight(
                type: .enhancement,
                title: "Sharpness Enhancement",
                description: "Apply sharpening to improve image clarity and detail",
                confidence: Double(1.0 - metrics.sharpness),
                action: .enhance,
                priority: .high
            ))
        }
        
        if metrics.exposure < 0.3 {
            insights.append(AIInsight(
                type: .enhancement,
                title: "Brighten Image",
                description: "Increase exposure to reveal more detail in shadows",
                confidence: Double(0.3 - metrics.exposure) / 0.3,
                action: .enhance,
                priority: .high
            ))
        } else if metrics.exposure > 0.8 {
            insights.append(AIInsight(
                type: .enhancement,
                title: "Reduce Exposure",
                description: "Decrease exposure to recover highlight detail",
                confidence: Double(metrics.exposure - 0.8) / 0.2,
                action: .enhance,
                priority: .high
            ))
        }
        
        return insights
    }
    
    /// Generate context insights (time, location, scene characteristics)
    private func generateContextInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Scene context
        if let primaryScene = result.scenes.first(where: { $0.confidence > 0.7 }) {
            let sceneName = primaryScene.identifier.replacingOccurrences(of: "_", with: " ").capitalized
            insights.append(AIInsight(
                type: .context,
                title: "Scene Type",
description: "Captured in a \(sceneName.lowercased()) setting",
                confidence: Double(primaryScene.confidence),
                action: .none,
                priority: .low,
                category: "Context",
                metadata: ["scene": sceneName]
            ))
        }
        
        return insights
    }
    
    /// Generate discovery insights (landmarks, barcodes, hidden details)
    private func generateDiscoveryInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Landmark discovery
        if let landmark = result.landmarks.first {
            insights.append(AIInsight(
                type: .discovery,
                title: "Landmark Identified",
                description: "Recognized '\(landmark.name)' - a notable location",
                confidence: Double(landmark.confidence),
                action: .navigate,
                priority: .high,
                category: "Discovery",
                metadata: ["landmark": landmark.name],
                icon: "mappin.and.ellipse"
            ))
        }
        
        // Barcode/QR code discovery
        if !result.barcodes.isEmpty {
            let barcodeCount = result.barcodes.count
            insights.append(AIInsight(
                type: .discovery,
                title: "Barcode Detected",
                description: "Found \(barcodeCount) \(barcodeCount == 1 ? "barcode" : "barcodes"). Tap to extract information",
                confidence: 0.95,
                action: .copy,
                priority: .high,
                category: "Discovery",
                metadata: ["count": "\(barcodeCount)"]
            ))
        }
        
        return insights
    }
    
    /// Generate action insights (quick actions based on content)
    private func generateActionInsights(from result: ImageAnalysisResult) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Export suggestion for high-quality images
        if result.quality == .high && result.qualityAssessment.metrics.megapixels > 8 {
            insights.append(AIInsight(
                type: .action,
                title: "Export Ready",
                description: "High quality image suitable for export and sharing",
                confidence: 0.85,
                action: .export,
                priority: .low,
                icon: "square.and.arrow.up"
            ))
        }
        
        // Share suggestion for people photos
        if !result.recognizedPeople.isEmpty {
            insights.append(AIInsight(
                type: .action,
                title: "Share with \(result.recognizedPeople[0].name)",
                description: "Quick share with recognized people",
                confidence: Double(result.recognizedPeople[0].confidence),
                action: .share,
                priority: .medium
            ))
        }
        
        return insights
    }
    
    private func prioritizeAndFilter(_ insights: [AIInsight]) -> [AIInsight] {
        // Sort by priority first, then confidence
        let sortedInsights = insights.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.confidence > rhs.confidence
        }
        
        // Limit to top 12 insights (increased from 5 for richer results)
        return Array(sortedInsights.prefix(12))
    }
}
