import Foundation
import NaturalLanguage
import AppKit
import Combine

/// Smart search service with AI-powered image discovery
@MainActor
final class SmartSearchService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SmartSearchService()
    
    // MARK: - Published Properties
    
    /// Current search status
    @Published private(set) var isSearching: Bool = false
    
    /// Search results
    @Published private(set) var searchResults: [SearchResult] = []
    
    /// Search suggestions
    @Published private(set) var searchSuggestions: [SmartSearchSuggestion] = []
    
    /// Recent searches
    @Published private(set) var recentSearches: [String] = []
    
    /// Search history
    @Published private(set) var searchHistory: [SearchHistoryItem] = []
    
    // MARK: - Private Properties
    
    private let aiAnalysisService = AIImageAnalysisService.shared
    private let smartOrganizationService = SmartImageOrganizationService.shared
    private let compatibilityService = MacOS26CompatibilityService.shared
    private var cancellables = Set<AnyCancellable>()
    private let searchQueue = DispatchQueue(label: "com.vinny.smart.search", qos: .userInitiated)
    
    // Search cache
    private var searchCache: [String: [SearchResult]] = [:]
    private var suggestionCache: [String: [SmartSearchSuggestion]] = [:]
    
    // MARK: - Initialization
    
    private init() {
        loadSearchHistory()
        setupSearchMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Perform smart search across image collection
    func searchImages(_ query: String, in images: [ImageFile]) async throws -> [SearchResult] {
        guard !query.isEmpty else {
            await MainActor.run {
                searchResults = []
            }
            return []
        }
        
        let cacheKey = "\(query)_\(images.count)"
        
        // Check cache first
        if let cachedResults = searchCache[cacheKey] {
            await MainActor.run {
                searchResults = cachedResults
            }
            return cachedResults
        }
        
        await MainActor.run {
            isSearching = true
        }
        
        defer {
            Task { @MainActor in
                isSearching = false
            }
        }
        
        // Perform search
        let results = try await performSmartSearch(query, in: images)
        
        // Cache results
        searchCache[cacheKey] = results
        
        // Update search history
        await updateSearchHistory(query, results: results)
        
        await MainActor.run {
            searchResults = results
        }
        
        return results
    }
    
    /// Generate search suggestions based on query and collection
    func generateSearchSuggestions(for query: String, in images: [ImageFile]) async throws -> [SmartSearchSuggestion] {
        let cacheKey = "suggestions_\(query)_\(images.count)"
        
        // Check cache first
        if let cachedSuggestions = suggestionCache[cacheKey] {
            await MainActor.run {
                searchSuggestions = cachedSuggestions
            }
            return cachedSuggestions
        }
        
        var suggestions: [SmartSearchSuggestion] = []
        
        // Generate AI-powered suggestions if available
        if compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
            let aiSuggestions = try await aiAnalysisService.generateSearchSuggestions(for: query, in: images)
            suggestions.append(contentsOf: aiSuggestions.map(SmartSearchSuggestion.init))
        }
        
        // Generate content-based suggestions
        let contentSuggestions = try await generateContentBasedSuggestions(query, in: images)
        suggestions.append(contentsOf: contentSuggestions)

        // Generate metadata-based suggestions
        let metadataSuggestions = generateMetadataBasedSuggestions(query, in: images)
        suggestions.append(contentsOf: metadataSuggestions)
        
        // Remove duplicates and sort by confidence
        suggestions = Array(Set(suggestions)).sorted { $0.confidence > $1.confidence }
        
        // Cache suggestions
        suggestionCache[cacheKey] = suggestions
        
        await MainActor.run {
            self.searchSuggestions = suggestions
        }
        
        return suggestions
    }
    
    /// Find similar images using AI
    /// Migration Note: Returns canonical SimilarImageResult type for consistency across services
    func findSimilarImages(to referenceImage: ImageFile, in collection: [ImageFile]) async throws -> [SimilarImageResult] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            return []
        }
        
        return try await aiAnalysisService.predictSimilarImages(to: referenceImage, in: collection)
    }
    
    /// Search by visual similarity
    func searchByVisualSimilarity(to referenceImage: ImageFile, in collection: [ImageFile]) async throws -> [SearchResult] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            return []
        }
        
        let similarImages = try await findSimilarImages(to: referenceImage, in: collection)
        
        return similarImages.map { similarImage in
            SearchResult(
                imageFile: similarImage.imageFile,
                relevanceScore: similarImage.similarity,
                matchType: .visualSimilarity,
                matchDetails: similarImage.reasons,
                searchQuery: "Similar to \(referenceImage.displayName)"
            )
        }
    }
    
    /// Search by date range
    func searchByDateRange(from startDate: Date, to endDate: Date, in images: [ImageFile]) async throws -> [SearchResult] {
        let filteredImages = images.filter { imageFile in
            imageFile.creationDate >= startDate && imageFile.creationDate <= endDate
        }
        
        return filteredImages.map { imageFile in
            SearchResult(
                imageFile: imageFile,
                relevanceScore: 1.0,
                matchType: .dateRange,
                matchDetails: ["Created between \(startDate.formatted()) and \(endDate.formatted())"],
                searchQuery: "Date range search"
            )
        }
    }
    
    /// Search by file size range
    func searchByFileSize(minSize: Int64, maxSize: Int64, in images: [ImageFile]) async throws -> [SearchResult] {
        let filteredImages = images.filter { imageFile in
            imageFile.size >= minSize && imageFile.size <= maxSize
        }
        
        return filteredImages.map { imageFile in
            SearchResult(
                imageFile: imageFile,
                relevanceScore: 1.0,
                matchType: .fileSize,
                matchDetails: ["File size: \(imageFile.formattedSize)"],
                searchQuery: "File size search"
            )
        }
    }
    
    /// Search by image format
    func searchByFormat(_ format: String, in images: [ImageFile]) async throws -> [SearchResult] {
        let filteredImages = images.filter { imageFile in
            imageFile.formatDescription.lowercased().contains(format.lowercased())
        }
        
        return filteredImages.map { imageFile in
            SearchResult(
                imageFile: imageFile,
                relevanceScore: 1.0,
                matchType: .format,
                matchDetails: ["Format: \(imageFile.formatDescription)"],
                searchQuery: "Format: \(format)"
            )
        }
    }
    
    /// Advanced search with multiple criteria
    func advancedSearch(_ criteria: SearchCriteria, in images: [ImageFile]) async throws -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Apply each criterion
        for criterion in criteria.criteria {
            let criterionResults = try await applySearchCriterion(criterion, to: images)
            results.append(contentsOf: criterionResults)
        }
        
        // Combine and deduplicate results
        let combinedResults = combineSearchResults(results, criteria: criteria)
        
        return combinedResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    /// Clear search cache
    func clearSearchCache() {
        searchCache.removeAll()
        suggestionCache.removeAll()
    }
    
    /// Clear search history
    func clearSearchHistory() {
        searchHistory.removeAll()
        recentSearches.removeAll()
        saveSearchHistory()
    }
    
    // MARK: - Private Methods
    
    private func setupSearchMonitoring() {
        // Monitor for changes that might affect search results
        NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.clearSearchCache()
            }
            .store(in: &cancellables)
    }
    
    private func performSmartSearch(_ query: String, in images: [ImageFile]) async throws -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Text-based search
        let textResults = try await performTextSearch(query, in: images)
        results.append(contentsOf: textResults)
        
        // AI-powered search if available
        if compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
            let aiResults = try await performAISearch(query, in: images)
            results.append(contentsOf: aiResults)
        }
        
        // Metadata search
        let metadataResults = performMetadataSearch(query, in: images)
        results.append(contentsOf: metadataResults)
        
        // Combine and deduplicate results
        let combinedResults = combineSearchResults(results, criteria: nil)
        
        return combinedResults.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func performTextSearch(_ query: String, in images: [ImageFile]) async throws -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Search in file names
        let nameResults = images.filter { imageFile in
            imageFile.displayName.localizedCaseInsensitiveContains(query)
        }.map { imageFile in
            SearchResult(
                imageFile: imageFile,
                relevanceScore: calculateNameRelevance(query, imageFile: imageFile),
                matchType: .fileName,
                matchDetails: ["Filename contains '\(query)'"],
                searchQuery: query
            )
        }
        results.append(contentsOf: nameResults)
        
        // Search in AI-generated descriptions if available
        if compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
            for imageFile in images {
                if let image = NSImage(contentsOf: imageFile.url) {
                    do {
                        let analysis = try await aiAnalysisService.analyzeImage(image, url: imageFile.url)
                        let description = generateDescriptionFromAnalysis(analysis)
                        
                        if description.localizedCaseInsensitiveContains(query) {
                            results.append(SearchResult(
                                imageFile: imageFile,
                                relevanceScore: calculateDescriptionRelevance(query, description: description),
                                matchType: .contentDescription,
                                matchDetails: ["Content description contains '\(query)'"],
                                searchQuery: query
                            ))
                        }
                    } catch {
                        // Continue with other images if one fails
                        continue
                    }
                }
            }
        }
        
        return results
    }
    
    private func performAISearch(_ query: String, in images: [ImageFile]) async throws -> [SearchResult] {
        // Use AI to find semantically similar images
        let suggestions = try await aiAnalysisService.generateSearchSuggestions(for: query, in: images)
        var results: [SearchResult] = []
        
        for suggestion in suggestions {
            if suggestion.confidence > 0.7 {
                // Find images that match this suggestion
                let matchingImages = images.filter { imageFile in
                    // This would typically involve more sophisticated matching
                    imageFile.displayName.localizedCaseInsensitiveContains(suggestion.text)
                }
                
                for imageFile in matchingImages {
                    results.append(SearchResult(
                        imageFile: imageFile,
                        relevanceScore: Double(suggestion.confidence),
                        matchType: .aiSuggestion,
                        matchDetails: ["AI suggested: \(suggestion.text)"],
                        searchQuery: query
                    ))
                }
            }
        }
        
        return results
    }
    
    private func performMetadataSearch(_ query: String, in images: [ImageFile]) -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Search by file format
        let formatResults = images.filter { imageFile in
            imageFile.formatDescription.localizedCaseInsensitiveContains(query)
        }.map { imageFile in
            SearchResult(
                imageFile: imageFile,
                relevanceScore: 0.8,
                matchType: .format,
                matchDetails: ["Format: \(imageFile.formatDescription)"],
                searchQuery: query
            )
        }
        results.append(contentsOf: formatResults)
        
        // Search by file size (if query contains size information)
        if query.contains("MB") || query.contains("KB") || query.contains("GB") {
            let sizeResults = images.filter { imageFile in
                imageFile.formattedSize.localizedCaseInsensitiveContains(query)
            }.map { imageFile in
                SearchResult(
                    imageFile: imageFile,
                    relevanceScore: 0.7,
                    matchType: .fileSize,
                    matchDetails: ["Size: \(imageFile.formattedSize)"],
                    searchQuery: query
                )
            }
            results.append(contentsOf: sizeResults)
        }
        
        return results
    }
    
    private func generateContentBasedSuggestions(_ query: String, in images: [ImageFile]) async throws -> [SmartSearchSuggestion] {
        var suggestions: [SmartSearchSuggestion] = []
        
        // Analyze query for entities
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = query
        
        let range = query.startIndex..<query.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                let keyword = String(query[tokenRange])
                suggestions.append(SmartSearchSuggestion(
                    text: keyword,
                    type: .entity,
                    confidence: 0.8
                ))
            }
            return true
        }
        
        // Generate suggestions based on image content
        if compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
            let aiSuggestions = try await aiAnalysisService.generateSearchSuggestions(for: query, in: images)
            suggestions.append(contentsOf: aiSuggestions.map(SmartSearchSuggestion.init))
        }
        
        return suggestions
    }
    
    private func generateMetadataBasedSuggestions(_ query: String, in images: [ImageFile]) -> [SmartSearchSuggestion] {
        var suggestions: [SmartSearchSuggestion] = []
        
        // Extract unique formats
        let formats = Set(images.map { $0.formatDescription })
        for format in formats {
            if format.localizedCaseInsensitiveContains(query) {
                suggestions.append(SmartSearchSuggestion(
                    text: format,
                    type: .format,
                    confidence: 0.9
                ))
            }
        }
        
        // Extract size ranges
        let sizes = images.map { $0.size }.sorted()
        if let minSize = sizes.first, let maxSize = sizes.last {
            let sizeRange = "\(formatFileSize(minSize)) - \(formatFileSize(maxSize))"
            suggestions.append(SmartSearchSuggestion(
                text: sizeRange,
                type: .fileSize,
                confidence: 0.7
            ))
        }
        
        return suggestions
    }
    
    private func calculateNameRelevance(_ query: String, imageFile: ImageFile) -> Double {
        let name = imageFile.displayName.lowercased()
        let queryLower = query.lowercased()
        
        if name == queryLower {
            return 1.0
        } else if name.hasPrefix(queryLower) {
            return 0.9
        } else if name.contains(queryLower) {
            return 0.7
        } else {
            return 0.5
        }
    }
    
    private func calculateDescriptionRelevance(_ query: String, description: String) -> Double {
        let descriptionLower = description.lowercased()
        let queryLower = query.lowercased()
        
        if descriptionLower.contains(queryLower) {
            return 0.8
        } else {
            return 0.3
        }
    }
    
    private func generateDescriptionFromAnalysis(_ analysis: ImageAnalysisResult) -> String {
        var description = ""
        
        // Add primary classification
        if let primaryClassification = analysis.classifications.first {
            description += primaryClassification.identifier
        }
        
        // Add objects
        if !analysis.objects.isEmpty {
            let objectNames = analysis.objects.map { $0.identifier }.joined(separator: ", ")
            description += " containing \(objectNames)"
        }
        
        // Add scenes
        if !analysis.scenes.isEmpty {
            let sceneNames = analysis.scenes.map { $0.identifier }.joined(separator: ", ")
            description += " in \(sceneNames)"
        }
        
        return description
    }
    
    private func combineSearchResults(_ results: [SearchResult], criteria: SearchCriteria?) -> [SearchResult] {
        // Group by image file
        let groupedResults = Dictionary(grouping: results) { $0.imageFile.id }
        
        var combinedResults: [SearchResult] = []
        
        for (_, groupResults) in groupedResults {
            if groupResults.count == 1 {
                combinedResults.append(groupResults.first!)
            } else {
                // Combine multiple results for the same image
                let combinedResult = combineResultsForImage(groupResults)
                combinedResults.append(combinedResult)
            }
        }
        
        return combinedResults
    }
    
    private func combineResultsForImage(_ results: [SearchResult]) -> SearchResult {
        let firstResult = results.first!
        let totalRelevance = results.reduce(0) { $0 + $1.relevanceScore }
        let averageRelevance = totalRelevance / Double(results.count)
        
        let allMatchDetails = results.flatMap { $0.matchDetails }
        let allMatchTypes = results.map { $0.matchType }
        
        return SearchResult(
            imageFile: firstResult.imageFile,
            relevanceScore: averageRelevance,
            matchType: allMatchTypes.contains(.aiSuggestion) ? .aiSuggestion : firstResult.matchType,
            matchDetails: allMatchDetails,
            searchQuery: firstResult.searchQuery
        )
    }
    
    private func applySearchCriterion(_ criterion: SearchCriterion, to images: [ImageFile]) async throws -> [SearchResult] {
        switch criterion.type {
        case .text:
            return try await performTextSearch(criterion.value, in: images)
        case .dateRange:
            let dates = parseDateRange(criterion.value)
            return try await searchByDateRange(from: dates.start, to: dates.end, in: images)
        case .fileSize:
            let sizes = parseFileSizeRange(criterion.value)
            return try await searchByFileSize(minSize: sizes.min, maxSize: sizes.max, in: images)
        case .format:
            return try await searchByFormat(criterion.value, in: images)
        case .visualSimilarity:
            // This would require a reference image
            return []
        }
    }
    
    private func parseDateRange(_ value: String) -> (start: Date, end: Date) {
        // Simple date range parsing
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let startDate = formatter.date(from: "2020-01-01") ?? Date.distantPast
        let endDate = formatter.date(from: "2024-12-31") ?? Date()
        
        return (start: startDate, end: endDate)
    }
    
    private func parseFileSizeRange(_ value: String) -> (min: Int64, max: Int64) {
        // Simple file size range parsing
        return (min: 0, max: Int64.max)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func updateSearchHistory(_ query: String, results: [SearchResult]) async {
        let historyItem = SearchHistoryItem(
            query: query,
            resultCount: results.count,
            timestamp: Date()
        )
        
        await MainActor.run {
            searchHistory.insert(historyItem, at: 0)
            if !recentSearches.contains(query) {
                recentSearches.insert(query, at: 0)
            }
            
            // Limit history size
            if searchHistory.count > 100 {
                searchHistory = Array(searchHistory.prefix(100))
            }
            if recentSearches.count > 20 {
                recentSearches = Array(recentSearches.prefix(20))
            }
        }
        
        saveSearchHistory()
    }
    
    private func loadSearchHistory() {
        // Load search history from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "SearchHistory"),
           let history = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) {
            searchHistory = history
        }
        
        if let searches = UserDefaults.standard.array(forKey: "RecentSearches") as? [String] {
            recentSearches = searches
        }
    }
    
    private func saveSearchHistory() {
        // Save search history to UserDefaults
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "SearchHistory")
        }
        
        UserDefaults.standard.set(recentSearches, forKey: "RecentSearches")
    }
}

// MARK: - Supporting Types

/// Search result
struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let imageFile: ImageFile
    let relevanceScore: Double
    let matchType: MatchType
    let matchDetails: [String]
    let searchQuery: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(imageFile.id)
    }
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.imageFile.id == rhs.imageFile.id
    }
}

/// Match types
enum MatchType {
    case fileName
    case contentDescription
    case aiSuggestion
    case format
    case fileSize
    case dateRange
    case visualSimilarity
    
    var displayName: String {
        switch self {
        case .fileName:
            return "Filename"
        case .contentDescription:
            return "Content"
        case .aiSuggestion:
            return "AI Suggestion"
        case .format:
            return "Format"
        case .fileSize:
            return "File Size"
        case .dateRange:
            return "Date Range"
        case .visualSimilarity:
            return "Visual Similarity"
        }
    }
}

/// Search suggestion used by the smart search service
struct SmartSearchSuggestion: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let confidence: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
    }
    
    static func == (lhs: SmartSearchSuggestion, rhs: SmartSearchSuggestion) -> Bool {
        return lhs.text == rhs.text
    }

    init(text: String, type: SuggestionType, confidence: Double) {
        self.text = text
        self.type = type
        self.confidence = confidence
    }

    init(_ suggestion: SearchSuggestion) {
        // Convert SearchSuggestionType to SuggestionType
        let convertedType: SuggestionType
        switch suggestion.type {
        case .entity:
            convertedType = .entity
        case .classification:
            convertedType = .classification
        case .object:
            convertedType = .object
        case .scene:
            convertedType = .scene
        }

        self.init(text: suggestion.text, type: convertedType, confidence: suggestion.confidence)
    }
}

/// Suggestion types
enum SuggestionType {
    case entity
    case classification
    case object
    case scene
    case format
    case fileSize
    
    var displayName: String {
        switch self {
        case .entity:
            return "Entity"
        case .classification:
            return "Classification"
        case .object:
            return "Object"
        case .scene:
            return "Scene"
        case .format:
            return "Format"
        case .fileSize:
            return "File Size"
        }
    }
}

/// Search criteria
struct SearchCriteria {
    let criteria: [SearchCriterion]
    let operatorType: SearchOperator
    
    enum SearchOperator {
        case and
        case or
    }
}

/// Search criterion
struct SearchCriterion {
    let type: CriterionType
    let value: String
    
    enum CriterionType {
        case text
        case dateRange
        case fileSize
        case format
        case visualSimilarity
    }
}

/// Search history item
struct SearchHistoryItem: Codable, Identifiable {
    let id = UUID()
    let query: String
    let resultCount: Int
    let timestamp: Date
}

/// Similar image result - Canonical type for all similar image operations
/// Migration Note: This is the unified type used across SmartSearchService, SmartImageOrganizationService,
/// and AIImageAnalysisService to ensure consistency. Previously, AI.SimilarImageResult was used
/// but has been migrated to use this canonical definition.
struct SimilarImageResult: Identifiable {
    let id = UUID()
    let imageFile: ImageFile
    let similarity: Double
    let reasons: [String]
}
