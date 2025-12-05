import SwiftUI
import AppKit
import Foundation

/// Compact AI insights inspector that presents enhanced analysis in a compact format
struct AIInsightsInspectorView: View {
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

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.accentColor)
                .font(.headline)

            Text("AI Insights")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Button(action: {
                viewModel.toggleAIInsights()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close AI Insights")
            .accessibilityLabel("Close AI Insights panel")
        }
        .padding()
        .background(.regularMaterial)
    }

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
                EnhancedAIInsightContent(analysis: analysis, insights: viewModel.aiInsights, isCompact: true)
                    .padding()
            }
        } else if viewModel.isAnalyzingAI {
            analyzingView
        } else {
            noAnalysisView
        }
    }

    // MARK: - State Views (Compact variants)

    private var featureUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile.slash")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("AI features require macOS 26 or later.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var analysisDisabledView: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.slash")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Enable AI analysis in Preferences to see insights.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func analysisErrorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                viewModel.retryAIAnalysis()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var analyzingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Analyzing image…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var noAnalysisView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Select an image to see AI insights.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#if DEBUG
struct AIInsightsInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        AIInsightsInspectorView(viewModel: ImageViewerViewModel())
            .frame(width: 280)
    }
}
#endif
