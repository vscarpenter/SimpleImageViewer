# AI Feature Implementation Tasks

## Model & Pipeline Setup
- [x] Select on-device Core ML models for image classification and OCR; document licensing and expected footprint. (Uses Apple’s built-in Vision models; documented in `Documentation/AIInsights.md`.)
- [x] Bundle models into the app target (Assets or Resources) and hook them up in `AIImageAnalysisService` loaders, replacing current stubs. (Service now loads bundled models when present and falls back to system-provided Vision classifiers.)
- [x] Implement preprocess/postprocess helpers (resizing, normalization, result filtering) and feed outputs into `analysisCache` for reuse.
- [x] Add graceful fallbacks when models are missing or the OS blocks loading; surface status via `macOS26CompatibilityService`.

## Viewer & Workflow Integration
- [x] Trigger background analysis when `ImageViewerViewModel` loads an image; expose published properties for tags, objects, and errors.
- [x] Update `EnhancedImageDisplayView` overlays to render real AI insights, progress, and actionable suggestions.
- [x] Expand smart search/organization services to index AI-derived metadata and improve filtering.

## Preferences & Consent
- [x] Add a Preferences toggle for AI analysis with explanatory copy and default opt-in decision.
- [x] Persist user consent (`PreferencesService`) and gate analysis accordingly.
- [x] Present a first-run dialog summarizing local processing, privacy impact, and opt-out path.

## Privacy & Compliance
- [x] Update `PrivacyInfo.xcprivacy` with Vision/Core ML reason codes and any biometric usage rationale.
- [x] Review entitlements to ensure AI storage respects sandbox rules (e.g., security-scoped bookmarks, cache location).

## Performance & Monitoring
- [ ] Benchmark model load times and analysis latency on macOS 26 hardware; record budgets. *(Instrumentation is in place; capture baseline numbers next pass.)*
- [x] Feed key metrics (latency, memory, cache hits) into `PerformanceOptimizationService` logging for ongoing monitoring.

## Testing & QA
- [x] Create unit tests that exercise feature gating, result parsing, and cache behavior with sample model outputs. *(See new `PreferencesServiceTests` and `ImageViewerViewModelTests` cases.)*
- [ ] Add integration/UI tests that verify overlays appear, fallbacks trigger, and search indices populate. *(Pending richer UI automation.)*
- [x] Produce manual QA script covering consent flow, accessibility narration, and performance smoke tests.

## Documentation & Release Prep
- [x] Update in-app Help and `Documentation/` guides with AI feature overview, privacy notes, and troubleshooting.
- [ ] Capture screenshots/GIFs for the PR and marketing assets showcasing AI insights.
- [ ] Prepare release notes highlighting macOS 26 AI capabilities and required minimum OS.
