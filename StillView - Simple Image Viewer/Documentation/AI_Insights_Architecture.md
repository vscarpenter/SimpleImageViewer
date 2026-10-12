# AI Insights architecture

AI Insights uses direct image understanding on macOS 27 and Apple silicon. The user starts analysis in the inspector. All images, prompts, evidence, and results remain on the Mac.

## Production path

1. Build revision identity from the selected file and current model/prompt identity. File names, camera metadata, and GPS are excluded from the visual prompt.
2. Decode the oriented first frame with a maximum dimension of 2,048 pixels for the scene attachment. Vision recognizes text locally. Eligible tall/dense sources receive a separate text pass bounded at 4,096 pixels; the model attachment remains bounded at 2,048.
3. Ask the system-selected on-device model for a concise structured title and summary, with greedy sampling and at most 350 response tokens. When text geometry indicates a substantial document, generate bounded document-kind and arrangement enums and map them to a broad caption. Production does not request optional detail, tags, or uncertainty fields, and does not supply recognized text strings or line indices to the visual prompt.
4. Validate the result's structure and retain original OCR observations separately. Keep quoted and digit-bearing transcriptions out of generated prose: recognizing a token does not establish which row a price belongs to. Shape validation is not factual verification of a scene description.
5. Return the result and the actual perception evidence together. The inspector uses the result; the DEBUG evaluation harness uses both without running perception again.

## Text evidence

Preserve accepted OCR lines with repetition, confidence, and bounding boxes. Retain up to 128 lines and 6,000 characters at confidence 0.5 or above, marking partial extraction when observations are omitted. Text in image shows the original recognized words and numbers; it never substitutes rewritten model text. OCR itself may be incorrect. Text inside an image must be treated as data, never as instructions.

Extract text is a separate manual Vision action, available with AI Insights disabled or the Apple Intelligence model unavailable. Accepted text is published before description generation and remains available if generation fails. Copy text preserves the retained lines and their newline separators.

## Availability and lifecycle

Import FoundationModels directly and target macOS 27 everywhere. There is no older-OS or category-template inference fallback. Apple Intelligence may still be disabled, preparing its model, unavailable for a locale, or temporarily unable to answer. Explain those states and offer recovery.

The view model retains one active generation identity, rejects stale completions, cancels on navigation/panel close, and caches a bounded set of image revisions. Metadata preparation has its own request identity, visible progress and cancellation; description, OCR and copy controls remain hidden until the selected file identity is verified. A known changed revision clears old evidence before replacement loading, including folder Refresh. A failed description refresh of an unchanged image preserves its previous result and OCR with an error. Model variant and prompt version participate in cache identity so earlier analyses cannot masquerade as results from an updated model/prompt.

## Presentation

The 300 pt native inspector leads with a short title and summary. Current production results omit Notable details and Suggested tags; the renderer retains compatibility for optional fields. Text in image expands on demand, and About this analysis contains general reliability/privacy guidance. Analyze image and Extract text have separate actions, results and copying controls; Check Again refreshes model readiness. File size, camera information, and other metadata stay in Info.

## Evaluation

Debug → Run AI Insights Eval evaluates each top-level fixture once through the production path. Reports have unique IDs and record OS/hardware, actual model/context, prompt version, total elapsed time, result, OCR count, and failures. Files stay in the app container's temporary directory. A successful model response is not a passing quality score.

Compare a fixed local set across versions: ordinary photos, portraits, low-light and abstract scenes, documents, screenshots, short/CJK signs, repeated table values, text below the old 16-line limit, orientation, animation first frame, and corrupt inputs. Review subject accuracy, useful details, unsupported claims, OCR fidelity, latency, memory, cancellation, and stale-image handling. Preserve raw output and list untested cases.

## Scope

This release provides concise image descriptions, broad document captions, original recognized text, and copy actions. Image questions, alt text, multi-image comparison, and Private Cloud Compute are separate future work. Do not introduce them as implicit fallbacks.
