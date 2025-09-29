import Foundation
import AppKit
import Combine
import NaturalLanguage

/// Enhanced accessibility service with AI-powered image descriptions
@MainActor
final class EnhancedAccessibilityService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = EnhancedAccessibilityService()
    
    // MARK: - Published Properties
    
    /// Current accessibility status
    @Published private(set) var isGeneratingDescription: Bool = false
    
    /// Generated descriptions cache
    @Published private(set) var descriptionCache: [String: AccessibilityDescription] = [:]
    
    /// Available accessibility features
    @Published private(set) var availableFeatures: Set<AccessibilityFeature> = []
    
    /// Current accessibility settings
    @Published var settings = AccessibilitySettings()
    
    // MARK: - Private Properties
    
    private let aiAnalysisService = AIImageAnalysisService.shared
    private let compatibilityService = MacOS26CompatibilityService.shared
    private var cancellables = Set<AnyCancellable>()
    private let descriptionQueue = DispatchQueue(label: "com.vinny.accessibility.description", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {
        setupFeatureDetection()
        setupSystemAccessibilityMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Generate comprehensive accessibility description for an image
    func generateAccessibilityDescription(for imageFile: ImageFile) async throws -> AccessibilityDescription {
        let cacheKey = imageFile.url.absoluteString
        
        // Check cache first
        if let cachedDescription = descriptionCache[cacheKey] {
            return cachedDescription
        }
        
        await MainActor.run {
            isGeneratingDescription = true
        }
        
        defer {
            Task { @MainActor in
                isGeneratingDescription = false
            }
        }
        
        guard let image = NSImage(contentsOf: imageFile.url) else {
            throw AccessibilityError.invalidImage
        }
        
        let description: AccessibilityDescription
        
        if compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
            description = try await generateAIDescription(image, imageFile: imageFile)
        } else {
            description = generateBasicDescription(image, imageFile: imageFile)
        }
        
        // Cache the description
        await MainActor.run {
            descriptionCache[cacheKey] = description
        }
        
        return description
    }
    
    /// Generate context-aware descriptions for image collections
    func generateCollectionDescription(for images: [ImageFile]) async throws -> CollectionAccessibilityDescription {
        guard !images.isEmpty else {
            throw AccessibilityError.emptyCollection
        }
        
        var descriptions: [ImageFile: AccessibilityDescription] = [:]
        var collectionInsights: [String] = []
        
        // Generate descriptions for each image
        for imageFile in images {
            do {
                let description = try await generateAccessibilityDescription(for: imageFile)
                descriptions[imageFile] = description
            } catch {
                // Continue with other images if one fails
                continue
            }
        }
        
        // Generate collection-level insights
        if compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
            collectionInsights = try await generateCollectionInsights(descriptions)
        }
        
        return CollectionAccessibilityDescription(
            imageDescriptions: descriptions,
            collectionInsights: collectionInsights,
            totalImages: images.count,
            describedImages: descriptions.count
        )
    }
    
    /// Generate smart navigation hints for image browsing
    func generateNavigationHints(for imageFile: ImageFile, in collection: [ImageFile]) async throws -> NavigationHints {
        guard let currentIndex = collection.firstIndex(where: { $0.id == imageFile.id }) else {
            throw AccessibilityError.imageNotInCollection
        }
        
        var hints: [String] = []
        
        // Basic navigation info
        hints.append("Image \(currentIndex + 1) of \(collection.count)")
        
        // Content-based hints
        if compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
            let description = try await generateAccessibilityDescription(for: imageFile)
            hints.append("Content: \(description.primaryDescription)")
            
            // Add context from adjacent images
            if currentIndex > 0 {
                let previousDescription = try? await generateAccessibilityDescription(for: collection[currentIndex - 1])
                if let prev = previousDescription {
                    hints.append("Previous: \(prev.primaryDescription)")
                }
            }
            
            if currentIndex < collection.count - 1 {
                let nextDescription = try? await generateAccessibilityDescription(for: collection[currentIndex + 1])
                if let next = nextDescription {
                    hints.append("Next: \(next.primaryDescription)")
                }
            }
        }
        
        return NavigationHints(
            currentImage: imageFile,
            position: currentIndex + 1,
            totalImages: collection.count,
            hints: hints
        )
    }
    
    /// Generate voice-over optimized descriptions
    func generateVoiceOverDescription(for imageFile: ImageFile) async throws -> VoiceOverDescription {
        let description = try await generateAccessibilityDescription(for: imageFile)
        
        // Optimize for voice-over reading
        let voiceOverText = optimizeForVoiceOver(description)
        
        return VoiceOverDescription(
            imageFile: imageFile,
            description: voiceOverText,
            readingTime: estimateReadingTime(voiceOverText),
            pronunciationHints: generatePronunciationHints(description)
        )
    }
    
    /// Generate multi-language descriptions
    func generateMultiLanguageDescription(
        for imageFile: ImageFile,
        languages: [String] = ["en", "es", "fr", "de"]
    ) async throws -> MultiLanguageDescription {
        let baseDescription = try await generateAccessibilityDescription(for: imageFile)
        var translations: [String: String] = [:]
        
        // For now, we'll use the base description for all languages
        // In a real implementation, this would use translation services
        for language in languages {
            translations[language] = baseDescription.primaryDescription
        }
        
        return MultiLanguageDescription(
            imageFile: imageFile,
            baseDescription: baseDescription,
            translations: translations,
            supportedLanguages: languages
        )
    }
    
    /// Generate contextual help for image viewing
    func generateContextualHelp(for imageFile: ImageFile, context: ViewingContext) async throws -> ContextualHelp {
        let description = try await generateAccessibilityDescription(for: imageFile)
        
        var helpItems: [HelpItem] = []
        
        // Basic navigation help
        helpItems.append(HelpItem(
            title: "Navigation",
            content: "Use arrow keys to navigate between images, or swipe on trackpad",
            category: .navigation
        ))
        
        // Zoom help
        helpItems.append(HelpItem(
            title: "Zoom",
            content: "Use + and - keys to zoom in and out, or pinch on trackpad",
            category: .interaction
        ))
        
        // Content-specific help
        if compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
            let contentHelp = generateContentSpecificHelp(description, context: context)
            helpItems.append(contentsOf: contentHelp)
        }
        
        return ContextualHelp(
            imageFile: imageFile,
            context: context,
            helpItems: helpItems,
            priority: determineHelpPriority(description, context: context)
        )
    }
    
    // MARK: - Private Methods
    
    private func setupFeatureDetection() {
        availableFeatures = Set(AccessibilityFeature.allCases.filter { feature in
            isFeatureSupported(feature)
        })
    }
    
    private func isFeatureSupported(_ feature: AccessibilityFeature) -> Bool {
        switch feature {
        case .aiDescriptions:
            return compatibilityService.isFeatureAvailable(.aiImageAnalysis)
        case .voiceOverOptimization:
            return true
        case .multiLanguageSupport:
            return compatibilityService.isMacOS15OrLater
        case .contextualHelp:
            return true
        case .smartNavigation:
            return compatibilityService.isFeatureAvailable(.aiImageAnalysis)
        case .pronunciationHints:
            return true
        }
    }
    
    private func setupSystemAccessibilityMonitoring() {
        // Monitor system accessibility settings
        NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilitySettings()
            }
            .store(in: &cancellables)
    }
    
    private func updateAccessibilitySettings() {
        // Update settings based on system preferences
        settings.isVoiceOverEnabled = NSWorkspace.shared.isVoiceOverEnabled
        // Note: These properties may not be available on all macOS versions
        settings.isReducedMotionEnabled = false // Fallback value
        settings.isHighContrastEnabled = false // Fallback value
    }
    
    private func generateAIDescription(_ image: NSImage, imageFile: ImageFile) async throws -> AccessibilityDescription {
        let analysis = try await aiAnalysisService.analyzeImage(image, url: imageFile.url)
        return generateDescriptionFromAnalysis(analysis, imageFile: imageFile)
    }
    
    private func generateBasicDescription(_ image: NSImage, imageFile: ImageFile) -> AccessibilityDescription {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var description = "Image"
        
        // Add size information
        if size.width > 0 && size.height > 0 {
            description += " (\(Int(size.width)) by \(Int(size.height)) pixels)"
        }
        
        // Add aspect ratio information
        if aspectRatio > 1.5 {
            description += ", landscape orientation"
        } else if aspectRatio < 0.67 {
            description += ", portrait orientation"
        } else {
            description += ", square format"
        }
        
        // Add file information
        description += ", \(imageFile.formatDescription)"
        
        return AccessibilityDescription(
            primaryDescription: description,
            detailedDescription: "Image file: \(imageFile.displayName), size: \(imageFile.formattedSize)",
            keywords: [imageFile.formatDescription, "image"]
        )
    }
    
    private func generateDescriptionFromAnalysis(_ analysis: ImageAnalysisResult, imageFile: ImageFile) -> AccessibilityDescription {
        var primaryDescription = "Image"
        
        // Add primary classification
        if let primaryClassification = analysis.classifications.first {
            primaryDescription += " of \(primaryClassification.identifier)"
        }
        
        // Add object information
        if !analysis.objects.isEmpty {
            let objectNames = analysis.objects.map { $0.identifier }.joined(separator: ", ")
            primaryDescription += " containing \(objectNames)"
        }
        
        // Add scene information
        if !analysis.scenes.isEmpty {
            let sceneNames = analysis.scenes.map { $0.identifier }.joined(separator: ", ")
            primaryDescription += " in a \(sceneNames) setting"
        }
        
        // Add quality information
        switch analysis.quality {
        case .high:
            primaryDescription += " (high quality)"
        case .medium:
            primaryDescription += " (medium quality)"
        case .low:
            primaryDescription += " (low quality)"
        case .unknown:
            break
        }
        
        // Generate detailed description
        let detailedDescription = generateDetailedDescription(analysis, imageFile: imageFile)
        
        // Extract keywords
        let keywords = extractKeywords(from: analysis, imageFile: imageFile)
        
        return AccessibilityDescription(
            primaryDescription: primaryDescription,
            detailedDescription: detailedDescription,
            keywords: keywords
        )
    }
    
    private func generateDetailedDescription(_ analysis: ImageAnalysisResult, imageFile: ImageFile) -> String {
        var details: [String] = []
        
        // Add file information
        details.append("File: \(imageFile.displayName) (\(imageFile.formattedSize))")
        
        // Add classification details
        for classification in analysis.classifications.prefix(3) {
            details.append("\(classification.identifier) (\(Int(classification.confidence * 100))% confidence)")
        }
        
        // Add object details
        for object in analysis.objects.prefix(3) {
            details.append("Contains \(object.identifier)")
        }
        
        // Add color information
        if !analysis.colors.isEmpty {
            let colorNames = analysis.colors.map { "\($0.color)" }.joined(separator: ", ")
            details.append("Dominant colors: \(colorNames)")
        }
        
        // Add text information
        if !analysis.text.isEmpty {
            let textContent = analysis.text.map { $0.text }.joined(separator: ", ")
            details.append("Text content: \(textContent)")
        }
        
        return details.joined(separator: ". ")
    }
    
    private func extractKeywords(from analysis: ImageAnalysisResult, imageFile: ImageFile) -> [String] {
        var keywords: [String] = []
        
        // Add file format
        keywords.append(imageFile.formatDescription)
        
        // Add high-confidence classifications
        keywords.append(contentsOf: analysis.classifications
            .filter { $0.confidence > 0.7 }
            .map { $0.identifier })
        
        // Add detected objects
        keywords.append(contentsOf: analysis.objects.map { $0.identifier })
        
        // Add scene information
        keywords.append(contentsOf: analysis.scenes.map { $0.identifier })
        
        return Array(Set(keywords)) // Remove duplicates
    }
    
    private func generateCollectionInsights(_ descriptions: [ImageFile: AccessibilityDescription]) async throws -> [String] {
        var insights: [String] = []
        
        // Analyze common themes
        let allKeywords = descriptions.values.flatMap { $0.keywords }
        let keywordCounts = Dictionary(grouping: allKeywords, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        // Add top themes
        for (keyword, count) in keywordCounts.prefix(3) {
            insights.append("\(count) images contain \(keyword)")
        }
        
        // Analyze quality distribution
        let qualityDistribution = descriptions.values.compactMap { description in
            description.keywords.first { $0.contains("quality") }
        }
        
        if !qualityDistribution.isEmpty {
            insights.append("Quality varies across the collection")
        }
        
        return insights
    }
    
    private func optimizeForVoiceOver(_ description: AccessibilityDescription) -> String {
        var optimized = description.primaryDescription
        
        // Add pauses for better voice-over reading
        optimized = optimized.replacingOccurrences(of: ", ", with: ", ")
        optimized = optimized.replacingOccurrences(of: ". ", with: ". ")
        
        // Add emphasis for important information
        if description.keywords.contains("high quality") {
            optimized = optimized.replacingOccurrences(of: "high quality", with: "high quality")
        }
        
        return optimized
    }
    
    private func estimateReadingTime(_ text: String) -> TimeInterval {
        // Estimate reading time based on word count
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).count
        let wordsPerMinute = 200.0 // Average reading speed
        return Double(wordCount) / wordsPerMinute * 60.0
    }
    
    private func generatePronunciationHints(_ description: AccessibilityDescription) -> [String] {
        var hints: [String] = []
        
        // Add pronunciation hints for technical terms
        for keyword in description.keywords {
            if keyword.contains("HEIF") {
                hints.append("HEIF is pronounced 'heef'")
            } else if keyword.contains("JPEG") {
                hints.append("JPEG is pronounced 'jay-peg'")
            } else if keyword.contains("PNG") {
                hints.append("PNG is pronounced 'ping'")
            }
        }
        
        return hints
    }
    
    private func generateContentSpecificHelp(_ description: AccessibilityDescription, context: ViewingContext) -> [HelpItem] {
        var helpItems: [HelpItem] = []
        
        // Add help based on content type
        if description.keywords.contains("portrait") {
            helpItems.append(HelpItem(
                title: "Portrait Viewing",
                content: "This appears to be a portrait. Use zoom to see facial details clearly.",
                category: .content
            ))
        }
        
        if description.keywords.contains("landscape") {
            helpItems.append(HelpItem(
                title: "Landscape Viewing",
                content: "This is a landscape image. Use fullscreen mode for the best viewing experience.",
                category: .content
            ))
        }
        
        if description.keywords.contains("text") {
            helpItems.append(HelpItem(
                title: "Text in Image",
                content: "This image contains text. Use zoom to read it clearly.",
                category: .content
            ))
        }
        
        return helpItems
    }
    
    private func determineHelpPriority(_ description: AccessibilityDescription, context: ViewingContext) -> HelpPriority {
        // Determine priority based on content and context
        if description.keywords.contains("high quality") {
            return .high
        } else if context == .slideshow {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Supporting Types

/// Accessibility features
enum AccessibilityFeature: String, CaseIterable {
    case aiDescriptions = "ai_descriptions"
    case voiceOverOptimization = "voiceover_optimization"
    case multiLanguageSupport = "multilanguage_support"
    case contextualHelp = "contextual_help"
    case smartNavigation = "smart_navigation"
    case pronunciationHints = "pronunciation_hints"
    
    var displayName: String {
        switch self {
        case .aiDescriptions:
            return "AI Descriptions"
        case .voiceOverOptimization:
            return "VoiceOver Optimization"
        case .multiLanguageSupport:
            return "Multi-Language Support"
        case .contextualHelp:
            return "Contextual Help"
        case .smartNavigation:
            return "Smart Navigation"
        case .pronunciationHints:
            return "Pronunciation Hints"
        }
    }
}

/// Accessibility settings
struct AccessibilitySettings {
    var isVoiceOverEnabled: Bool = false
    var isReducedMotionEnabled: Bool = false
    var isHighContrastEnabled: Bool = false
    var preferredDescriptionLength: DescriptionLength = .medium
    var includeTechnicalDetails: Bool = true
    var useNaturalLanguage: Bool = true
}

/// Description length options
enum DescriptionLength {
    case short
    case medium
    case detailed
    
    var maxWords: Int {
        switch self {
        case .short:
            return 10
        case .medium:
            return 25
        case .detailed:
            return 50
        }
    }
}

/// Collection accessibility description
struct CollectionAccessibilityDescription {
    let imageDescriptions: [ImageFile: AccessibilityDescription]
    let collectionInsights: [String]
    let totalImages: Int
    let describedImages: Int
    
    var coveragePercentage: Double {
        return Double(describedImages) / Double(totalImages) * 100.0
    }
}

/// Navigation hints
struct NavigationHints {
    let currentImage: ImageFile
    let position: Int
    let totalImages: Int
    let hints: [String]
}

/// Voice-over description
struct VoiceOverDescription {
    let imageFile: ImageFile
    let description: String
    let readingTime: TimeInterval
    let pronunciationHints: [String]
}

/// Multi-language description
struct MultiLanguageDescription {
    let imageFile: ImageFile
    let baseDescription: AccessibilityDescription
    let translations: [String: String]
    let supportedLanguages: [String]
}

/// Viewing context
enum ViewingContext {
    case normal
    case slideshow
    case fullscreen
    case grid
    case search
}

/// Contextual help
struct ContextualHelp {
    let imageFile: ImageFile
    let context: ViewingContext
    let helpItems: [HelpItem]
    let priority: HelpPriority
}

/// Help item
struct HelpItem {
    let title: String
    let content: String
    let category: HelpCategory
}

/// Help categories
enum HelpCategory {
    case navigation
    case interaction
    case content
    case technical
}

/// Help priority
enum HelpPriority {
    case low
    case medium
    case high
}

/// Accessibility errors
enum AccessibilityError: LocalizedError {
    case invalidImage
    case emptyCollection
    case imageNotInCollection
    case descriptionGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image is invalid or corrupted"
        case .emptyCollection:
            return "The image collection is empty"
        case .imageNotInCollection:
            return "The image is not part of the specified collection"
        case .descriptionGenerationFailed:
            return "Failed to generate accessibility description"
        }
    }
}
