# AI Insights v12 — Sample Audit

**Purpose.** Quality-verify the rewritten AI Insights pipeline against a diverse,
real-image sample before committing the v12 plan in Phase 6. Catches PRIMARY/
SECONDARY/CONTEXT ranking failures, anti-pattern leakage (camera metadata as
title, etc.), hallucinations, and dishonest limitations text.

**Status.** SCAFFOLD — fill in during Phase 4 audit, do not commit empty.

**Architecture under test.** Six-file system: `ImagePerceptionService` (Apple
Vision: classification ≥0.5 top-3, OCR, face detection, saliency, horizon) →
`AppleIntelligenceInsightsService` (Foundation Models, on-device, `@Generable`
+ `@Guide` constraints) → `ImageInsightPanelView` (six result sections: title,
summary, likely content, useful details, tags, limitations).

---

## How to run the audit

1. Build & launch Release: `xcodebuild ... -configuration Release` (or
   Product > Scheme > Edit Scheme > Run > Build Configuration: Release in
   Xcode), launch the app, point it at a folder of test images.
2. For each image: open the AI Insights panel, click **Generate Insight**,
   wait for completion, paste the six output fields verbatim into the per-
   image section below.
3. Score against the per-image rubric. Note time-to-generate ballpark.
4. Fill in the **Aggregate Findings** section last; decide
   pass/block/iterate based on the Pass/Fail Criteria at the bottom.

---

## Coverage matrix

Target ≥30 images, ≥2 per category. Mark images "DONE" as they're audited.

| # | Category | Target | Done | Notes |
|---|----------|--------|------|-------|
| 1 | Landscape / nature (outdoor, no people) | 3 | 0 | |
| 2 | Portrait / person(s) (close-up faces) | 3 | 0 | |
| 3 | Street / urban scene | 2 | 0 | |
| 4 | Document / receipt / page of text (OCR-rich) | 3 | 0 | |
| 5 | Screenshot (UI / app / web page) | 2 | 0 | |
| 6 | Food | 2 | 0 | |
| 7 | Product / object | 2 | 0 | |
| 8 | Animal / pet | 2 | 0 | |
| 9 | Abstract / artistic | 2 | 0 | |
| 10 | Event / group (multiple people) | 2 | 0 | |
| 11 | Low-light / night | 2 | 0 | |
| 12 | Macro / close-up object | 2 | 0 | |
| 13 | Sparse-visual edge case (blurry, mostly-empty, solid color) | 3 | 0 | |
| **Total** | | **30** | **0** | |

---

## Per-image audit template

Duplicate this block per image audited. Index from 1.

### Image 01

- **Filename:**
- **Category:**
- **Ground truth (what's actually in the image, written by reviewer in 1–2 sentences):**

**Generated insight (verbatim from panel):**

- **Title:**
- **Summary:**
- **Likely content:**
- **Useful details:**
- **Tags:**
- **Limitations:**

**Rubric:**

| Check | Result | Notes |
|-------|--------|-------|
| Visual signals drove PRIMARY evidence (not camera/EXIF) | Y / N | |
| Title/subject grounded in visuals, NOT in camera metadata | Y / N | |
| If visual signals were sparse, limitations says so honestly | Y / N / N/A | |
| No hallucinated specifics (invented text/people/places) | Y / N | List any |
| Tags reference visual content (not camera make/model) | Y / N | |
| Accuracy of overall description (1–5) | | |
| Time to generate (rough, seconds) | | |

**Reviewer comments:**

---

### Image 02

[copy template above]

---

## Aggregate findings

Fill in after all per-image entries are complete.

### Headline numbers

- Total images audited: __ / 30
- Median accuracy score: __ / 5
- Hallucination rate (images with any invented specifics): __ %
- Camera-metadata-as-title rate: __ %

### Anti-pattern occurrence rates

| # | Anti-pattern | Count | % of sample |
|---|--------------|-------|-------------|
| 1 | Camera metadata appears in title (e.g., "iPhone 13 Pro Max Capture") | | |
| 2 | GPS coordinates appear in subject/title | | |
| 3 | Filename used as title without visual grounding | | |
| 4 | Camera/EXIF facts dominate likelyContent or summary | | |
| 5 | Hallucinated specifics (text, people, places not in image) | | |
| 6 | Limitations section silent despite sparse visual signals | | |
| 7 | Tags reference camera make/model instead of visual content | | |
| 8 | Generic filler ("this is a photograph") instead of substance | | |

### Failure-mode patterns

Free-form: any clusters? E.g., "all low-light photos hallucinated subject", "all
OCR-rich documents had useful details but wrong title", etc. Document the
patterns, not just the counts.

### Success patterns

Where did the pipeline shine? Concrete examples worth preserving (could become
test fixtures).

### Surprises

Anything unexpected — model behaviors, latency outliers, panel UX issues.

---

## Pass / Fail criteria

| Criterion | Threshold | Result |
|-----------|-----------|--------|
| Any single anti-pattern rate | < 10% | |
| Median accuracy | ≥ 3.5 / 5 | |
| Hallucination rate | < 15% | |
| Camera-metadata-as-title rate | < 5% | |

**Decision:** PASS (proceed to Phase 5) / ITERATE (specific prompt/perception
fixes needed) / BLOCK (architectural rework needed)

**If ITERATE:** list specific changes to make and re-audit subset.

---

## Sign-off

- Auditor:
- Date:
- App version / commit SHA at audit time:
- macOS version / Apple Intelligence enabled:
- Decision:
- Next phase:
