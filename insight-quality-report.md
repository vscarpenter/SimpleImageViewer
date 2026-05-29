# AI Insights — Generation-System Quality Review

## Scope

This reviews the **generation system** that shapes AI Insights — the prompt contract (`systemInstruction` + 6 type-specific prompts + 3 ranked evidence buckets + `returnFormat`), the perception signal rendering, the classifier routing thresholds, the `@Generable`/`@Guide` constraints, and the `InsightOutputValidator` gate — **not live model outputs**. FoundationModels runs on-device only, so model behavior cannot be exercised here; every finding is grounded in code that was read and traced, with verified `file:line`. Findings split into three actionability tiers: (1) **testable-correctness** fixes that are safe to apply and verify via `xcodebuild test`; (2) **prompt/contract** changes that alter shipping model behavior and need human approval; (3) **tuning** dials that are reversible experiments.

> All severities below are the **verification-corrected** values. The review pass downgraded six findings from `high` (the original triage) after tracing blast radius; those deltas are shown inline. **VALID-1 is the only item that remains `high`.** Several proposed diffs in the source findings were traced as *broken* (they regress their own tests); the fixes below use the corrected implementations from the verification pass.

---

## 2. Quick wins — testable-correctness fixes

Safe to apply and verify with `xcodebuild test`. Ordered by corrected severity.

| # | Sev | File:line | Defect (1-line) | Fix | Test |
|---|-----|-----------|-----------------|-----|------|
| VALID-1 (+CONSIST-3) | **high** | `InsightOutputValidator.swift:123-138, 211-224` | `hasPromptScaffoldLeakage` guards a removed `suitcase`/`leather` prompt example and now false-positives correct output when Vision emits a synonym (`luggage`/`bag`) | Delete the check entirely (see below) | New `test_legitimateLeatherSuitcasePhotoPasses`; delete 2 over-fit tests |
| FALLBACK-1 | medium ↓ | `ImageInsightCore.swift:500-501` | `.document` fallback's `"Text-heavy image"` branch is unreachable; every document fallback emits the constant `"Readable text in image"` | Lead title with cleaned first OCR line via `clipped()` | New `test_documentFallbackTitleIncludesOCRText` |
| FALLBACK-2 | medium | `ImageInsightCore.swift:606-611, 472` | Fallback promotes a ≥0.2-confidence label to a confident title (`"Blur outdoor scene"`) with no hedge, defeating the prompt's hedge-when-weak rule | Gate the *titling* subject at ≥0.5; keep 0.2 list for summary/tags | New `test_fallbackTitleHedgesWhenTopLabelIsLowConfidence` (type `.general`) |
| PERCEPT-2 | medium ↓ | `ImagePerceptionService.swift:190-195` | Routing-critical face-count predicate (`area ≥ 0.003 ‖ conf ≥ 0.7`) is trapped in a `private` Vision closure with zero test coverage; broke once already (commit `1e423ec`) | Extract `static func shouldCountFace(area:confidence:)`, call it from the filter | New `ImagePerceptionServiceTests.test_shouldCountFace_*` (3 cases) |
| VALID-2 | medium | `InsightOutputValidator.swift:84-95, 164-168` | `genericPrefixes` has `"a photo showing"` but not `"a photo of"` — `"A photo of a sunset"` slips through (`hasPrefix` asymmetry) | Add `"a photo of"` to `genericPrefixes` | New: assert `"A photo of a sunset"` → `.genericFillerTitle` |
| VALID-3 | medium | `InsightOutputValidator.swift:149-162` | `hasCameraModel` needs ≥2 significant tokens; single-token makes (`Camera: DJI`/`GoPro`, or any file missing the Model tag) never fire | Require 1 match when `significantTokens.count == 1`, keep ≥2 otherwise | New: `"DJI aerial shot"` + `["Camera: DJI"]` → `.cameraModelTitle`; assert no FP on `"A red apple…"` + `["Camera: Apple iPhone 15"]` |
| CONSIST-4 | medium | `InsightOutputValidator.swift:149-162` | Short camera models (`RX100`, bare `iPhone`) defeat the ≥2 gate even though the prompt forbids "any camera model" in the title | Same single-token relaxation as VALID-3, **plus** require the lone token be model-like (contains a digit OR not in a brand stop-set) so `"Apple orchard"` doesn't trip | New `test_singleDistinctiveCameraTokenInTitleFails`; keep `test_cameraModelNotInTitlePasses` |
| CONSIST-2 (+CONSIST-6) | medium ↓ | `InsightOutputValidator.swift:84-105, 164-168` vs `ImageInsightCore.swift:310,331,351,371,390` | 12 type-specific FORBIDDEN-title phrases (`"A beautiful landscape"`, `"Nature scene"`, `"Portrait of someone"`, …) are invisible to the validator — pure silent drift | Add a generic-filler phrase list checked by **prefix/word-boundary** (not unbounded `.contains`); add bare `"selfie"`/`"portrait"` to `genericExactTitles` | New `test_typeSpecificForbiddenTitlesFailValidation` iterating the 12 |
| CONSIST-5 | medium | `InsightOutputValidator.swift:140-162` vs `ImageInsightCore.swift:271,404` | The headline forbidden example `"iPhone 13 Pro Max Capture"` is only caught when camera EXIF is present; a camera-less PNG/screenshot can ship the parroted title | Add a 1-element scaffold-forbidden-title list checked independently of `cameraSignals` | New `test_parrotedScaffoldExampleTitleFailsWithoutCameraMetadata` |
| VALID-4 | medium | `InsightOutputValidator.swift:199-208` | `hasFileNameTitle` uses **ordered** word-set equality; `"Summer garden scene"` for `summer-garden.jpg` (extra word) or `"Garden summer"` (reorder) evades it | Switch to evidence-gated **filename-stem coverage** (fraction of *stem* words echoed-and-unsupported ≥ ~0.66), not title-fraction | New `test_fileNameLeakEvadedByExtraWordFails` + FP-guard `test_descriptiveFilenameSupportedByVisionPasses` |
| CONSIST-1 | medium ↓ | `InsightOutputValidator.swift:186-197` vs `ImageInsightCore.swift:248-252` | `hasRawOCRDump` rejects the *correct* title for a pure short sign (`"Closed For Renovation"` = 100% OCR overlap), fighting RULE 1 which mandates incorporating OCR words | Gate the dump check on OCR corpus size: only fire when `ocrWords.count >= 6` | New `test_shortSignTitleNamedAfterItsOwnTextPasses`; **re-verify** `test_titleMatchingExactOCRLine…` + `test_titleMostlyComposed…` still pass |
| PERCEPT-3 | low | `ImagePerceptionService.swift:81-85` | `count >= 2` floor (line 81) **and** `semanticCount >= 2` (line 85) both drop single-char CJK signage (`出`, `湯`) that the OCR config explicitly enables (`ja`/`zh-Hans`/`ko`) | Relax **both** guards with `isStandaloneCJK(_:)` scalar-range helper | New `test_clean_keepsSingleCharCJKSign` (`["出","A"]` → keeps `出`) |
| PERCEPT-1 | low ↓ | `ImagePerceptionService.swift:181-194` | Comment claims `conf ≥ 0.7` "rejects false positives that happen to be large" — an `OR` can only add matches, never reject (comment/code drift; same drift caused bug `1e423ec`) | Comment-only rewrite (do **not** flip the operator) | Covered by PERCEPT-2 extraction (makes the comment checkable) |

### Diffs

**VALID-1 (+CONSIST-3) — delete the dead/false-positive scaffold check** *(high)*
Verified via git history: this entire check is part of the current uncommitted changeset; the `vintage leather suitcase` prompt example it targets was removed in the *same* changeset, so it is born dead. The only live forbidden example (`iPhone 13 Pro Max Capture`) is handled by the camera-title checks. Every reference to `.promptScaffoldLeakage` is confined to this file and consumed as an opaque `[ValidationFailure]`, so deletion compiles cleanly. **Supersedes CONSIST-3** (same code; reject CONSIST-3's "extract tokens from scaffold programmatically" — premature abstraction).

```diff
// ValidationFailure enum (line 16)
-    case promptScaffoldLeakage

// validate() call site (lines 51-53)
-        if hasPromptScaffoldLeakage(result, input: input) {
-            failures.append(.promptScaffoldLeakage)
-        }

// correctionHint() branch (lines 75-76)
-            case .promptScaffoldLeakage:
-                return "Do NOT copy wording from prompt examples or scaffold text. Use only this image's evidence."

// static lists (lines 123-138) — DELETE both promptScaffoldLeakPhrases and unsupportedScaffoldConcepts
// helper hasPromptScaffoldLeakage (lines 211-224) — DELETE entirely
```
Delete the two over-fit tests (`test_promptExamplePhraseFailsValidation`, `test_unsupportedSuitcaseConceptFailsValidationEvenWhenExactPromptPhraseChanges`). Keep the smoke test `test_promptScaffold_doesNotLeakRealEntityNames` (it guards the *prompt*, which is the correct layer). Add:
```swift
func test_legitimateLeatherSuitcasePhotoPasses() {
    let result = makeResult(title: "Leather suitcase on a table")
    // Apple Vision emits the synonym, not the literal word
    let input = makeInput(visualSignals: ["Scene/object categories: luggage (88%), bag (72%)"])
    XCTAssertEqual(InsightOutputValidator.validate(result, input: input), .passed)
}
```

**FALLBACK-1 — content-forward document fallback title** *(medium)*
```diff
 case .document:
-    return perception.recognizedText.isEmpty ? "Text-heavy image" : "Readable text in image"
+    if let firstLine = perception.recognizedText.first {
+        return "Document: \(clipped(firstLine, to: 50))"
+    }
+    return "Text-heavy image"  // defensive default (unreachable from classifier today)
```

**FALLBACK-2 — confidence-gated titling subject** *(medium)*
```diff
+private static func confidentSubject(from perception: ImagePerceptionResult) -> String? {
+    perception.classifications
+        .filter { $0.confidence >= 0.5 && !personLikeLabels.contains(displayLabel($0.identifier)) }
+        .map { displayLabel($0.identifier) }
+        .first
+}
// in result(): pass confidentSubject(...) to title(for:); keep usableLabels(0.2) for summary/details/tags
```
Test note: the hedge test must use `type: .general` — `car@0.22` cannot route to `.object` via the real classifier (object requires `> 0.7`), so an `.object`-typed test exercises an impossible state.

**PERCEPT-2 — extract the routing-critical predicate** *(medium)*
```diff
+    /// Counts a detected face if it occupies a reasonable area OR is high-confidence.
+    /// Pure + testable: faceCount drives prompt routing (portrait vs group).
+    static func shouldCountFace(area: Double, confidence: Float) -> Bool {
+        area >= 0.003 || confidence >= 0.7
+    }
 ...
-        return area >= 0.003 || observation.confidence >= 0.7
+        return shouldCountFace(area: Double(area), confidence: observation.confidence)
```
Tests: `(0.008, 0.6)→true` (bar-photo, area arm), `(0.001, 0.4)→false`, `(0.001, 0.85)→true` (confidence arm).

**VALID-2 — add the missing generic prefix** *(medium)*
```diff
     private static let genericPrefixes = [
         "a photograph of",
         "an image of",
         "a photo showing",
+        "a photo of",
         "a picture of",
```

**VALID-3 + CONSIST-4 — single-token camera names, with FP guard** *(medium)*
The naive `minMatches = 1` regresses on brand homonyms (`"Apple orchard"`, `"Canon in D"`), so the lone token must be model-like before flagging.
```diff
 private static func hasCameraModel(in text: String, cameraSignals: [String]) -> Bool {
     let lowercaseText = text.lowercased()
     for signal in cameraSignals {
         guard signal.hasPrefix("Camera:") else { continue }
         let cameraName = String(signal.dropFirst("Camera:".count)).trimmingCharacters(in: .whitespaces)
         let significantTokens = normalizedWords(cameraName).filter(isSignificantCameraToken)
         let matchCount = significantTokens.filter { lowercaseText.contains($0) }.count
-        if matchCount >= 2 {
-            return true
-        }
+        if matchCount >= 2 { return true }
+        // Single-token model: flag only when that token is model-like (has a digit
+        // or isn't a generic camera brand word), so "Apple orchard" doesn't trip.
+        if significantTokens.count == 1, matchCount == 1, let token = significantTokens.first,
+           isModelLikeToken(token) {
+            return true
+        }
     }
     return false
 }
+private static let cameraBrandStopSet: Set<String> = ["apple", "canon", "sony", "nikon", "fujifilm", "camera"]
+private static func isModelLikeToken(_ token: String) -> Bool {
+    token.contains(where: \.isNumber) || !cameraBrandStopSet.contains(token)
+}
```

**CONSIST-2 (+CONSIST-6) — close the silent-drift gap** *(medium)*
Use prefix/word-boundary matching, **not** unbounded `.contains` (`"nature scene"` is a substring of `"Signature scene"`). Add bare `"selfie"`/`"portrait"` as exact titles (CONSIST-6's enforcement half).
```diff
+    private static let genericFillerPrefixes = [
+        "a person standing", "portrait of someone", "a group of people",
+        "several individuals", "text on a screen", "a document showing",
+        "a beautiful landscape", "a scenic view of", "nature scene",
+        "an object on a surface", "a photo of an item"
+    ]
 private static func hasGenericFillerTitle(_ title: String) -> Bool {
     let lowercaseTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
     return genericExactTitles.contains(lowercaseTitle)
         || genericPrefixes.contains { lowercaseTitle.hasPrefix($0) }
+        || genericFillerPrefixes.contains { lowercaseTitle.hasPrefix($0) }
 }
// add "selfie", "portrait" to genericExactTitles
```

**CONSIST-5 — catch the parroted example without EXIF** *(medium)*
```diff
+    private static let scaffoldForbiddenTitlePhrases = ["iphone 13 pro max capture"]
 private static func hasGenericFillerTitle(_ title: String) -> Bool {
     let lowercaseTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
     return genericExactTitles.contains(lowercaseTitle)
         || genericPrefixes.contains { lowercaseTitle.hasPrefix($0) }
+        || scaffoldForbiddenTitlePhrases.contains { lowercaseTitle.contains($0) }
 }
```
(Reject the finding's "derive the set from scaffold text" long-term idea — premature abstraction for one literal.)

**VALID-4 — evidence-gated filename-stem coverage** *(medium)*
The finding's 0.8 *title-fraction* threshold fails its own headline test (`"Summer garden scene"` → 2/3 = 0.667). Measure **filename-stem coverage** instead.
```diff
     let titleWords = Set(normalizedWords(title))
     let fileWords = normalizedWords(stem)
     guard fileWords.count >= 2 || (fileWords.first?.count ?? 0) >= 4 else { return false }
-    return titleWords == fileWords
+    guard !fileWords.isEmpty else { return false }
+    let evidence = evidenceText(from: input)  // thread input through
+    let echoed = fileWords.filter { titleWords.contains($0) && !evidence.contains($0) }
+    // Title echoes most of the file-name stem with no visual support.
+    return Double(echoed.count) / Double(fileWords.count) >= 0.66
```

**CONSIST-1 — don't punish a short sign for naming itself** *(medium)*
The finding's `ocrWords.count >= titleWords.count + 3` regresses both existing OCR-dump tests (6 ≥ 7 and 6 ≥ 8 are both false). Gate on absolute corpus size instead.
```diff
     guard titleWords.count >= 3 else { return false }
     let ocrWords = Set(normalizedWords(ocrLines.joined(separator: " ")))
     guard !ocrWords.isEmpty else { return false }
+    // A short self-contained sign is legitimately named after its own text (RULE 1).
+    // Only treat high overlap as a dump when the OCR corpus is substantially larger.
+    guard ocrWords.count >= 6 else { return false }
     let overlapCount = titleWords.filter { ocrWords.contains($0) }.count
     let overlapRatio = Double(overlapCount) / Double(titleWords.count)
     return overlapRatio >= 0.85
```
Re-run `test_titleMatchingExactOCRLineFailsValidation` (6 OCR words ≥ 6 ✓) and `test_titleMostlyComposedFromOCRWordsFailsValidation` (6 ≥ 6 ✓) — both still fire; the new short-sign case (3 OCR words < 6) passes.

**PERCEPT-3 — keep single-char CJK signage** *(low)*
The finding's diff touches only line 81; line 85's `semanticCount >= 2` *also* drops a length-1 token, so as written it fails its own test. Relax **both**.
```diff
-            guard trimmed.count >= 2 else { continue }
+            guard trimmed.count >= 2 || isStandaloneCJK(trimmed) else { continue }
 ...
-            guard semanticCount >= 2, semanticRatio >= 0.5 else { continue }
+            guard semanticCount >= 2 || isStandaloneCJK(trimmed), semanticRatio >= 0.5 else { continue }
```

**PERCEPT-1 — honest comment (no operator change)** *(low)*
Comment-only; the `OR` is the correct, empirically-validated operator (commit `1e423ec` fixed `&&`→`||` to recover the bar-photo case). Drop the "detector self-thresholds internally" rationale (unverifiable here). File uses Unicode `≥`.
```diff
-        //   - Confidence ≥ 0.7 rejects false positives that happen to be large (e.g. a
-        //     face-shaped pattern in a poster, decoration, or reflection).
+        //   - Confidence ≥ 0.7 RESCUES small but high-confidence faces below the area floor;
+        //     with OR it can only add matches, never reject a large detection.
```

---

## 3. Prompt & contract changes (propose-only)

These alter shipping model behavior and **cannot be verified without the on-device model**. Present for human approval; do not auto-apply.

**CONSIST-6 (prompt half) — reconcile the `selfie` valence** *(low)*
The perception hint (`ImagePerceptionService.swift:43-44`, `"likely a portrait or selfie"`) and RULE 2 (`ImageInsightCore.swift:255`, `"1 = portrait or selfie"`) endorse `selfie` as a content category, while the portrait prompt (`ImageInsightCore.swift:310`) lists `"Selfie"` as a FORBIDDEN *title*. Same word, opposite valence. Keep the concept usable; forbid only the lazy one-word title:
```diff
// portraitPrompt FORBIDDEN line (ImageInsightCore.swift:310)
-   ...FORBIDDEN: ... "Selfie"...
+   ...FORBIDDEN: a bare "Selfie" / "Portrait" with no descriptive content...
```
(The *enforcement* half — folding bare `"selfie"`/`"portrait"` into the validator — is already in §2 under CONSIST-2.)

> No other §3-only items. PERCEPT-1, though originally filed as `prompt-judgment`, is a comment-only doc fix with no model-behavior change and is fully verifiable — it lives in §2 above, paired with PERCEPT-2 which makes the comment checkable against code.

---

## 4. Tuning judgment calls (reversible experiments)

| Finding | Sev | Location | Current | Suggested | Rationale / risk |
|---------|-----|----------|---------|-----------|------------------|
| ROUTE-1 | medium ↓ | `ImageContentTypeClassifier.swift:37-44, 70-74` | `.landscape` requires `hasHorizon && outdoor(>0.3)` (AND-gate) | Add a 2nd branch: `salientObjectCount == 0 && outdoor(≥0.5) → .landscape` | Horizonless landscapes (forest, dune, occluded waterline, top-down snow) misroute to `.object`/`.general` and lose the scenery-tuned profile (temp 0.6/topK 4/550). **Do not** use the finding's unconditional `outdoor(≥0.5)` branch — it over-routes object-in-outdoor photos (boat+water, flower+garden, dog+park). The `salientObjectCount == 0` gate is the discriminator that steals pure scenes while leaving object photos in `.object`. Reversible. |
| ROUTE-4 | low | `ImageContentTypeClassifier.swift:11-15, 25-35, 49-66` | ID card / badge with 1 face + light text → `.portrait` | Add `card`/`license`/`passport`/`id`/`badge` to `documentKeywords` | A loosely-shot badge (1 face, few fields, no `document` class) gets the person-framed prompt instead of reading the card. **Reject** the finding's option 1 (`≥3 lines + face → document`) — it regresses the common portrait-with-signage case. Option 2 fires only when Vision classifies a card at >0.25 *and* there are ≥3 lines, so it won't grab incidental-signage portraits. Most real licenses/passports already trip the ≥8-line heavy-text path, so blast radius is the loose-badge tail. |
| PROFILE-1 | low ↓ | `ImageContentTypeClassifier.swift:97-103` | Retry always lowers temp 0.1 & caps topK≤2 | Branch `retryProfile(for: failures)`: tighten for hallucination/leakage; hold-steady-or-nudge-up for `.emptyDespiteSignals`/`.genericFillerTitle` | Under-specification retries push the model toward the same conservative argmax that produced the generic answer (the codebase's own comment at `AppleIntelligenceInsightsService.swift:216-219` warns argmax "miss[es] anything not in the top-1"). `allSatisfy` guard defaults any mixed/leakage set to tightening (safe). Low because the `correctionHint` is a strong opposing lever and `.emptyDespiteSignals` only fires on verbatim fallback sentinels (rare from a live FM). Reversible; conservative variant: hold temp steady rather than +0.1. |
| VALID-6 | low | `InsightOutputValidator.swift:178-184` | `exifHits >= 2` to flag EXIF-driven content | **Leave as-is** | A lone trailing `f/2.8` slips through, but the proposed "strong-pattern fires on 1" split FPs on legit content (`"shot on location near the coast"`, `"a wide aperture for daylight"`). The ≥2 floor is a deliberate guard against incidental single-substring mentions (`iso`/`gps`/`aperture` as ordinary words). Refine only with measured FP data. |

---

## 5. Cross-stage consistency matrix

The graded artifact. Each row is one contract rule / forbidden phrase / `@Guide`, mapped across the three enforcement stages. **Gap** classifies the mismatch. (Stages: P = prompt rule, G = `@Guide`, V = validator check.)

| Contract rule | Prompt (P) | `@Guide` (G) | Validator (V) | Gap classification |
|---------------|-----------|-------------|---------------|--------------------|
| Incorporate OCR words into title (RULE 1) `Core:248-252` | ✅ "MUST incorporate… treat as fact" | — | ⚠️ `hasRawOCRDump` **rejects** faithful short-sign titles `Validator:186-197` | **P↔V conflict** — prompt mandates, validator punishes (CONSIST-1) |
| No "any camera model" in title `Core:269-271,310,404` | ✅ all 6 prompts | ✅ `Service:270` | ⚠️ `hasCameraModel` needs ≥2 tokens `Validator:149-162` | **Under-enforced** — short/single-token models slip (CONSIST-4, VALID-3) |
| Forbidden example `"iPhone 13 Pro Max Capture"` `Core:271,404` | ✅ | ✅ "no prompt examples" `Service:270` | ⚠️ caught **only** when camera EXIF present `Validator:140-162` | **Partial** — unguarded on camera-less images (CONSIST-5) |
| Type-specific FORBIDDEN titles (12: `"A beautiful landscape"`, `"Nature scene"`, `"Portrait of someone"`, `"A group of people"`, …) `Core:310,331,351,371,390` | ✅ per type | partial | ❌ **none** of the 12 — `hasGenericFillerTitle` misses all `Validator:164-168` | **Rule with no validator** — silent drift (CONSIST-2) |
| `"A photo of …"` generic title | ✅ (general) | — | ❌ FN — `"a photo of"` absent from `genericPrefixes` `Validator:84-95` | **Rule with no validator** (VALID-2) |
| `selfie` as content vs lazy title `Core:255,310` + `Perception:43-44` | ⚠️ endorsed as category, forbidden as title | — | ❌ bare `"Selfie"` not in `genericExactTitles` `Validator:97-105` | **P↔P valence conflict + no validator** (CONSIST-6) |
| No camera/EXIF in summary/title (shooting settings) `Core:269-271` | ✅ | ✅ usefulDetails-only exception | ⚠️ `hasExifDrivenContent` needs ≥2 hits `Validator:178-184` | **Under-enforced** — lone EXIF clause slips (VALID-6) |
| No file name as title | implicit | implicit | ⚠️ `hasFileNameTitle` exact-ordered equality `Validator:199-208` | **Trivially evaded** — extra/reordered word (VALID-4) |
| Removed `"vintage leather suitcase"` example | ❌ removed from prompt | — | ⚠️ `hasPromptScaffoldLeakage` still guards it `Validator:123-138,211-224` | **Validator with no rule** — false-positives correct output (VALID-1) |
| Camera model in summary/details/tags | ✅ | ✅ | ✅ `hasCameraModelLeakage` `Validator:144-147` | aligned |
| Empty/sentinel output despite signals | ✅ "use the signals" | ✅ | ✅ `hasEmptyDespiteSignals` | aligned (fires on verbatim sentinels only) |

**Structural fix the matrix points to:** the type-specific FORBIDDEN lists (prompts) and the validator's filler lists drift independently. Drive both from **one shared constant** (the same list §2/CONSIST-2 introduces) so a new forbidden phrase added to a prompt cannot silently bypass the validator. This shared list should also be the source for plan **Task 3.2**'s quality-scorer generic-phrase list (see §6) — three consumers, one source of truth.

---

## 6. Dropped / not-pursued

- **CONSIST-3** — merged into **VALID-1** (same code `hasPromptScaffoldLeakage`; VALID-1 is the git-history-confirmed superset and the only `high`). Its "extract scaffold tokens programmatically" suggestion is rejected as premature abstraction.
- **Six `high`→`medium`/`low` downgrades** by verification (blast-radius traced): CONSIST-1, CONSIST-2, CONSIST-3, ROUTE-1, PERCEPT-1, PERCEPT-2. Output stays grounded/valid/privacy-safe in every downgraded case — these are sub-optimal-tuning or backstop-hole defects, not wrong/ungrounded content.
- **Plan dedupe — Task 3.1 (Confidence Tuning):** owns OCR *confidence* filtering and per-sensitivity classification/face thresholds. **PERCEPT-3** (single-char CJK *length* floor) is orthogonal — a token-survival rule, not a confidence dial — so it's kept separate. The face-confidence threshold the plan exposes is the same `0.7` arm **PERCEPT-2** extracts; the extraction makes that threshold unit-testable for 3.1's benefit (fold-in, not duplicate).
- **Plan dedupe — Task 3.2 (Quality Scoring):** the plan adds a *new post-hoc scorer/badge* with its own generic-phrase + camera-leakage lists. The validator findings here (CONSIST-2/4/5, VALID-1/2/3/4) fix the *existing `validate()` gate* that drives retry/fallback — a different layer. Fold-in: 3.2's scorer should consume the **shared filler/forbidden constant** from §5 rather than maintaining a parallel list.
- **VALID-6** — real but parked: `exifHits >= 2` left unchanged; refine only with measured FP data (the split FPs on `"shot on location"` / `"wide aperture"`).
- **PERCEPT-1 operator flip** — explicitly *not* pursued: the `OR` is correct and empirically validated (commit `1e423ec`). Only the stale comment is fixed.

---

## 7. Implementation status — §2 applied & verified (branch `fix/ai-insights-quality`)

All §2, §3, and §4 fixes were implemented via TDD (watched-RED → minimal-GREEN) and verified with `xcodebuild test` on macOS (Xcode 26.5). Full test target: **76 tests, 0 failures**, including the privacy guardrail (`ImageInsightPrivacyAndProjectTests`). The one exception is **VALID-6, deliberately left as-is** per §4's own recommendation (the proposed split false-positives on legitimate content like "shot on location near the coast").

| Finding | Files changed | Tests (new) |
|---------|---------------|-------------|
| VALID-1 (+CONSIST-3) | `InsightOutputValidator.swift` — deleted `.promptScaffoldLeakage` + both lists + helper | `test_legitimateLeatherSuitcasePhotoPasses`; removed 2 over-fit tests |
| VALID-2 | added `"a photo of"` prefix | `test_aPhotoOfPrefixFailsValidation` |
| VALID-3 + CONSIST-4 | single-token camera detection w/ `isModelLikeToken` + `cameraBrandStopSet` | `test_singleTokenCameraNameInTitleFails`, `test_cameraBrandHomonymInTitlePasses` |
| CONSIST-2 (+CONSIST-6 enforcement) | `genericFillerPrefixes` (hasPrefix) + `selfie`/`portrait` exact titles | `test_typeSpecificForbiddenTitlesFailValidation` (13 phrases) |
| CONSIST-5 | `scaffoldForbiddenTitlePhrases` checked independent of EXIF | `test_parrotedScaffoldExampleTitleFailsWithoutCameraMetadata` |
| VALID-4 | `hasFileNameTitle` → evidence-gated stem coverage (≥0.66) | `test_fileNameLeakWithExtraWordFails`, `test_descriptiveFilenameSupportedByVisionPasses` |
| CONSIST-1 | `hasRawOCRDump` gated on `ocrWords.count >= 6` | `test_shortSignTitleNamedAfterItsOwnTextPasses` |
| FALLBACK-1 | `ImageInsightCore.swift` — document fallback leads with OCR via `clipped()` | `test_documentFallbackTitleIncludesOCRText` |
| FALLBACK-2 | `confidentSubject(from:)` gates titling subject at ≥0.5 | `test_fallbackTitleHedgesWhenTopLabelIsLowConfidence` |
| PERCEPT-2 | `ImagePerceptionService.swift` — extracted `static shouldCountFace(area:confidence:)` | `ImagePerceptionServiceTests` (3 cases) + new file registered in `project.pbxproj` |
| PERCEPT-3 | `OCRCleaner` made internal; `isStandaloneCJK` relaxes both length floors | `test_clean_keepsSingleCharCJKSign`, `test_clean_stillDropsStraySingleLatinChar` |
| PERCEPT-1 | comment-only: corrected the OR-cannot-reject semantics | (covered by PERCEPT-2) |
| **CONSIST-6 (§3 prompt)** | `ImageInsightCore.swift` — portrait prompt forbids a *bare* "Selfie"/"Portrait", keeps the concept usable | (prompt text; not behaviorally testable without the model) |
| **ROUTE-1 (§4)** | `ImageContentTypeClassifier.swift` — horizonless-landscape branch gated on `salientObjectCount == 0 && hasStrongOutdoorClassification (≥0.5)` | `test_horizonlessOutdoorSceneWithNoForegroundReturnsLandscape`, `test_outdoorSceneWithForegroundSubjectStaysObject` |
| **ROUTE-4 (§4)** | added `card`/`license`/`passport`/`id`/`badge` to `documentKeywords` | `test_idCardWithFaceRoutesToDocument` |
| **PROFILE-1 (§4)** | `retryProfile(for: failures)` holds steady for under-specification, tightens for leakage; wired into `AppleIntelligenceInsightsService` | `test_retryProfileHoldsSteadyForUnderSpecification`, `test_retryProfileTightensForLeakage`, `test_retryProfileTightensForMixedFailures` |
| VALID-6 (§4) | **not changed** — left as-is per §4 recommendation (split FPs on legit content) | n/a |

**Not committed** — changes sit uncommitted on the branch alongside the pre-existing quality-pipeline WIP, for review.
