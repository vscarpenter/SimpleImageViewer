# AI Insights Quality Pipeline — Design Spec

**Date:** 2026-05-24
**Status:** Approved
**Scope:** Improve the quality of generated text from the AI Insights feature by expanding input signals, routing to type-specific prompts, tuning generation parameters per image type, and validating output against known-bad patterns.

---

## Problem Statement

The current AI Insights pipeline produces generated text with three recurring quality issues:

1. **Generic/vague descriptions** — "A photograph showing..." or failure to name specific subjects when Vision clearly identifies them.
2. **Wrong content identification** — Hallucinated subjects, venues, or events not supported by Vision signals.
3. **Camera/EXIF leakage** — Despite prompt guardrails, camera models or technical metadata creep into titles and summaries.

Root causes:
- Single prompt for all image types (portrait, document, landscape treated identically)
- OCR hardcoded to `en-US` — non-English text images get zero text signal
- Fixed generation parameters regardless of image content
- No post-generation check for known-bad patterns
- System instruction duplicated in user prompt, diluting attention
- Prompt rules numbered out of order (1, 2, 3, 6, 4, 5)

---

## Architecture

### Current Pipeline (linear, single-strategy)

```
Image → makeInput() → [Vision perception] → [FM generation] → Result
```

### Improved Pipeline (routed, validated)

```
Image → makeInput() → [Vision + multi-lang OCR] → [Type Classification] → [Prompt Selection + Param Tuning] → [FM Generation] → [Output Validation] → Result
                                                                                                                                        ↓ (fail)
                                                                                                                              [Single Retry + correction hint]
```

### Key Architectural Decisions

1. **Image-type classification derives from existing Vision results** — no separate model call. Classifications, face count, OCR presence, saliency, and horizon are sufficient to route.
2. **Prompt strategies are static strings** — each type gets a dedicated user prompt template. No runtime prompt generation beyond filling in signal data.
3. **Output validation is a pure Swift function** — string pattern matching against known-bad outputs. Fast, deterministic, no additional model invocation.
4. **One retry maximum** — if validation fails, regenerate once with adjusted temperature and a correction hint. If retry also fails, return it anyway. Never block the user.
5. **Backward-compatible result type** — `ImageInsightResult` stays unchanged. Quality improvements are internal to the generation pipeline. ViewModel and PanelView are unmodified.

---

## Layer 1: Vision Pipeline — Multi-Language OCR

### Current State

`ImagePerceptionService.swift:139-142`:
```swift
textRecognition.recognitionLevel = .accurate
textRecognition.usesLanguageCorrection = true
textRecognition.recognitionLanguages = ["en-US"]
```

### Change

```swift
textRecognition.recognitionLevel = .accurate
textRecognition.usesLanguageCorrection = true
textRecognition.automaticallyDetectsLanguage = true
textRecognition.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "ja", "zh-Hans", "ko"]
```

### Impact

Images containing non-English text currently produce zero OCR signal. The FM receives no text evidence and falls back to generic classifications. With multi-language support, venue signs in French, product labels in Japanese, documents in Spanish, etc. all produce usable OCR tokens that the FM can reference in its description.

### Risk

Low. `automaticallyDetectsLanguage` is supported in macOS 26 Vision SDK. The priority list means English is still preferred when ambiguous. Existing English-text images are unaffected.

---

## Layer 2: Image-Type Classification

### Type Enum

```swift
enum ImageContentType: String, Sendable, CaseIterable {
    case portrait   // 1 face, subject-focused
    case group      // 2+ faces
    case document   // Heavy text presence
    case landscape  // Horizon + outdoor classifications, no faces
    case object     // Strong single-subject classification, no faces
    case general    // Fallback (current behavior preserved)
}
```

### Classification Rules (Priority Order)

Priority resolves ambiguity — if multiple rules match, highest priority wins.

| Priority | Type | Rule |
|----------|------|------|
| 1 | `document` | `recognizedText.count >= 15` |
| 2 | `group` | `faceCount >= 2` |
| 3 | `portrait` | `faceCount == 1` |
| 4 | `landscape` | `hasHorizon == true` AND `faceCount == 0` AND has outdoor-related classification (confidence > 0.3) |
| 5 | `object` | `salientObjectCount <= 2` AND top classification confidence > 0.7 AND `faceCount == 0` |
| 6 | `general` | Default fallback |

### Outdoor Classification Keywords

For landscape detection, these classification identifiers (from Apple Vision taxonomy) indicate outdoor content:
`sky`, `tree`, `mountain`, `beach`, `ocean`, `lake`, `river`, `field`, `forest`, `sunset`, `sunrise`, `cloud`, `snow`, `desert`, `garden`, `park`

### Implementation

A pure function in a new file. No state, no actor, no async — just pattern matching on `ImagePerceptionResult` fields. Easily unit-testable with constructed inputs.

---

## Layer 3: Prompt Strategy

### Structural Fix

**Remove system instruction duplication.** Currently `ImageInsightPromptBuilder.prompt(for:)` (line 289) concatenates the full `systemInstruction` into the user prompt via `\(systemInstruction)`. The session already receives this as `instructions:` at line 78-79. Removing the duplication frees ~400 tokens of context for actual signal data and prevents attention dilution.

**Fix rule numbering.** Current order is 1, 2, 3, 6, 4, 5. Reorder to sequential 1-6.

### Architecture

```
Session instruction (shared, all types):
  - Core identity and role
  - Hard rules (no camera titles, no hallucination, honesty)
  - Evidence hierarchy (visual > metadata > EXIF)

User prompt (type-specific):
  - Type-appropriate emphasis and constraints
  - Anti-generic patterns for this type
  - Title template guidance
  - Signal data (visual, metadata, camera)
  - Return format specification
```

### Type-Specific Prompt Guidance

#### `portrait`
- **Emphasis:** Person's apparent activity, expression context, setting, clothing/accessories
- **De-emphasis:** Background scene details, other objects
- **Title pattern:** "[Activity/attribute] [setting]" — e.g., "Reading in a sunlit room"
- **Anti-generic:** Forbid "A person standing...", "Portrait of someone..."
- **Constraint:** Never guess identity, name, or age. Describe observable attributes only.

#### `group`
- **Emphasis:** Face count, shared activity, occasion indicators from OCR/signage, setting
- **De-emphasis:** Individual person descriptions
- **Title pattern:** "[N people] [activity] [where]" — e.g., "Three friends at a cafe patio"
- **Anti-generic:** Forbid "A group of people...", "Several individuals..."
- **Constraint:** Never hallucinate event type (wedding, birthday) unless OCR/signage explicitly supports it.

#### `document`
- **Emphasis:** Document type identification, key text content synthesis, layout description
- **De-emphasis:** Photography language, visual aesthetics, "this is an image of..."
- **Title pattern:** "[Document type]: [key content]" — e.g., "Code snippet: Swift async function"
- **Anti-generic:** Forbid "Text on a screen...", "A document showing..."
- **Constraint:** Synthesize OCR into meaning — don't just list words. If fragments are partial, say what's discernible.

#### `landscape`
- **Emphasis:** Setting/environment, lighting/time-of-day cues, natural elements, depth/composition
- **De-emphasis:** Technical camera details, GPS coordinates
- **Title pattern:** "[Scene type] [location indicators]" — e.g., "Coastal sunset with rocky cliffs"
- **Anti-generic:** Forbid "A beautiful landscape...", "A scenic view of..."
- **Constraint:** Name specific natural elements from classifications rather than generic "nature."

#### `object`
- **Emphasis:** Name the specific object, material/condition, immediate context, scale
- **De-emphasis:** Background, human presence (if any)
- **Title pattern:** "[Object name] [distinctive attribute]" — e.g., "Vintage leather suitcase"
- **Anti-generic:** Forbid "An object on a surface...", "A photo of an item..."
- **Constraint:** Use the highest-confidence classification to name it specifically.

#### `general` (fallback)
- **Prompt:** Current prompt logic with structural fixes applied (deduplication, rule reordering)
- **No type-specific constraints** — this is the safety net that preserves current behavior

### All Type Prompts Share

- Evidence hierarchy rendering (PRIMARY / SECONDARY / CONTEXT ONLY sections)
- Same return format (title, summary, likelyContent, usefulDetails, tags, limitations)
- Same forbidden patterns (camera-model titles, hallucinated venues without evidence)
- Required `limitations` field

---

## Layer 4: Generation Parameter Tuning

### Profiles Per Type

| Type | Temperature | Top-K Sampling | Max Tokens | Rationale |
|------|------------|----------------|------------|-----------|
| `portrait` | 0.4 | 3 | 500 | Moderate creativity for describing expression/scene, constrained to avoid hallucination |
| `group` | 0.4 | 3 | 500 | Describe observable facts about the group |
| `document` | 0.2 | 2 | 400 | High factual precision — OCR text is ground truth |
| `landscape` | 0.6 | 4 | 550 | More creative freedom for atmosphere and scene description |
| `object` | 0.3 | 3 | 450 | Name precisely; allow slight creativity for context |
| `general` | 0.5 | 3 | 600 | Current values unchanged |

### Implementation

```swift
struct GenerationProfile: Sendable {
    let temperature: Double
    let topK: Int
    let maxTokens: Int

    static func profile(for type: ImageContentType) -> GenerationProfile
}
```

### Retry Profile

When output validation fails, the retry uses:
- `temperature` = original + 0.15 (escape the bad local minimum)
- Same `topK` and `maxTokens`

---

## Layer 5: Output Validation

### Validation Checks

| Check | Detects | Method |
|-------|---------|--------|
| Camera-model title | "iPhone 13 Pro Capture", "Canon EOS R5 Shot" | Title contains tokens matching camera brand/model patterns from `cameraSignals` input |
| Generic filler title | "A Photograph Showing...", "An Image of..." | Title starts with article + generic noun from static deny-list |
| Empty despite signals | Default fallback text returned when `input.visualSignals` is non-empty | Compare result fields against `ImageInsightResult.init` defaults while input has signals |
| EXIF-driven summary | Summary dominated by camera settings or coordinates | Summary contains camera-signal keywords (f/, ISO, focal length, lat/long patterns) as primary content |
| Raw OCR dump | Title is just verbatim OCR without synthesis | Title exactly matches one of the `recognizedText` lines from input |

### Deny-List for Generic Filler Detection

Title prefixes (case-insensitive):
- "A photograph of"
- "An image of"
- "A photo showing"
- "A picture of"
- "This is a"
- "An image showing"
- "A photograph showing"

### Camera Brand/Model Patterns

Extract from `cameraSignals` input — if any signal starts with "Camera:", parse the brand/model string and check if it appears in the title.

### Validation Result Type

```swift
enum InsightValidation: Sendable {
    case passed
    case failed(reasons: [ValidationFailure])
}

enum ValidationFailure: String, Sendable, CaseIterable {
    case cameraModelTitle
    case genericFillerTitle
    case emptyDespiteSignals
    case exifDrivenContent
    case rawOCRDump
}
```

### Retry Behavior

```
1. Generate with type-specific prompt + parameters
2. Validate result
3. If .passed → return result
4. If .failed(reasons) →
     a. Bump temperature by +0.15
     b. Append correction hint to prompt:
        "Avoid: [specific patterns from failure reasons]. Instead: [type-specific positive guidance]."
     c. Regenerate once
     d. Return retry result regardless of validation (never block user)
```

### Correction Hints Per Failure

| Failure | Correction appended to retry prompt |
|---------|-------------------------------------|
| `cameraModelTitle` | "Do NOT use the camera model in the title. Name what the image SHOWS instead." |
| `genericFillerTitle` | "Be specific in the title. Name the subject, scene, or activity directly." |
| `emptyDespiteSignals` | "Vision detected signals — use them. The title and summary must reference the specific classifications and text found." |
| `exifDrivenContent` | "The summary must describe image CONTENT, not camera settings. Lead with what is visible." |
| `rawOCRDump` | "Synthesize the text into a meaningful description rather than copying it verbatim." |

---

## File Structure

### New Files (2)

| File | Location | Purpose | ~Lines |
|------|----------|---------|--------|
| `ImageContentTypeClassifier.swift` | `Services/` | Pure function: perception → content type. Also holds `GenerationProfile` struct and mapping. | ~80 |
| `InsightOutputValidator.swift` | `Services/` | Pure function: result + input → validation. Deny-lists and pattern matching. | ~100 |

### Modified Files (3)

| File | Changes |
|------|---------|
| `ImagePerceptionService.swift` | Add `automaticallyDetectsLanguage = true`, expand `recognitionLanguages` (~3 lines) |
| `ImageInsightCore.swift` | Rewrite `ImageInsightPromptBuilder`: split into shared system instruction + 6 type-specific prompt functions. Fix rule numbering. Remove duplication. Add `ImageContentType` enum. |
| `AppleIntelligenceInsightsService.swift` | In `generateInsight()`: after perception → classify type → select prompt → select generation profile → generate → validate → optionally retry. Flow grows from ~10 lines to ~30 lines. |

### Unchanged Files (3)

| File | Reason |
|------|--------|
| `ImageInsightViewModel.swift` | State machine unchanged. Retry is internal to `generateInsight()`. |
| `ImageInsightPanelView.swift` | `ImageInsightResult` type unchanged. No UI changes. |
| `ImageInsightTests.swift` | Existing tests pass. New tests added alongside. |

---

## Testing Strategy

### Unit Tests for New Components

- **ImageContentTypeClassifier:**
  - Given 1 face, no dominant scene → returns `.portrait`
  - Given 3 faces → returns `.group`
  - Given 20 OCR tokens → returns `.document`
  - Given horizon + outdoor label + no faces → returns `.landscape`
  - Given high-confidence classification + no faces + 1 salient object → returns `.object`
  - Given sparse signals → returns `.general`
  - Priority tests: 15 OCR tokens + 2 faces → `.document` (priority 1 wins)

- **InsightOutputValidator:**
  - Title "iPhone 13 Pro Capture" with camera signal "Camera: Apple iPhone 13 Pro" → fails `cameraModelTitle`
  - Title "A photograph showing flowers" → fails `genericFillerTitle`
  - Default title "Local Image Insight" with non-empty visual signals → fails `emptyDespiteSignals`
  - Summary "Shot at f/2.8, ISO 400, 50mm" → fails `exifDrivenContent`
  - Title matching exact OCR line → fails `rawOCRDump`
  - Clean result with specific title → passes

- **GenerationProfile:**
  - Each type maps to expected temperature/topK/maxTokens

### Integration Tests

- Full pipeline: constructed `ImageInsightInput` → type classification → prompt selection → verify correct prompt template used
- Retry path: mock a result that fails validation → verify retry called with adjusted params and correction hint

### Existing Tests

All existing `ImageInsightTests` continue to pass unchanged. The privacy test (no URLSession/http/telemetry) still applies to the new files.

---

## Success Criteria

1. Non-English images with text produce insights that reference the visible text content
2. Portrait images get person-focused descriptions (not scene-focused)
3. Document/screenshot images get content-type identification and text synthesis
4. Camera model never appears in generated titles
5. Generic filler phrases ("A photograph showing...") are caught and corrected
6. Landscape images get atmospheric descriptions using scene classifications
7. Object images name the specific object from high-confidence classifications
8. `general` fallback produces same quality as current implementation (no regression)
9. All changes stay on-device, no network calls, no new dependencies
10. `ImageInsightResult` type unchanged — ViewModel and View unmodified

---

## Non-Goals

- No quality scores or badges shown to users
- No UI changes
- No new Vision request types (beyond OCR language fix)
- No barcode/QR detection
- No document rectangle detection
- No multi-pass generation beyond the single retry
- No caching (separate concern, can be added independently later)
- No batch processing
- No export functionality

---

## Dependencies

- macOS 26+ (unchanged)
- Apple Intelligence enabled (unchanged)
- No new frameworks or external dependencies
- `VNRecognizeTextRequest.automaticallyDetectsLanguage` available in macOS 26 SDK
