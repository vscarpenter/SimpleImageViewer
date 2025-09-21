# AI Feature Implementation Tasks

## Model & Pipeline Setup
- [ ] Select on-device Core ML models for image classification and OCR; document licensing and expected footprint.
- [ ] Bundle models into the app target (Assets or Resources) and hook them up in `AIImageAnalysisService` loaders, replacing current stubs.
- [ ] Implement preprocess/postprocess helpers (resizing, normalization, result filtering) and feed outputs into `analysisCache` for reuse.
- [ ] Add graceful fallbacks when models are missing or the OS blocks loading; surface status via `macOS26CompatibilityService`.

## Viewer & Workflow Integration
- [ ] Trigger background analysis when `ImageViewerViewModel` loads an image; expose published properties for tags, objects, and errors.
- [ ] Update `EnhancedImageDisplayView` overlays to render real AI insights, progress, and actionable suggestions.
- [ ] Expand smart search/organization services to index AI-derived metadata and improve filtering.

## Preferences & Consent
- [ ] Add a Preferences toggle for AI analysis with explanatory copy and default opt-in/off decision.
- [ ] Persist user consent (`PreferencesService`) and gate analysis accordingly.
- [ ] Present a first-run dialog summarizing local processing, privacy impact, and opt-out path.

## Privacy & Compliance
- [ ] Update `PrivacyInfo.xcprivacy` with Vision/Core ML reason codes and any biometric usage rationale.
- [ ] Review entitlements to ensure AI storage respects sandbox rules (e.g., security-scoped bookmarks, cache location).

## Performance & Monitoring
- [ ] Benchmark model load times and analysis latency on macOS 26 hardware; record budgets.
- [ ] Feed key metrics (latency, memory, cache hits) into `PerformanceOptimizationService` logging for ongoing monitoring.

## Testing & QA
- [ ] Create unit tests that exercise feature gating, result parsing, and cache behavior with sample model outputs.
- [ ] Add integration/UI tests that verify overlays appear, fallbacks trigger, and search indices populate.
- [ ] Produce manual QA script covering consent flow, accessibility narration, and performance smoke tests.

## Documentation & Release Prep
- [ ] Update in-app Help and `Documentation/` guides with AI feature overview, privacy notes, and troubleshooting.
- [ ] Capture screenshots/GIFs for the PR and marketing assets showcasing AI insights.
- [ ] Prepare release notes highlighting macOS 26 AI capabilities and required minimum OS.
