import SwiftUI
import AppKit
import Foundation

/// Simplified AI insights view presenting a short narrative for the current image
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
                AIInsightSummaryContent(analysis: analysis, isCompact: false)
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

            Text("Hang tight while we generate a short description for this image.")
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

// MARK: - Shared Summary View

struct AIInsightSummaryContent: View {
    let analysis: ImageAnalysisResult
    let isCompact: Bool

    private var titleFont: Font { isCompact ? .headline : .title3 }
    private var bodyFont: Font { isCompact ? .body : .body }
    private var detailFont: Font { isCompact ? .subheadline : .callout }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
            VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
                Text("Summary")
                    .font(titleFont)
                    .fontWeight(.semibold)

                Text(analysis.narrativeSummary)
                    .font(bodyFont)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isCompact ? 0.9 : 1.0))
            )

            if !analysis.summaryHighlights.isEmpty {
                VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
                    Text("Details")
                        .font(detailFont)
                        .fontWeight(.semibold)

                    ForEach(analysis.summaryHighlights, id: \.self) { highlight in
                        Text("• \(highlight)")
                            .font(detailFont)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
