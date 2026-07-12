# AI Insights Architecture

AI Insights is an accuracy-first, on-device pipeline for macOS 26.

## Platform boundary

The macOS 26 Foundation Models API accepts text prompts, not image pixels. StillView therefore uses
Apple Vision to extract observations and sends only a confidence-gated text representation to Apple
Intelligence. The model is never told that it saw the image.

macOS 27 introduces public image prompts. When the project adopts an Xcode 27 SDK, the preferred
follow-up is to evaluate direct image input and remove the Vision-to-text bridge if it is measurably
more accurate.

## Pipeline

1. `ImagePerceptionService` runs image classification, accurate OCR, and face detection on device.
2. `ImageContentTypeClassifier` separates specific subjects from generic scene hints and drops weak
   observations before they can reach the language model.
3. Weak evidence returns an honest deterministic result without calling Foundation Models.
4. Strong evidence gets one greedy guided-generation pass for a single cautious summary sentence.
5. `InsightOutputValidator` rejects summaries that do not reference evidence or add common unsupported
   details. Titles, likely content, details, tags, and limitations are always deterministic.

File names, dates, camera details, EXIF, GPS, and embedded keywords are never included in the prompt.

## Current evidence gates

- Specific subject labels: at least 65% confidence.
- Scene hints: at least 45% confidence and from the explicit scene-label set.
- Narrative generation: an 80% subject match, a detected face, at least four OCR words, or at least two
  corroborating scene hints whose strongest match is at least 55%.
- OCR: at least 50% confidence, deduplicated, maximum 16 lines.
- Face detections: minimum area and confidence, with a stricter high-confidence path for small faces.

These thresholds intentionally prefer an incomplete result over a wrong one.

## Evaluation

The Debug menu's AI Insights evaluation command runs the production pipeline over a selected folder and
writes a Markdown report. Evaluate a mixed set of photos, screenshots, documents, portraits, low-light
images, abstract images, and deliberately ambiguous inputs before changing evidence thresholds.
