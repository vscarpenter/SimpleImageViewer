# AI Insights Overview

StillView ships with an opt-in, on-device AI pipeline that enriches the viewing experience without ever leaving the user’s Mac. This document summarises the moving pieces introduced for macOS 26.

## Feature Summary
- **AIImageAnalysisService** orchestrates Vision/Core ML requests (classification, object detection, scene labelling, OCR) on a background queue. Results are cached and surfaced through `ImageViewerViewModel` so that UI consumers share one analysis.
- **EnhancedImageDisplayView** exposes live progress and quick facts (top tags, error state, disabled state) directly in the overlay.
- **AIInsightsView** now binds to the view model rather than triggering its own analyses. It shows a richer overview, tabbed deep dives, suggested search chips, smart organisation, and hydrated similar-image rails.
- **PerformanceIntegration**: latency, cache hit-rate and memory footprint are published into `PerformanceOptimizationService` for ongoing tuning.

## User Consent & Preferences
- **First-run Prompt**: `AIConsentManager` ensures a single consent dialog is shown (macOS 26 only). Users can enable insights or decline; the choice persists in `DefaultPreferencesService.enableAIAnalysis`.
- **Preferences Toggle**: “Enable AI analysis” lives in **Preferences ▸ General** with inline help. Toggling publishes `Notification.Name.aiAnalysisPreferenceDidChange`, allowing running view models to update immediately.
- **Gating Behaviour**: When the toggle is disabled or the device does not support macOS 26 features, the analysis pipeline cancels outstanding work, clears cached insights, and the UI communicates the disabled state.

## Privacy Notes
- All processing is performed locally using shipped Vision/Core ML frameworks—no network or telemetry calls are made.
- `PrivacyInfo.xcprivacy` documents the fact that user-selected photos are analysed purely for app functionality and never collected or tracked.
- Error surfaces clarify when analysis fails and provide an immediate retry path.

## Smart Search & Organisation
- `SmartSearchService` now incorporates AI-derived classifications, objects, scenes, and extracted text when proposing queries.
- `AIInsightsView` exposes analysis tags as quick-launch search chips.
- `SmartImageOrganizationService` consumes the shared cache, reducing redundant analysis when building collections or finding similar items.

## Testing Touchpoints
- `PreferencesServiceTests` verifies the default and persistence of the new preference.
- `ImageViewerViewModelTests` assert that preference-change notifications immediately update view-model state.
- `AIImageAnalysisService` caching/performance is covered indirectly through new metrics logging; manual QA ensures accuracy of Vision results on reference assets.

## Manual QA Checklist
1. Launch on macOS 26 with a fresh profile ➝ confirm consent dialog wording, buttons, and subsequent behaviour.
2. Accept consent, open a folder ➝ verify overlay progress, quick facts, AI Insights side panel population, and search chips.
3. Disable AI analysis in Preferences ➝ ensure overlays report the disabled state and that no further Vision work is triggered.
4. Re-enable ➝ confirm the current image is re-analysed and insights return.
5. Trigger analysis errors (e.g., corrupt file) ➝ observe user-facing messaging and retry behaviour.

These guardrails keep the experience private, transparent, and responsive while unlocking macOS 26 AI capabilities.
