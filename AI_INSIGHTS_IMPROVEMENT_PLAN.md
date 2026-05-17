# AI Insights v12 — macOS 26 + Apple Intelligence Only

A comprehensive plan to close out the AI Insights rewrite, eliminate every trace of the
legacy AI pipeline, hard-cut the deployment floor to macOS 26, and verify/refine the
quality of insights produced by the new Apple Intelligence + Vision implementation.

---

## Executive Summary

The v11 rewrite (committed 2026-05-16) has already replaced ~11,500 LOC of custom
captioning, Core ML, and heuristic-scoring code with six focused files that delegate to
Apple's Foundation Models framework. **The rewrite is structurally complete.** What
remains is finishing what the rewrite started:

1. **Commit the legacy deletions** sitting unstaged in the working tree.
2. **Hard-cut to macOS 26** at every build setting and `@available` check.
3. **Collapse `MacOS26CompatibilityService`**, which is ~95% dead under the new floor.
4. **Audit the modified non-AI files** for stale references and dead branches.
5. **Verify v12 output quality on real images** — without sampling, "improve quality" is
   guesswork.
6. **Enhance Vision perception or the prompt** based on Phase 4 findings AND a verified
   read of what the macOS 26 SDK actually exposes.
7. **Restore test coverage** for the v12 surface (the legacy test files were deleted
   without replacements).

This plan **does not propose multimodal image input to `LanguageModelSession`**. The
macOS 26.4 SDK reference (verified 2026-04-06, see
`reference_foundation_models_api.md`) describes text-only `respond(to:generating:)` with
`@Generable` payloads — that is the current and latest verified pattern. The Vision → FM
hybrid is the correct architecture. Phase 5 includes an explicit SDK research step
before enhancing.

The legacy plan's "ResNet50 + Vision classifications don't work together" problem is
**already solved** by removing ResNet50, the captioning pipeline, the scoring system,
and the classification merger entirely.

---

## Architectural Anchors (Do Not Violate)

These are guardrails for every phase. If a change breaks one of these, stop and reconsider.

- **Six AI Insight files. No more.** `ImagePerceptionService`,
  `AppleIntelligenceInsightsService`, `ImageInsightCore` (all types + protocol +
  prompt builder), `ImageInsightViewModel`, `ImageInsightPanelView`, and
  `ImageInsightTests`. Resist the urge to extract.
- **On device only.** No network, no analytics, no telemetry, no bundled Core ML
  models. The privacy test in `ImageInsightTests` (currently missing — see Phase 6)
  must fail the build if `URLSession`, `http(s)://`, `telemetry`, or `analytics`
  appears in any of the four insight source files.
- **Apple Intelligence is a hard floor for generation.** `ImagePerceptionService` may
  run on any macOS 26 build, but insight *generation* requires
  `SystemLanguageModel.default.availability == .available`.
- **Camera/EXIF/GPS is context only.** Never the title, never the subject. The
  forbidden-title example ("iPhone 13 Pro Max Capture") must stay in the prompt.
- **Vision signals are PRIMARY EVIDENCE. Embedded metadata is SECONDARY. Camera is
  CONTEXT ONLY.** This three-bucket ranking must remain explicit in the prompt.
- **Perception runs lazily inside `generateInsight`** — never on every image
  navigation. Cancellation on image change or panel close is non-negotiable.

---

## Phase 0 — Baseline Lock (1 commit, ~30 min)

You cannot cleanly refactor against a working tree with 60+ uncommitted deletions.
Lock the baseline first.

### 0.1 Verify the working tree builds
- Open `StillView - Simple Image Viewer.xcodeproj` in Xcode and build (⌘+B).
- If the build fails because deleted files are still referenced in `project.pbxproj`,
  remove those references (this is the most likely failure mode).

### 0.2 Commit the legacy removal as a single coherent change
Stage in two logical groups, then commit as **one** commit titled
`refactor(ai): remove legacy AI pipeline; AI Insights is Apple Intelligence only`:

- **Group A — Source deletions** (~30 files): all of `Services/AIAnalysis/*`,
  `AIBrain.swift`, `AIConsentManager.swift`, `AIImageAnalysisService.swift`,
  `EnhancedVisionAnalyzer.swift`, `CoreMLModelManager.swift`,
  `SmartImageOrganizationService.swift`, `SmartSearchService.swift`,
  `ImageCaptioningProvider.swift`, `NarrativeGenerator.swift`,
  `QualityAssessmentService.swift`, `SmartTagGenerator.swift`,
  `ClassificationFilter.swift`, `AIAnalysisConstants.swift`,
  `ImagePurposeDetector.swift`, `Models/AIAnalysisError.swift`,
  `Models/AIInsight.swift`, `Models/EnhancedCaptionCache.swift`,
  `Views/AIInsightsInspectorView.swift`, `Views/AIInsightsView.swift`.
- **Group B — Resource & doc deletions**:
  `Resources/CoreMLModels/BLIPImageCaptioning.mlmodel`,
  `Resources/CoreMLModels/Resnet50.mlmodel`, `Resources/Resnet50.mlmodel`,
  all seven `Documentation/AI*` and `Documentation/CoreML*` files,
  `AIInsights.md`, `WARP.md`, `XCODE_BUILD_FIX.md`, `actual_files.txt`,
  the deleted test files in `Tests/Services/` and `Tests/ViewModels/`.

### 0.3 Verify post-commit
- Build again. Run tests (⌘+U). Confirm green on the existing surface.

**Why this commit shape:** A single "remove legacy AI pipeline" commit gives anyone
reading `git log` a clean narrative anchor. Spreading the deletions across phase
commits makes them harder to revert or reason about later.

---

## Phase 1 — Hard Cut to macOS 26 (build settings + `@available` sweep)

After Phase 0, no code should compile a branch reachable only on macOS < 26.

### 1.1 Build settings (Xcode project) — fix four real mismatches
Open `StillView - Simple Image Viewer.xcodeproj/project.pbxproj` and unify:

| Config | Current | Target | Why |
|---|---|---|---|
| Project-level Debug/Release `MACOSX_DEPLOYMENT_TARGET` | `15.0` | `26.0` | Below app target — inconsistent floor |
| Test target Debug/Release `MACOSX_DEPLOYMENT_TARGET` | `14.6` | `26.0` | Tests need same APIs as app |
| App target `INFOPLIST_KEY_LSMinimumSystemVersion` | `12.0` | `26.0` | **App Store / Gatekeeper gating mismatch — most user-visible bug in this list** |
| Test target `IPHONEOS_DEPLOYMENT_TARGET = 17.0` | present | remove | Bogus iOS setting on a macOS-only target |
| Test target `TARGETED_DEVICE_FAMILY = "1,2"` | present | remove | iOS-only key |

These are not five separate "settings polish" items. The `LSMinimumSystemVersion = 12.0`
mismatch in particular means the App Store currently advertises StillView as macOS 12
compatible while the binary is built for 26.0. That is an install-time failure waiting
to happen.

### 1.2 Sweep dead `@available` and version checks
Every check below has an unreachable else branch under the new floor. Delete the check,
keep only the macOS 26 branch:

- `SimpleImageViewerApp.applyWindowResizability` — `#available(macOS 13.0, *)` always true.
- `ContentView.swift:66` — `if #available(macOS 15.0, *) { EnhancedImageDisplayView } else { ImageDisplayView }`. Keep `EnhancedImageDisplayView`. Then check whether `Views/ImageDisplayView.swift` has any other callers; if not, delete it.
- `Extensions/KeyboardNavigation+Preferences.swift` — four `@available(macOS 14.0, *)` annotations.
- `EnhancedImageDisplayView.swift:29` — `.macOS15Enhanced { ... }` modifier. Inline the enhancement unconditionally.
- `EnhancedImageProcessingService.swift` (3 sites), `EnhancedAccessibilityService.swift` (1 site), `EnhancedSecurityService.swift` (4 sites) — `compatibilityService.isMacOS15OrLater` always true. Inline.

### 1.3 Update CLAUDE.md
The project CLAUDE.md already states `Target: macOS 26.0+ (Tahoe)`. After 1.1 + 1.2 this
becomes literally true. Verify the line stays current.

**Why a single phase for build settings + sweep:** They have to ship together. If you
move the deployment target without removing the `@available` checks, the checks still
compile (just always-true), and you'll forget about them. If you remove the checks
without moving the deployment target, the build breaks on macOS < 26 builders.

---

## Phase 2 — Compatibility Service Collapse

`MacOS26CompatibilityService` exists to gate features on OS version. After Phase 1, the
only feature still gated *by anything other than the OS floor* is `aiImageAnalysis`,
and that gate is **Apple Intelligence runtime availability**, not macOS version.

### 2.1 Decide: inline or shrink?
Two options, pick one:

**Option A — Delete the service entirely (recommended).**
- `appleIntelligenceStatus()` is already duplicated in
  `AppleIntelligenceInsightsService.modelAvailability()`. The service version doesn't
  add value; it adds a second source of truth.
- Move `isFeatureAvailable(.aiImageAnalysis)` callers to call
  `AppleIntelligenceInsightsService.shared.availability().isAvailable` directly.
- Delete `MacOS26Feature`, `FeatureAvailabilityInfo`, `FeatureOperationalStatus`,
  `MacOSVersion`, `macOS15Enhanced`, `macOS26Enhanced`, `withFeature`,
  `withFeatureAvailability`, `withFeatureAvailabilityAsync`.

**Option B — Shrink to a one-feature stub.**
- Keep the service, delete all enum cases except `aiImageAnalysis`, delete all
  `isMacOS15OrLater` paths, delete `advancedFeaturesEnabled` (`@Published` but never
  read — dead), delete the unused view extensions.

Either way: **`MacOS26Feature` cannot have ten cases.** Nine of them are unconditional
on macOS 26+. Pick the option whose end-state is most honest about the architecture.

### 2.2 Update callers
- `PreferencesValidator.swift:179` calls `isFeatureAvailable(.aiImageAnalysis)` to gate
  `enableAIAnalysis` validation. Update to use the chosen API from 2.1.
- `PreferencesValidator.swift:168, 173` call `isFeatureAvailable(.enhancedImageProcessing)`.
  After Phase 1 this is always true — delete the validation entirely.
- `ImageViewerViewModel` and `WindowStateManager` references to AI availability go
  through the view-model property `isAIInsightsAvailable`, which already chains to the
  insight service. No churn there.

---

## Phase 3 — Modified-File Audit

The remaining `M` files in `git status` need targeted attention. Read each, decide what
the diff is for, keep what serves AI Insights v12, remove what doesn't.

### 3.1 Preferences chain
- **`PreferencesService.swift`** — `enableAIAnalysis` and `rememberAIInsightsPanelState`
  preferences. **Decision: keep both.** "I don't want backwards compatibility" applies
  to code paths, not user controls. `enableAIAnalysis` is the user's privacy opt-out
  even when Apple Intelligence is capable. The UserDefaults key stays
  (`"enableAIAnalysis"`) for migration; the Swift symbol can stay too — renaming would
  be churn for marginal clarity.
- **`PreferencesViewModel.swift`** — verify the AI section UI copy still talks about
  Apple Intelligence (not the legacy "AI analysis engine"). Confirm `enableAIAnalysis`
  is the only AI-related toggle. (The legacy `enableSmartSearch`,
  `enableImageOrganization` flags are already gone — `grep` confirmed.)
- **`PreferencesValidator.swift`** — see 2.2.

### 3.2 Help and what's-new
- **`Models/HelpContent.swift`** — read the AI Insights help section. Make sure it
  describes the Apple Intelligence flow and not the deleted "AI analyzes your images
  to identify objects, scenes, text, colors, and quality" pipeline. The `whats-new.json`
  diff already migrated; HelpContent must follow.
- **`whats-new.json`** — already updated to describe v12 honestly. Confirm version
  number matches `MARKETING_VERSION = 3.2.0` (or bump to 3.3.0 if this cleanup ships
  as its own release).

### 3.3 Logger and error handling
- **`Extensions/Logger.swift`**, **`Services/ErrorHandlingService.swift`**, and
  **`Services/UnifiedErrorHandlingService.swift`** are modified. Verify changes are AI
  Insights-related (the perception/insight code uses `Logger.info(..., context:
  "AIInsights")`) and not leftover bits of the dead pipeline.

### 3.4 Window state and view-model glue
- **`Services/WindowStateManager.swift`** — `rememberAIInsightsPanelState` plumbing.
  Should remain functional. Just verify it doesn't reference deleted services.
- **`ViewModels/ImageViewerViewModel.swift`** — the `showAIInsights`,
  `isAIInsightsAvailable`, `toggleAIInsights`, `restoreAIInsightsState`,
  `updateAIInsightsAvailability` surface. Verify everything chains through
  `imageInsightViewModel` cleanly, with no references to deleted services or types.

### 3.5 Ghost comments
Sweep the 14 `// Favorites removed` comments in `FolderSelectionViewModel.swift` (5),
`ImageViewerViewModel.swift` (7), and `ContentView.swift` (3). Either delete the
comment and any dead surrounding scaffold, or — if the scaffold is gone — delete the
comment alone. These are minor but their persistence hurts the "no half-finished
implementations" rule in CLAUDE.md.

### 3.6 `Services/Dummy.swift`
13 bytes. Contents: `// Dummy file`. Almost certainly an old workaround for an empty
build phase or a Swift Package Manager target. **Verify nothing references it, then
delete.**

---

## Phase 4 — Quality Verification on Real Images

**Half the user's ask is "improve the quality."** You cannot improve what you have not
measured. Without this phase, Phase 5 is guesswork.

### 4.1 Assemble a sample set (~30 images)
Curate a folder covering the failure modes the old pipeline struggled with:
- Portraits (1 face, single subject) — should yield "portrait of …" titles
- Group photos (5+ faces) — should yield group photo titles
- **Still lifes with no faces** (roses, flowers, food) — should NOT mistakenly call
  them "people photos" (this was a specific old-pipeline failure)
- Vehicles, especially dark/metallic — the old pipeline misclassified these
- Document scans / receipts / signage — OCR-heavy, title should incorporate brand/venue
- Landscapes (horizon detected)
- Low-signal images (blurry, abstract, screenshots of empty UIs)
- A few photos with rich EXIF — verify the camera model is **never** the title

### 4.2 Run insights on each, capture verbatim
For each image, record: file name, generated title, summary, useful details, tags,
limitations. Take screenshots of the inspector. Score each on:
- Title accuracy (does it name what's in the image, not the camera?)
- Subject correctness (especially on the still-life / face-count edge cases)
- OCR incorporation when text is present
- Honesty when signals are sparse

Save as a markdown table in `Documentation/AI_Insights_v12_Sample_Audit.md`. This
artifact becomes the input to Phase 5.

### 4.3 Identify failure patterns
Group the failures. Common categories you'll likely find:
- Prompt-tunable (wording can fix it) → Phase 5.1
- Vision-perception-gap (the FM has no signal to ground on) → Phase 5.2
- Genuine model limit (FM can't do this with current evidence) → document in
  limitations, accept

---

## Phase 5 — SDK-Verified Enhancements

**Do not propose any FoundationModels API call without first verifying it exists in
the macOS 26 SDK on this machine.** Memory and assumptions are not evidence.

### 5.1 Research step (do this first)
Open `Xcode → Help → Developer Documentation` or directly inspect
`/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.X.sdk/System/Library/Frameworks/FoundationModels.framework`.

Answer with citations:
1. Does `LanguageModelSession.respond(...)` accept image attachments in any form
   (multimodal prompt)? If yes, what's the call shape?
2. Is there a `SystemLanguageModel.UseCase.imageDescription` /
   `.contentTagging` / `.vision` / similar use-case that's pre-trained on image
   reasoning? `contentTagging` is documented but may be text-tagging only — verify.
3. Does `Prompt` (or `PromptElement`) accept image inputs?
4. Is there a separate Vision-Foundation-Models bridge (e.g. an Apple-provided
   `ImageReasoningTool` or `VisionResponse` type)?

Write findings to `Documentation/macos26_foundation_models_image_capabilities.md`.

**If any of (1)–(4) exists**, plan a v13 follow-up to use it. Do not retrofit it into
v12; multimodal is a real architectural change.

**If none exists** (most likely outcome given current evidence), the Vision → FM
hybrid is the latest pattern, and Phase 5.2 / 5.3 are the only quality lever.

### 5.2 Vision perception enhancements (only based on Phase 4 findings)
Candidates to consider — pick from this list only what Phase 4 evidence supports:

- **`VNRecognizeAnimalsRequest`** — current classifier returns generic "dog", "cat".
  This API names the species/breed when confident. Cheap to add.
- **`VNDetectHumanBodyPoseRequest`** / **`VNDetectAnimalBodyPoseRequest`** — activity
  inference (running, sitting, eating). The old pipeline tried activity tags;
  body-pose is the right signal source. Only add if Phase 4 shows activity-relevant
  images failing.
- **`VNDetectDocumentSegmentationRequest`** (macOS 13+) — detect document/receipt
  images for better document-style insights. Only useful if Phase 4 includes document
  scans that miscategorize.
- **`VNGenerateAttentionBasedSaliencyImageRequest`** — alongside the current
  *objectness*-based saliency, this gives "where would a viewer look" vs "where are
  the objects." Probably not worth two saliency passes.
- **Newer `ImageRequest` Swift-native API** — if macOS 26 introduced a replacement
  for `VNRequest`, migrate as a code-modernization pass. **Verify the API exists
  before planning the migration** (same research discipline as 5.1).

For each candidate: state the evidence from Phase 4, the expected improvement, and
the cost (perception time, prompt token budget, complexity).

### 5.3 Prompt refinements (only based on Phase 4 findings)
The current system instruction in `ImageInsightCore.ImageInsightPromptBuilder` is
already detailed. Resist adding more rules unless Phase 4 shows specific failures.

Likely small wins (validate against Phase 4 first):
- Add an explicit rule that classifications like `"daisy"` (a single specific
  category > 0.5 confidence) override the "say so plainly when sparse" hedge.
- Tighten OCR incorporation — if OCR contains a venue name and faces > 0, prefer
  "Group photo at [venue]" over "Group photo" or "[Venue] signage."
- Consider switching `SystemLanguageModel.default` to
  `SystemLanguageModel(useCase: .contentTagging)` for the tags field specifically
  (would require a second session call — only worth it if Phase 4 tag quality is
  measurably worse than other fields). **Verify `.contentTagging` is text-only or
  image-aware first**.

### 5.4 Token budget hygiene
The current `maximumResponseTokens: 600` is reasonable but un-instrumented. Add a
one-line `model.tokenCount(for: prompt)` log (macOS 26.4+) before the
`session.respond` call so future tuning has data. No user-facing change.

---

## Phase 6 — Tests, Documentation, Release Notes

### 6.1 Restore test coverage for the v12 surface
The deleted test files (`AIInsightsErrorHandlingTests`, `AIInsightsRegressionTests`,
`ClassificationFilterTests`, `ColorNamingTests`, `SubjectDetectorTests`,
`AIInsightsStateTests`) tested deleted code. They were correctly removed. **They have
no v12 replacements yet.**

Create `Tests/Services/ImageInsightTests.swift` covering:
- **Privacy build assertion** — the project CLAUDE.md mandates this. Test fails if
  `URLSession`, `http(s)://`, `telemetry`, or `analytics` (case-insensitive, regex-bounded)
  appears in any of `AppleIntelligenceInsightsService.swift`,
  `ImagePerceptionService.swift`, `ImageInsightCore.swift`,
  `ImageInsightViewModel.swift`. **Read the four files at test time.** This is the
  most important new test.
- **`ImageInsightAvailability.resolve`** — exhaustive case coverage of the
  `(macOSMajorVersion, foundationModelsAvailable, modelAvailability)` matrix.
- **`ImageInsightInput.withVisualSignals`** — preserves all other fields.
- **`ImageInsightPromptBuilder.prompt`** — output contains "PRIMARY EVIDENCE",
  "SECONDARY EVIDENCE", "CONTEXT ONLY", and the forbidden-title example string.
- **`ImageInsightResult` init defaults** — empty title becomes "Local Image Insight",
  empty limitations becomes the canonical fallback.
- **`ImageInsightViewModel` state transitions** — `prepareForImage`, `generate`,
  `cancelGeneration`, `updateAvailability`. Use a stub `ImageInsightGenerating` that
  returns canned results or throws.
- **OCR cleaner** — `OCRCleaner.clean` drops short tokens, drops mostly-non-alpha
  tokens, dedupes case-insensitively. (Currently `private`; make it `internal` for the
  test or expose a static helper.)

### 6.2 Documentation
- Replace **this file** (`AI_INSIGHTS_IMPROVEMENT_PLAN.md`) when implementation is
  complete with a `AI_INSIGHTS.md` describing the as-built v12 architecture (or
  delete this file — the README + CLAUDE.md already cover it).
- Update **`README.md`** AI Insights section to match v12 reality (the modified diff
  in `git status` is already partway there — finish it).
- Create **`Documentation/AI_Insights_v12_Sample_Audit.md`** in Phase 4. Keep it
  checked in as the quality baseline for future regressions.
- Create **`Documentation/macos26_foundation_models_image_capabilities.md`** in
  Phase 5.1 with the SDK research findings.

### 6.3 Release notes
- `whats-new.json` is already updated for v12. Verify the version string matches the
  Xcode `MARKETING_VERSION` you ship.
- Consider whether this work ships as 3.2.1 (point release, cleanup) or 3.3.0 (minor
  release, "AI Insights with Apple Intelligence"). Lean 3.3.0 — the
  privacy-defaults and quality improvements are user-visible.

---

## Success Criteria

| # | Criterion | How to verify |
|---|---|---|
| 1 | App targets macOS 26 only at every layer | `grep MACOSX_DEPLOYMENT_TARGET project.pbxproj` shows only `26.0`; `INFOPLIST_KEY_LSMinimumSystemVersion` is `26.0`; no `@available(macOS X, *)` for X < 26 in the codebase. |
| 2 | No legacy AI symbols compile | `grep -r "AIBrain\|AIImageAnalysisService\|CoreMLModelManager\|EnhancedVisionAnalyzer\|SmartTagGenerator\|NarrativeGenerator\|ClassificationFilter\|ImageCaptionGenerator\|SubjectDetector\|QualityAssessmentService\|SmartSearchService\|SmartImageOrganizationService\|AIConsentManager" "StillView - Simple Image Viewer/"` returns zero matches. |
| 3 | `MacOS26CompatibilityService` is either gone or has one feature case | Read the file. |
| 4 | Tests pass and include the privacy assertion | `⌘+U` green; `ImageInsightTests.testPrivacyContract` exists and runs. |
| 5 | Sample audit document exists with ≥30 images | `Documentation/AI_Insights_v12_Sample_Audit.md` checked in. |
| 6 | SDK research document exists | `Documentation/macos26_foundation_models_image_capabilities.md` checked in. |
| 7 | "Favorites removed" comments are gone | `grep -r "Favorites removed" "StillView - Simple Image Viewer/"` returns zero matches. |
| 8 | `Services/Dummy.swift` is verified-needed or deleted | File explanation in commit message, or file removed. |

---

## Out of Scope (Explicit Non-Goals)

These are reasonable things this plan deliberately does NOT do:

- **Multimodal `LanguageModelSession` image input** — gated on Phase 5.1 research. If
  it exists, it's a v13 plan, not v12.
- **Re-introducing custom Core ML models** for any reason (duplicate detection,
  landmark detection, face quality). The user has been explicit: Apple Intelligence
  only.
- **Caching insight results** beyond the in-flight task model. Per-image caching is a
  separable feature; do not couple it to this cleanup.
- **A general "macOS 26 features showcase"** — `MacOS26Feature.predictiveLoading` etc.
  exist as enum cases without any callers. They were aspirational. Phase 2 deletes
  them; do not implement them.
- **Refactoring `MARKETING_VERSION` bump strategy** — pick one (3.2.1 or 3.3.0) per
  Phase 6.3 and move on.

---

## Open Decisions (Resolve Before Phase 2)

1. **Option A or B in Phase 2.1** (delete vs. shrink `MacOS26CompatibilityService`).
   Recommendation: **A (delete entirely).** The service was scaffolding for a feature
   matrix that no longer exists.
2. **MARKETING_VERSION** for this ship. Recommendation: **3.3.0** (user-visible
   improvements warrant a minor bump).
3. **Whether to delete `Views/ImageDisplayView.swift`** if Phase 1.2 finds it's only
   reachable from the dead `#available` else branch. Recommendation: **delete** —
   keeping unreachable code violates the project's "no half-finished implementations"
   rule.

---

## Phase Sizing (rough effort)

| Phase | Effort | Risk |
|---|---|---|
| 0 — Baseline lock | ~30 min | Low (mechanical) |
| 1 — Hard cut to macOS 26 | 1–2 hours | Low (changes are tautological) |
| 2 — Compatibility service collapse | 1 hour | Low (one caller, well-isolated) |
| 3 — Modified-file audit | 1–2 hours | Medium (find-then-decide, no template) |
| 4 — Quality verification | 2–3 hours | Medium (depends on image set assembly) |
| 5 — SDK research + enhancements | 2–4 hours | High (research outcome unknown) |
| 6 — Tests + docs | 2–3 hours | Low–Medium |

Total: **10–15 hours** of focused work, gated by Phase 4 image sampling.

---

*Plan version: v12-cleanup (drafted 2026-05-17). Supersedes the v1.2 caption-pipeline
improvement plan. The pipeline this plan applies to is the six-file Apple Intelligence
implementation, not the deleted ~11.5k LOC legacy system.*
