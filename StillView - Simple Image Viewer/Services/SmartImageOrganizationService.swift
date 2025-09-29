import Foundation
import CoreML
import Vision
import AppKit
import Combine
import NaturalLanguage

/// Smart image organization service using AI for automatic categorization
@MainActor
final class SmartImageOrganizationService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SmartImageOrganizationService()
    
    // MARK: - Published Properties
    
    /// Current organization status
    @Published private(set) var isOrganizing: Bool = false
    
    /// Organization progress (0.0 to 1.0)
    @Published private(set) var organizationProgress: Double = 0.0
    
    /// Organized categories
    @Published private(set) var categories: [SmartCategory] = []
    
    /// Smart collections
    @Published private(set) var smartCollections: [SmartCollection] = []
    
    /// Search suggestions
    @Published private(set) var searchSuggestions: [SearchSuggestion] = []
    
    // MARK: - Private Properties
    
    private let aiAnalysisService = AIImageAnalysisService.shared
    private let compatibilityService = MacOS26CompatibilityService.shared
    private var cancellables = Set<AnyCancellable>()
    private let organizationQueue = DispatchQueue(label: "com.vinny.smart.organization", qos: .userInitiated)
    
    // Organization cache
    private var organizationCache: [String: SmartCategory] = [:]
    private var collectionCache: [String: SmartCollection] = [:]
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Organize images into smart categories
    func organizeImages(_ images: [ImageFile]) async throws -> [SmartCategory] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw OrganizationError.featureNotAvailable
        }
        
        await MainActor.run {
            isOrganizing = true
            organizationProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isOrganizing = false
                organizationProgress = 0.0
            }
        }
        
        var categories: [String: SmartCategory] = [:]
        
        for (index, imageFile) in images.enumerated() {
            await MainActor.run {
                organizationProgress = Double(index) / Double(images.count)
            }
            
            do {
                let category = try await categorizeImage(imageFile)
                
                if var existingCategory = categories[category.name] {
                    existingCategory.images.append(imageFile)
                    existingCategory.confidence = max(existingCategory.confidence, category.confidence)
                    categories[category.name] = existingCategory
                } else {
                    categories[category.name] = category
                }
            } catch {
                // Handle categorization error
                continue
            }
        }
        
        let finalCategories = Array(categories.values).sorted { $0.confidence > $1.confidence }
        
        await MainActor.run {
            self.categories = finalCategories
        }
        
        return finalCategories
    }
    
    /// Create smart collections based on patterns
    func createSmartCollections(from images: [ImageFile]) async throws -> [SmartCollection] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw OrganizationError.featureNotAvailable
        }
        
        var collections: [SmartCollection] = []
        
        // Create time-based collections
        let timeCollections = try await createTimeBasedCollections(images)
        collections.append(contentsOf: timeCollections)
        
        // Create content-based collections
        let contentCollections = try await createContentBasedCollections(images)
        collections.append(contentsOf: contentCollections)
        
        // Create similarity-based collections
        let similarityCollections = try await createSimilarityBasedCollections(images)
        collections.append(contentsOf: similarityCollections)
        
        await MainActor.run {
            self.smartCollections = collections
        }
        
        return collections
    }
    
    /// Generate smart search suggestions
    func generateSearchSuggestions(for query: String, in images: [ImageFile]) async throws -> [SearchSuggestion] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            return []
        }
        
        // Use AI analysis service for intelligent search
        let suggestions = try await aiAnalysisService.generateSearchSuggestions(for: query, in: images)
        
        await MainActor.run {
            self.searchSuggestions = suggestions
        }
        
        return suggestions
    }
    
    /// Find similar images
    /// Migration Note: Uses canonical SimilarImageResult type from SmartSearchService
    /// This ensures consistency across all services that work with similar image results
    func findSimilarImages(to referenceImage: ImageFile, in collection: [ImageFile]) async throws -> [SimilarImageResult] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            return []
        }
        
        return try await aiAnalysisService.predictSimilarImages(to: referenceImage, in: collection)
    }
    
    /// Auto-tag images with relevant keywords
    func autoTagImages(_ images: [ImageFile]) async throws -> [ImageFile: [String]] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw OrganizationError.featureNotAvailable
        }
        
        var taggedImages: [ImageFile: [String]] = [:]
        
        for imageFile in images {
            if let image = NSImage(contentsOf: imageFile.url) {
                let analysis = try await aiAnalysisService.analyzeImage(image, url: imageFile.url)
                let tags = extractTags(from: analysis)
                taggedImages[imageFile] = tags
            }
        }
        
        return taggedImages
    }
    
    /// Generate smart album suggestions
    func generateAlbumSuggestions(from images: [ImageFile]) async throws -> [AlbumSuggestion] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw OrganizationError.featureNotAvailable
        }
        
        var suggestions: [AlbumSuggestion] = []
        
        // Analyze images for patterns
        let categories = try await organizeImages(images)
        
        // Generate suggestions based on categories
        for category in categories {
            if category.images.count >= 3 { // Minimum images for an album
                suggestions.append(AlbumSuggestion(
                    name: "\(category.name) Collection",
                    description: "\(category.images.count) images of \(category.name.lowercased())",
                    images: category.images,
                    confidence: category.confidence
                ))
            }
        }
        
        // Generate time-based suggestions
        let timeSuggestions = try await generateTimeBasedAlbumSuggestions(images)
        suggestions.append(contentsOf: timeSuggestions)
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe AI analysis service changes
        aiAnalysisService.$isAnalyzing
            .sink { [weak self] isAnalyzing in
                if isAnalyzing {
                    self?.isOrganizing = true
                }
            }
            .store(in: &cancellables)
    }
    
    private func categorizeImage(_ imageFile: ImageFile) async throws -> SmartCategory {
        let cacheKey = imageFile.url.absoluteString
        
        if let cachedCategory = organizationCache[cacheKey] {
            return cachedCategory
        }
        
        guard let image = NSImage(contentsOf: imageFile.url) else {
            throw OrganizationError.invalidImage
        }
        
        let analysis = try await aiAnalysisService.analyzeImage(image, url: imageFile.url)
        let category = determineCategory(from: analysis, imageFile: imageFile)
        
        organizationCache[cacheKey] = category
        return category
    }
    
    private func determineCategory(from analysis: ImageAnalysisResult, imageFile: ImageFile) -> SmartCategory {
        // Determine category based on AI analysis
        let primaryClassification = analysis.classifications.first?.identifier ?? "unknown"
        let confidence = analysis.classifications.first?.confidence ?? 0.0
        
        // Map classifications to categories
        let categoryName = mapClassificationToCategory(primaryClassification)
        
        return SmartCategory(
            name: categoryName,
            description: generateCategoryDescription(categoryName, analysis),
            images: [imageFile],
            confidence: Double(confidence),
            keywords: extractKeywords(from: analysis),
            color: determineCategoryColor(categoryName),
            icon: determineCategoryIcon(categoryName)
        )
    }
    
    private func mapClassificationToCategory(_ classification: String) -> String {
        let lowercased = classification.lowercased()
        
        switch lowercased {
        case let category where category.contains("person") || category.contains("people") || category.contains("portrait"):
            return "People"
        case let category where category.contains("animal") || category.contains("pet") || category.contains("dog") || category.contains("cat"):
            return "Animals"
        case let category where category.contains("landscape") || category.contains("nature") ||
                               category.contains("mountain") || category.contains("forest"):
            return "Nature"
        case let category where category.contains("food") || category.contains("meal") || category.contains("restaurant"):
            return "Food"
        case let category where category.contains("vehicle") || category.contains("car") ||
                               category.contains("truck") || category.contains("motorcycle"):
            return "Vehicles"
        case let category where category.contains("building") || category.contains("architecture") || category.contains("house"):
            return "Architecture"
        case let category where category.contains("sport") || category.contains("athlete") || category.contains("game"):
            return "Sports"
        case let category where category.contains("art") || category.contains("painting") || category.contains("sculpture"):
            return "Art"
        case let category where category.contains("travel") || category.contains("vacation") || category.contains("trip"):
            return "Travel"
        case let category where category.contains("event") || category.contains("party") || category.contains("celebration"):
            return "Events"
        default:
            return "Other"
        }
    }
    
    private func generateCategoryDescription(_ categoryName: String, _ analysis: ImageAnalysisResult) -> String {
        var description = "Images of \(categoryName.lowercased())"
        
        if let primaryClassification = analysis.classifications.first {
            description += " (\(primaryClassification.identifier))"
        }
        
        if !analysis.objects.isEmpty {
            let objectNames = analysis.objects.map { $0.identifier }.joined(separator: ", ")
            description += " containing \(objectNames)"
        }
        
        return description
    }
    
    private func extractKeywords(from analysis: ImageAnalysisResult) -> [String] {
        var keywords: [String] = []
        
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
    
    private func determineCategoryColor(_ categoryName: String) -> NSColor {
        switch categoryName {
        case "People":
            return .systemBlue
        case "Animals":
            return .systemOrange
        case "Nature":
            return .systemGreen
        case "Food":
            return .systemRed
        case "Vehicles":
            return .systemGray
        case "Architecture":
            return .systemPurple
        case "Sports":
            return .systemYellow
        case "Art":
            return .systemPink
        case "Travel":
            return .systemTeal
        case "Events":
            return .systemIndigo
        default:
            return .systemGray
        }
    }
    
    private func determineCategoryIcon(_ categoryName: String) -> String {
        switch categoryName {
        case "People":
            return "person.2.fill"
        case "Animals":
            return "pawprint.fill"
        case "Nature":
            return "leaf.fill"
        case "Food":
            return "fork.knife"
        case "Vehicles":
            return "car.fill"
        case "Architecture":
            return "building.2.fill"
        case "Sports":
            return "sportscourt.fill"
        case "Art":
            return "paintbrush.fill"
        case "Travel":
            return "airplane"
        case "Events":
            return "party.popper.fill"
        default:
            return "photo.fill"
        }
    }
    
    private func createTimeBasedCollections(_ images: [ImageFile]) async throws -> [SmartCollection] {
        var collections: [SmartCollection] = []
        
        // Group by creation date
        let calendar = Calendar.current
        let groupedImages = Dictionary(grouping: images) { imageFile in
            calendar.dateInterval(of: .day, for: imageFile.creationDate)?.start ?? imageFile.creationDate
        }
        
        for (date, dayImages) in groupedImages {
            if dayImages.count >= 3 { // Minimum images for a collection
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                
                collections.append(SmartCollection(
                    name: "\(formatter.string(from: date))",
                    description: "\(dayImages.count) images from this day",
                    images: dayImages,
                    type: .timeBased,
                    confidence: 0.8
                ))
            }
        }
        
        return collections
    }
    
    private func createContentBasedCollections(_ images: [ImageFile]) async throws -> [SmartCollection] {
        let categories = try await organizeImages(images)
        var collections: [SmartCollection] = []
        
        for category in categories {
            if category.images.count >= 3 {
                collections.append(SmartCollection(
                    name: "\(category.name) Collection",
                    description: category.description,
                    images: category.images,
                    type: .contentBased,
                    confidence: category.confidence
                ))
            }
        }
        
        return collections
    }
    
    private func createSimilarityBasedCollections(_ images: [ImageFile]) async throws -> [SmartCollection] {
        var collections: [SmartCollection] = []
        var processedImages: Set<String> = []
        
        for imageFile in images {
            if processedImages.contains(imageFile.id.uuidString) { continue }
            
                // Migration Note: Uses canonical SimilarImageResult type for consistency
            let similarImages: [SimilarImageResult] = try await findSimilarImages(to: imageFile, in: images)
            let similarImageFiles = similarImages.map { $0.imageFile }
            
            if similarImageFiles.count >= 3 {
                collections.append(SmartCollection(
                    name: "Similar to \(imageFile.displayName)",
                    description: "\(similarImageFiles.count) similar images",
                    images: similarImageFiles,
                    type: .similarityBased,
                    confidence: 0.7
                ))
                
                // Mark similar images as processed
                for similarImage in similarImageFiles {
                    processedImages.insert(similarImage.id.uuidString)
                }
            }
        }
        
        return collections
    }
    
    private func generateTimeBasedAlbumSuggestions(_ images: [ImageFile]) async throws -> [AlbumSuggestion] {
        var suggestions: [AlbumSuggestion] = []
        
        // Group by month
        let calendar = Calendar.current
        let groupedImages = Dictionary(grouping: images) { imageFile in
            let components = calendar.dateComponents([.year, .month], from: imageFile.creationDate)
            return "\(components.year ?? 0)-\(components.month ?? 0)"
        }
        
        for (_, monthImages) in groupedImages {
            if monthImages.count >= 5 {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                let sampleDate = monthImages.first?.creationDate ?? Date()
                
                suggestions.append(AlbumSuggestion(
                    name: formatter.string(from: sampleDate),
                    description: "\(monthImages.count) images from this month",
                    images: monthImages,
                    confidence: 0.9
                ))
            }
        }
        
        return suggestions
    }
    
    private func extractTags(from analysis: ImageAnalysisResult) -> [String] {
        var tags: [String] = []
        
        // Add high-confidence classifications as tags
        tags.append(contentsOf: analysis.classifications
            .filter { $0.confidence > 0.8 }
            .map { $0.identifier })
        
        // Add detected objects as tags
        tags.append(contentsOf: analysis.objects.map { $0.identifier })
        
        // Add scene information as tags
        tags.append(contentsOf: analysis.scenes.map { $0.identifier })
        
        return Array(Set(tags)) // Remove duplicates
    }
}

// MARK: - Supporting Types

/// Smart category for organizing images
struct SmartCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    var images: [ImageFile]
    var confidence: Double
    let keywords: [String]
    let color: NSColor
    let icon: String
    
    var imageCount: Int {
        return images.count
    }
    
    var primaryKeyword: String {
        return keywords.first ?? name
    }
}

/// Smart collection for grouping related images
struct SmartCollection: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let images: [ImageFile]
    let type: CollectionType
    let confidence: Double
    
    var imageCount: Int {
        return images.count
    }
}

/// Collection types
enum CollectionType {
    case timeBased
    case contentBased
    case similarityBased
    case manual
}

/// Album suggestion
struct AlbumSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let images: [ImageFile]
    let confidence: Double
    
    var imageCount: Int {
        return images.count
    }
}

/// Organization errors
enum OrganizationError: LocalizedError {
    case featureNotAvailable
    case invalidImage
    case organizationFailed
    case insufficientImages
    
    var errorDescription: String? {
        switch self {
        case .featureNotAvailable:
            return "Smart organization feature is not available on this system"
        case .invalidImage:
            return "The provided image is invalid or corrupted"
        case .organizationFailed:
            return "Image organization failed"
        case .insufficientImages:
            return "Not enough images to create collections"
        }
    }
}

