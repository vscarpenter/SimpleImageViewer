import SwiftUI
import AppKit
import Combine

/// Advanced AI insights view showcasing intelligent image analysis
struct AIInsightsView: View {
    @StateObject private var aiAnalysisService = AIImageAnalysisService.shared
    @StateObject private var smartOrganizationService = SmartImageOrganizationService.shared
    @StateObject private var compatibilityService = MacOS26CompatibilityService.shared
    
    @ObservedObject var viewModel: ImageViewerViewModel
    @State private var analysisResult: ImageAnalysisResult?
    @State private var isAnalyzing = false
    @State private var analysisProgress: Double = 0.0
    @State private var selectedTab: AIInsightTab = .overview
    @State private var searchQuery = ""
    @State private var searchSuggestions: [SearchSuggestion] = []
    @State private var similarImages: [SimilarImageResult] = []
    @State private var smartCategories: [SmartCategory] = []
    @State private var showingSimilarImages = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            if compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
                contentView
            } else {
                featureUnavailableView
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            analyzeCurrentImage()
        }
        .onChange(of: viewModel.currentImageFile) { _ in
            analyzeCurrentImage()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.accentColor)
                .font(.title2)
            
            Text("AI Insights")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            if isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // Tab picker
            tabPicker
            
            // Tab content
            TabView(selection: $selectedTab) {
                overviewTab
                    .tag(AIInsightTab.overview)
                
                analysisTab
                    .tag(AIInsightTab.analysis)
                
                searchTab
                    .tag(AIInsightTab.search)
                
                organizationTab
                    .tag(AIInsightTab.organization)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
    
    @ViewBuilder
    private var featureUnavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("AI Features Not Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("AI-powered image analysis requires macOS 26 or later")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Learn More") {
                // Show information about AI features
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    @ViewBuilder
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AIInsightTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.title)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedTab == tab ? .accentColor : .primary)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let analysis = analysisResult {
                    // Quick insights
                    quickInsightsSection(analysis)
                    
                    // Image quality
                    imageQualitySection(analysis)
                    
                    // Dominant colors
                    dominantColorsSection(analysis)
                    
                    // Enhancement suggestions
                    enhancementSuggestionsSection(analysis)
                } else if isAnalyzing {
                    analyzingView
                } else {
                    noAnalysisView
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var analysisTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let analysis = analysisResult {
                    // Classifications
                    classificationsSection(analysis)
                    
                    // Detected objects
                    objectsSection(analysis)
                    
                    // Scenes
                    scenesSection(analysis)
                    
                    // Text recognition
                    textSection(analysis)
                } else if isAnalyzing {
                    analyzingView
                } else {
                    noAnalysisView
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var searchTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search bar
            searchBar
            
            // Search suggestions
            if !searchSuggestions.isEmpty {
                searchSuggestionsSection
            }
            
            // Similar images
            if !similarImages.isEmpty {
                similarImagesSection
            }
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private var organizationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Smart categories
                smartCategoriesSection
                
                // Smart collections
                smartCollectionsSection
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Section Views
    
    @ViewBuilder
    private func quickInsightsSection(_ analysis: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InsightCard(
                    title: "Primary Content",
                    value: analysis.classifications.first?.identifier ?? "Unknown",
                    confidence: analysis.classifications.first?.confidence ?? 0.0,
                    icon: "photo"
                )
                
                InsightCard(
                    title: "Image Quality",
                    value: analysis.quality.displayName,
                    confidence: 1.0,
                    icon: "star.fill"
                )
                
                InsightCard(
                    title: "Objects Detected",
                    value: "\(analysis.objects.count)",
                    confidence: 1.0,
                    icon: "rectangle.3.group"
                )
                
                InsightCard(
                    title: "Text Found",
                    value: analysis.text.isEmpty ? "None" : "\(analysis.text.count) items",
                    confidence: 1.0,
                    icon: "text.bubble"
                )
            }
        }
    }
    
    @ViewBuilder
    private func imageQualitySection(_ analysis: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Quality")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: analysis.quality.icon)
                    .foregroundColor(analysis.quality.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.quality.displayName)
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text(analysis.quality.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(analysis.quality.color.opacity(0.1))
            )
        }
    }
    
    @ViewBuilder
    private func dominantColorsSection(_ analysis: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dominant Colors")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 8) {
                ForEach(Array(analysis.colors.enumerated()), id: \.offset) { index, color in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color(color.color))
                            .frame(width: 32, height: 32)
                        
                        Text("\(Int(color.percentage * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func enhancementSuggestionsSection(_ analysis: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enhancement Suggestions")
                .font(.headline)
                .fontWeight(.semibold)
            
            if analysis.suggestions.isEmpty {
                Text("No suggestions available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(analysis.suggestions.enumerated()), id: \.offset) { index, suggestion in
                    EnhancementSuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
    
    @ViewBuilder
    private func classificationsSection(_ analysis: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Classifications")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(Array(analysis.classifications.enumerated()), id: \.offset) { index, classification in
                ClassificationRow(classification: classification)
            }
        }
    }
    
    @ViewBuilder
    private func objectsSection(_ analysis: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Objects")
                .font(.headline)
                .fontWeight(.semibold)
            
            if analysis.objects.isEmpty {
                Text("No objects detected")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(analysis.objects.enumerated()), id: \.offset) { index, object in
                    ObjectRow(object: object)
                }
            }
        }
    }
    
    @ViewBuilder
    private func scenesSection(_ analysis: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scene Classification")
                .font(.headline)
                .fontWeight(.semibold)
            
            if analysis.scenes.isEmpty {
                Text("No scene information available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(analysis.scenes.enumerated()), id: \.offset) { index, scene in
                    SceneRow(scene: scene)
                }
            }
        }
    }
    
    @ViewBuilder
    private func textSection(_ analysis: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recognized Text")
                .font(.headline)
                .fontWeight(.semibold)
            
            if analysis.text.isEmpty {
                Text("No text detected")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(analysis.text.enumerated()), id: \.offset) { index, text in
                    TextRow(text: text)
                }
            }
        }
    }
    
    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search images...", text: $searchQuery)
                .textFieldStyle(.plain)
                .onSubmit {
                    performSearch()
                }
            
            if !searchQuery.isEmpty {
                Button("Clear") {
                    searchQuery = ""
                    searchSuggestions = []
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    @ViewBuilder
    private var searchSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggestions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(searchSuggestions, id: \.text) { suggestion in
                    Button(action: {
                        searchQuery = suggestion.text
                        performSearch()
                    }) {
                        HStack {
                            Text(suggestion.text)
                                .font(.body)
                            Spacer()
                            Text("\(Int(suggestion.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    private var similarImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Similar Images")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Show All") {
                    showingSimilarImages = true
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(similarImages.prefix(5), id: \.imageFile.id) { similarImage in
                        SimilarImageCard(similarImage: similarImage)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var smartCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Categories")
                .font(.headline)
                .fontWeight(.semibold)
            
            if smartCategories.isEmpty {
                Text("No categories available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(smartCategories) { category in
                        CategoryCard(category: category)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var smartCollectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Collections")
                .font(.headline)
                .fontWeight(.semibold)
            
            if smartOrganizationService.smartCollections.isEmpty {
                Text("No collections available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(smartOrganizationService.smartCollections) { collection in
                    CollectionCard(collection: collection)
                }
            }
        }
    }
    
    @ViewBuilder
    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing image...")
                .font(.headline)
            
            if analysisProgress > 0 {
                ProgressView(value: analysisProgress)
                    .frame(width: 200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var noAnalysisView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Analysis Available")
                .font(.headline)
            
            Text("Select an image to see AI insights")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func analyzeCurrentImage() {
        guard let imageFile = viewModel.currentImageFile,
              let image = viewModel.currentImage else {
            analysisResult = nil
            return
        }
        
        Task {
            do {
                isAnalyzing = true
                let result = try await aiAnalysisService.analyzeImage(image, url: imageFile.url)
                
                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        Task {
            do {
                let suggestions = try await smartOrganizationService.generateSearchSuggestions(
                    for: searchQuery,
                    in: viewModel.allImageFiles
                )
                
                await MainActor.run {
                    searchSuggestions = suggestions
                }
            } catch {
                // Handle error
            }
        }
    }
}

// MARK: - Supporting Views

struct InsightCard: View {
    let title: String
    let value: String
    let confidence: Float
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Spacer()
                Text("\(Int(confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct EnhancementSuggestionCard: View {
    let suggestion: EnhancementSuggestion
    
    var body: some View {
        HStack {
            Image(systemName: suggestion.type.icon)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.description)
                    .font(.body)
                
                Text("\(Int(suggestion.confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.1))
        )
    }
}

struct ClassificationRow: View {
    let classification: ClassificationResult
    
    var body: some View {
        HStack {
            Text(classification.identifier)
                .font(.body)
            
            Spacer()
            
            Text("\(Int(classification.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ObjectRow: View {
    let object: DetectedObject
    
    var body: some View {
        HStack {
            Image(systemName: "rectangle.3.group")
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(object.identifier)
                    .font(.body)
                
                Text(object.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int(object.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SceneRow: View {
    let scene: SceneClassification
    
    var body: some View {
        HStack {
            Text(scene.identifier)
                .font(.body)
            
            Spacer()
            
            Text("\(Int(scene.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct TextRow: View {
    let text: RecognizedText
    
    var body: some View {
        HStack {
            Image(systemName: "text.bubble")
                .foregroundColor(.accentColor)
            
            Text(text.text)
                .font(.body)
            
            Spacer()
            
            Text("\(Int(text.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SimilarImageCard: View {
    let similarImage: SimilarImageResult
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail would go here
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                )
            
            Text(similarImage.imageFile.displayName)
                .font(.caption)
                .lineLimit(2)
            
            Text("\(Int(similarImage.similarity * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 100)
    }
}

struct CategoryCard: View {
    let category: SmartCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(Color(category.color))
                
                Spacer()
                
                Text("\(category.imageCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(category.name)
                .font(.headline)
                .fontWeight(.medium)
            
            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(category.color).opacity(0.1))
        )
    }
}

struct CollectionCard: View {
    let collection: SmartCollection
    
    var body: some View {
        HStack {
            Image(systemName: collection.type.icon)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(collection.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(collection.imageCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - Supporting Types

enum AIInsightTab: String, CaseIterable {
    case overview = "overview"
    case analysis = "analysis"
    case search = "search"
    case organization = "organization"
    
    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .analysis:
            return "Analysis"
        case .search:
            return "Search"
        case .organization:
            return "Organization"
        }
    }
    
    var icon: String {
        switch self {
        case .overview:
            return "chart.bar.fill"
        case .analysis:
            return "magnifyingglass"
        case .search:
            return "magnifyingglass.circle.fill"
        case .organization:
            return "folder.fill"
        }
    }
}

extension ImageQuality {
    var displayName: String {
        switch self {
        case .low:
            return "Low Quality"
        case .medium:
            return "Medium Quality"
        case .high:
            return "High Quality"
        case .unknown:
            return "Unknown Quality"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "This image has low resolution or quality"
        case .medium:
            return "This image has moderate quality"
        case .high:
            return "This image has high quality and resolution"
        case .unknown:
            return "Quality assessment not available"
        }
    }
    
    var icon: String {
        switch self {
        case .low:
            return "exclamationmark.triangle.fill"
        case .medium:
            return "checkmark.circle.fill"
        case .high:
            return "star.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    var color: NSColor {
        switch self {
        case .low:
            return .systemRed
        case .medium:
            return .systemYellow
        case .high:
            return .systemGreen
        case .unknown:
            return .systemGray
        }
    }
}

extension EnhancementType {
    var icon: String {
        switch self {
        case .brightness:
            return "sun.max.fill"
        case .contrast:
            return "circle.lefthalf.filled"
        case .saturation:
            return "paintpalette.fill"
        case .sharpness:
            return "wand.and.rays"
        case .noiseReduction:
            return "sparkles"
        }
    }
}

extension CollectionType {
    var icon: String {
        switch self {
        case .timeBased:
            return "clock.fill"
        case .contentBased:
            return "photo.fill"
        case .similarityBased:
            return "square.stack.3d.up.fill"
        case .manual:
            return "folder.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    AIInsightsView(viewModel: ImageViewerViewModel())
        .frame(width: 400, height: 600)
}
