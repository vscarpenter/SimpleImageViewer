import SwiftUI
import AppKit
import Foundation

/// Enhanced AI insights view with comprehensive analysis display
struct AIInsightsView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    @StateObject private var compatibilityService = MacOS26CompatibilityService.shared

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.accentColor)
                .font(.title2)

            Text("AI Insights")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            if viewModel.isAnalyzingAI {
                HStack(spacing: 8) {
                    if viewModel.aiAnalysisProgress > 0 {
                        ProgressView(value: viewModel.aiAnalysisProgress)
                            .frame(width: 80)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    Text("Analyzing…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Content States

    @ViewBuilder
    private var contentView: some View {
        if !compatibilityService.isFeatureAvailable(.aiImageAnalysis) {
            featureUnavailableView
        } else if !viewModel.isAIAnalysisEnabled {
            analysisDisabledView
        } else if let error = viewModel.analysisError {
            analysisErrorView(error)
        } else if let analysis = viewModel.currentAnalysis {
            ScrollView {
                EnhancedAIInsightContent(analysis: analysis, insights: viewModel.aiInsights, isCompact: false)
                    .padding()
            }
        } else if viewModel.isAnalyzingAI {
            analyzingView
        } else {
            noAnalysisView
        }
    }

    // MARK: - State Views

    private var featureUnavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("AI Features Not Available")
                .font(.title2)
                .fontWeight(.semibold)

            Text("AI-powered image analysis requires macOS 26 or later.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Learn More") {
                if let url = URL(string: "https://support.apple.com/macos") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var analysisDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("AI Analysis Disabled")
                .font(.headline)

            Text("Enable on-device AI analysis in Preferences to see automatic insights.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Text("Choose StillView ▸ Preferences ▸ General to toggle AI Analysis.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func analysisErrorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Group {
                if let aiError = error as? AIAnalysisError {
                    Image(systemName: aiError.isRetryable ? "exclamationmark.triangle" : "xmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(aiError.isRetryable ? .orange : .red)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                }
            }

            Text("Analysis Error")
                .font(.headline)

            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if let aiError = error as? AIAnalysisError,
               let recoverySuggestion = aiError.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            HStack(spacing: 12) {
                if let aiError = error as? AIAnalysisError, aiError.isRetryable {
                    Button("Try Again") {
                        viewModel.retryAIAnalysis()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Try Again") {
                        viewModel.retryAIAnalysis()
                    }
                    .buttonStyle(.bordered)
                }

                if let aiError = error as? AIAnalysisError {
                    switch aiError {
                    case .preferenceSyncFailed:
                        Button("Open Preferences") {
                            NotificationCenter.default.post(name: .openPreferences, object: nil)
                        }
                        .buttonStyle(.bordered)

                    case .featureNotAvailable:
                        Button("Learn More") {
                            if let url = URL(string: "https://support.apple.com/macos") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)

                    default:
                        EmptyView()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Analyzing image…")
                .font(.headline)

            Text("Performing comprehensive AI analysis including quality assessment, object detection, and scene understanding.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noAnalysisView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select an image to see AI insights")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Enhanced AI Insight Content

struct EnhancedAIInsightContent: View {
    let analysis: ImageAnalysisResult
    let insights: [AIInsight]
    let isCompact: Bool

    private var titleFont: Font { isCompact ? .headline : .title3 }
    private var bodyFont: Font { isCompact ? .body : .body }
    private var detailFont: Font { isCompact ? .subheadline : .callout }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 16 : 20) {
            // Image Caption - New Feature
            if let caption = analysis.caption {
                captionSection(caption)
            }

            // Intelligent Narrative (Priority 3)
            narrativeSection

            if analysis.primarySubject != nil || !analysis.recognizedPeople.isEmpty || !analysis.rankedSubjects.isEmpty {
                subjectSection
            }

            // Quality Assessment (Priority 1)
            qualitySection

            // Saliency & Composition (Priority 2)
            if let saliency = analysis.saliencyAnalysis, !saliency.attentionPoints.isEmpty {
                saliencySection(saliency)
            }

            // Actionable Insights
            if !insights.isEmpty {
                insightsSection
            }

            // Smart Tags
            if !analysis.smartTags.isEmpty {
                smartTagsSection
            }

            // Additional Details
            additionalDetailsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Caption Section

    private func captionSection(_ caption: ImageCaption) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack {
                Image(systemName: "captions.bubble")
                    .foregroundColor(.accentColor)
                Text("Image Caption")
                    .font(titleFont)
                    .fontWeight(.semibold)
                Spacer()
                if caption.confidence > 0 {
                    Text(String(format: "%.0f%% confidence", caption.confidence * 100))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                // Main caption
                VStack(alignment: .leading, spacing: 6) {
                    Text(caption.detailedCaption)
                        .font(bodyFont)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Technical caption if available
                if let technicalCaption = caption.technicalCaption {
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "camera")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(technicalCaption)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                // Accessibility caption
                if !isCompact {
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "person.badge.key")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accessibility")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text(caption.accessibilityCaption)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
            .padding(isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
    }

    // MARK: - Narrative Section (Priority 3)

    private var narrativeSection: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.accentColor)
                Text("Description")
                    .font(titleFont)
                    .fontWeight(.semibold)
            }
            
            Text(analysis.narrativeSummary)
                .font(bodyFont)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(isCompact ? 12 : 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
        }
    }
    
    // MARK: - Subject Section
    
    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack {
                Image(systemName: "person.text.rectangle")
                    .foregroundColor(.accentColor)
                Text("Subjects")
                    .font(titleFont)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Show recognized people first if available
                if !analysis.recognizedPeople.isEmpty {
                    ForEach(Array(analysis.recognizedPeople.prefix(2)), id: \.name) { person in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(detailFont)
                                    .fontWeight(.semibold)
                                Text(person.source == .text ? "Derived from visible text" : "Classified on-device")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", person.confidence * 100))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(confidenceColor(person.confidence))
                        }
                    }
                }

                // Show ranked subjects (objects + classifications, intelligently sorted)
                let rankedSubjects = analysis.rankedSubjects
                if !rankedSubjects.isEmpty {
                    ForEach(Array(rankedSubjects.prefix(3).enumerated()), id: \.element.label) { index, subject in
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: subjectIcon(for: subject))
                                .foregroundColor(subject.source == .detectedObject ? .accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subject.label)
                                    .font(detailFont)
                                    .fontWeight(index == 0 ? .semibold : .regular)
                                Text(subjectDescription(for: subject))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", subject.confidence * 100))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(confidenceColor(subject.confidence))
                        }
                    }
                } else {
                    Text("No subjects detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
    }
    
    // MARK: - Quality Section (Priority 1)
    
    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack {
                Image(systemName: qualityIcon)
                    .foregroundColor(qualityColor)
                Text("Image Quality")
                    .font(titleFont)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(analysis.qualityAssessment.summary)
                    .font(detailFont)
                    .foregroundColor(.primary)
                
                // Quality Metrics
                VStack(alignment: .leading, spacing: 6) {
                    MetricRow(
                        label: "Resolution",
                        value: "\(String(format: "%.1f", analysis.qualityAssessment.metrics.megapixels))MP",
                        icon: "photo"
                    )
                    MetricRow(
                        label: "Sharpness",
                        value: String(format: "%.0f%%", analysis.qualityAssessment.metrics.sharpness * 100),
                        icon: "scope"
                    )
                    MetricRow(
                        label: "Exposure",
                        value: exposureLabel,
                        icon: "sun.max"
                    )
                }
                .font(.caption)
                
                // Quality Issues
                if !analysis.qualityAssessment.issues.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(analysis.qualityAssessment.issues, id: \.title) { issue in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: issueIcon(for: issue.kind))
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(issue.detail)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
    }
    
    private var qualityIcon: String {
        switch analysis.quality {
        case .high: return "checkmark.seal.fill"
        case .medium: return "checkmark.circle"
        case .low: return "exclamationmark.triangle"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var qualityColor: Color {
        switch analysis.quality {
        case .high: return .green
        case .medium: return .blue
        case .low: return .orange
        case .unknown: return .gray
        }
    }
    
    private var exposureLabel: String {
        let exposure = analysis.qualityAssessment.metrics.exposure
        if exposure < 0.3 {
            return "Dark"
        } else if exposure > 0.7 {
            return "Bright"
        } else {
            return "Balanced"
        }
    }
    
    private func issueIcon(for kind: ImageQualityAssessment.Issue.Kind) -> String {
        switch kind {
        case .lowResolution: return "arrow.down.to.line"
        case .softFocus: return "eye.slash"
        case .underexposed: return "moon"
        case .overexposed: return "sun.max.fill"
        }
    }
    
    // MARK: - Saliency Section (Priority 2)
    
    private func saliencySection(_ saliency: SaliencyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack {
                Image(systemName: "viewfinder")
                    .foregroundColor(.accentColor)
                Text("Composition")
                    .font(titleFont)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Balance Score:")
                        .font(detailFont)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", saliency.visualBalance.score * 100))
                        .font(detailFont)
                        .fontWeight(.semibold)
                        .foregroundColor(balanceColor(saliency.visualBalance.score))
                }
                
                Text(saliency.visualBalance.feedback)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                if !saliency.visualBalance.suggestions.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(saliency.visualBalance.suggestions, id: \.self) { suggestion in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
    }
    
    private func balanceColor(_ score: Double) -> Color {
        if score > 0.7 {
            return .green
        } else if score > 0.4 {
            return .blue
        } else {
            return .orange
        }
    }

    private func confidenceColor(_ value: Double) -> Color {
        if value >= 0.75 {
            return .green
        } else if value >= 0.5 {
            return .blue
        } else {
            return .orange
        }
    }

    private func subjectIcon(for subject: SubjectItem) -> String {
        if subject.source == .detectedObject {
            let label = subject.label.lowercased()
            if label.contains("person") || label.contains("human") || label.contains("face") {
                return "person.fill"
            } else if label.contains("car") || label.contains("vehicle") {
                return "car.fill"
            } else if label.contains("dog") || label.contains("cat") || label.contains("animal") {
                return "pawprint.fill"
            } else {
                return "scope"
            }
        } else {
            return "photo"
        }
    }

    private func subjectDescription(for subject: SubjectItem) -> String {
        if subject.source == .detectedObject {
            return "Detected on-device"
        } else {
            return "Classified on-device"
        }
    }

    // MARK: - Insights Section
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Suggestions")
                    .font(titleFont)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(insights) { insight in
                    InsightCard(insight: insight, isCompact: isCompact)
                }
            }
        }
    }
    
    // MARK: - Smart Tags Section
    
    private var smartTagsSection: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.accentColor)
                Text("Smart Tags")
                    .font(titleFont)
                    .fontWeight(.semibold)
            }
            
            FlowLayout(spacing: 6) {
                ForEach(analysis.smartTags.prefix(10), id: \.name) { tag in
                    TagView(tag: tag)
                }
            }
        }
    }
    
    // MARK: - Additional Details Section
    
    private var additionalDetailsSection: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.accentColor)
                Text("Details")
                    .font(titleFont)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if !analysis.objects.isEmpty {
                    DetailRow(
                        label: "Detected Objects",
                        value: "\(analysis.objects.count)",
                        icon: "cube.box"
                    )
                }
                
                if !analysis.text.isEmpty {
                    DetailRow(
                        label: "Text Elements",
                        value: "\(analysis.text.count)",
                        icon: "text.alignleft"
                    )
                }
                
                if !analysis.colors.isEmpty {
                    DetailRow(
                        label: "Dominant Colors",
                        value: "\(analysis.colors.count)",
                        icon: "paintpalette"
                    )
                }
                
                if !analysis.barcodes.isEmpty {
                    DetailRow(
                        label: "Barcodes/QR Codes",
                        value: "\(analysis.barcodes.count)",
                        icon: "qrcode"
                    )
                }
                
                if let horizon = analysis.horizon {
                    DetailRow(
                        label: "Horizon",
                        value: horizon.isLevel ? "Level" : "Tilted \(String(format: "%.1f°", horizon.angle * 180 / .pi))",
                        icon: "level"
                    )
                }
            }
            .font(.caption)
            .padding(isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
    }
}

// MARK: - Supporting Views

struct MetricRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct InsightCard: View {
    let insight: AIInsight
    let isCompact: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: insightIcon)
                    .foregroundColor(insightColor)
                Text(insight.title)
                    .font(isCompact ? .caption : .subheadline)
                    .fontWeight(.semibold)
            }
            
            Text(insight.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let action = insight.action, action != .none {
                HStack {
                    Spacer()
                    Text(actionText)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(isCompact ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
    }
    
    private var actionText: String {
        guard let action = insight.action else { return "" }
        switch action {
        case .crop:
            return "View Crop Suggestions"
        case .enhance:
            return "Enhance Quality"
        case .tag:
            return "Tag People"
        case .export:
            return "Export Image"
        case .share:
            return "Share"
        case .copy:
            return "Copy"
        case .navigate:
            return "Navigate"
        case .search:
            return "Search Similar"
        case .addToCollection:
            return "Add to Collection"
        case .viewMetadata:
            return "View Metadata"
        case .none:
            return ""
        }
    }
    
    private var insightIcon: String {
        switch insight.type {
        case .compositional:
            return "viewfinder.circle"
        case .quality:
            return "wand.and.stars"
        case .content:
            return "lightbulb"
        case .technical:
            return "info.circle"
        case .accessibility:
            return "accessibility"
        case .organization:
            return "folder"
        case .enhancement:
            return "wand.and.rays"
        case .context:
            return "location.circle"
        case .privacy:
            return "lock.shield"
        case .discovery:
            return "sparkles"
       case .action:
            return "bolt.circle"
        }
    }
    
    private var insightColor: Color {
        switch insight.type {
        case .quality:
            return .orange
        case .compositional:
            return .blue
        case .content:
            return .purple
        case .technical:
            return .gray
        case .accessibility:
            return .green
        case .organization:
            return .indigo
        case .enhancement:
            return .pink
        case .context:
            return .teal
        case .privacy:
            return .red
        case .discovery:
            return .yellow
        case .action:
            return .cyan
        }
    }
}

struct TagView: View {
    let tag: SmartTag
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: categoryIcon)
                .font(.caption2)
            Text(tag.name)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(categoryColor.opacity(0.2))
        )
        .foregroundColor(categoryColor)
    }
    
    private var categoryIcon: String {
        switch tag.category {
        case .content: return "photo"
        case .location: return "location"
        case .people: return "person"
        case .quality: return "star"
        case .style: return "paintbrush"
        case .event: return "calendar"
        case .time: return "clock"
        case .useCase: return "lightbulb"
        }
    }
    
    private var categoryColor: Color {
        switch tag.category {
        case .content: return .blue
        case .location: return .green
        case .people: return .purple
        case .quality: return .orange
        case .style: return .pink
        case .event: return .red
        case .time: return .cyan
        case .useCase: return .yellow
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#if DEBUG
struct AIInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        AIInsightsView(viewModel: ImageViewerViewModel())
            .frame(width: 360)
    }
}
#endif
