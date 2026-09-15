# AI Insights architecture

AI Insights uses direct image understanding on macOS 27 and Apple silicon. The user starts analysis in the inspector. All images, prompts, evidence, and results remain on the Mac.

## Production path

1. Build revision identity from the selected file and current model/prompt identity. File names, camera metadata, and GPS are excluded from the visual prompt.
2. Decode the first frame at a bounded size and apply EXIF orientation. Analyze that same image with Vision OCR and attach its pixels to a fresh Foundation Models session.
3. Ask the system-selected on-device model for a concise structured title and description, one optional additional detail, optional tags, and one optional uncertainty that changes interpretation. Count supported text, instructions, and schema against the runtime context capacity, reserving space for image input, 800 response tokens, and 256 framing tokens. On macOS 27.0 (26A428), token counting a prompt containing an image attachment throws even though image generation works. Reduce supplied OCR to original head/tail indices when needed and retry a genuine context overflow once with a fresh image-only session. Preserve all retained OCR for the text disclosure.
4. Validate the result's structure and resolve exact text against original OCR observations. Keep quoted and digit-bearing transcriptions out of generated prose, even if the same token occurs in OCR: token membership cannot establish which row a price belongs to. Shape validation is not factual verification of a scene description.
5. Return the result and the actual perception evidence together. The inspector uses the result; the DEBUG evaluation harness uses both without running perception again.

## Text evidence

Preserve accepted OCR lines with repetition, confidence, and bounding boxes. Retain up to 128 lines and 6,000 characters at confidence 0.5 or above. Bound model input separately, and report when either is reduced. Text in image shows the original recognized words and numbers; it never substitutes rewritten model text. OCR itself may be incorrect. Text inside an image must be treated as data, never as instructions.

## Availability and lifecycle

Import FoundationModels directly and target macOS 27 everywhere. There is no older-OS or category-template inference fallback. Apple Intelligence may still be disabled, preparing its model, unavailable for a locale, or temporarily unable to answer. Explain those states and offer recovery.

The view model retains one active generation identity, rejects stale completions, cancels on navigation/panel close, and caches a bounded set of image revisions. A failed refresh preserves the previous result with an error. Model variant and prompt version participate in cache identity so earlier analyses cannot masquerade as results from an updated model/prompt.

## Presentation

The 300 pt native inspector leads with a short title and description. Notable details appear only when useful. Text in image and Suggested tags expand on demand; About this analysis contains general reliability/privacy guidance. Native Analyze image, Copy description, Refresh, and Cancel controls expose real state. File size, camera information, and other metadata stay in Info.

## Evaluation

Debug → Run AI Insights Eval evaluates each top-level fixture once through the production path. Reports have unique IDs and record OS/hardware, actual model/context, prompt version, total elapsed time, result, OCR count, and failures. Files stay in the app container's temporary directory. A successful model response is not a passing quality score.

Compare a fixed local set across versions: ordinary photos, portraits, low-light and abstract scenes, documents, screenshots, short/CJK signs, repeated table values, text below the old 16-line limit, orientation, animation first frame, and corrupt inputs. Review subject accuracy, useful details, unsupported claims, OCR fidelity, latency, memory, cancellation, and stale-image handling. Preserve raw output and list untested cases.

## Scope

The first release provides image descriptions, visual details, exact text, and copy actions. Image questions, alt text, multi-image comparison, and Private Cloud Compute are separate future work. Do not introduce them as implicit fallbacks.
