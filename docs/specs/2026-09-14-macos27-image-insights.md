# macOS 27 image Insights

Approved by the user on 2026-09-14, following the image-insights review and the successful macOS 27.0 (26A428) Foundation Models probe. This approval covers specification, planning, implementation, and verification.

## Scope
- macOS 27.0+ and Apple silicon; consistent app/project/test/minimum-version metadata, SDK checks, current runtime availability, no older-OS implementation.
- Give the on-device SystemLanguageModel a bounded, oriented image attachment and preserve exact local OCR evidence.
- Generate a concise title, description, notable details, optional tags, and useful uncertainty. Do not use file names, EXIF/GPS, or camera facts as visual evidence.
- Keep one image per model session, request cancellation, revision-aware caching, stale-result rejection, and previous-result retention after a failed refresh.
- Track model variant, context capacity, prompt version, and analysis duration locally. Cache identity includes model/prompt identity.
- Keep the existing inspector and viewer design tokens. Show description first, optional Notable details, expandable Text in image and Suggested tags, a compact limitations disclosure, and native Analyze image/Copy description/Refresh/Cancel controls.
- Preserve OCR words, numbers, repetitions, and positions under an explicit evidence budget. Display limits must not silently destroy evidence. Generated prose and recognized text have distinct provenance.

## Non-goals
Cloud models, external model downloads, chat, alt-text generation, multi-image comparison, image editing, automatic background analysis, OS compatibility branches, distribution or App Store publication.

## Contracts
1. A successful photo result must come from a direct image request; no deterministic category-template fallback is allowed after inference failure.
2. Model availability is checked independently of app preference. Disabled intelligence, preparing model, language restrictions, refusals, and errors remain actionable states on supported systems.
3. Exact text is copied from OCR observations. Structured generation constrains response shape, not factual accuracy.
4. Navigating, canceling, closing the inspector, or replacing a file cannot let an older result overwrite the current image.
5. App source analysis remains on-device. No network model, upload, analytics, or remote fallback is introduced.
6. First-frame rendering, image orientation, bounded decode memory, security-scoped resource access, and cancellation match the viewer's image contract.

## Acceptance
Meaningful engine/validator/lifecycle tests pass against the built app. Debug and Release builds and SwiftLint pass; build metadata reports27.0 and arm64. Compare old/new production paths over local photo and synthetic fixtures, recording model/OS and latency; inspect unsupported claims and exact text fidelity. Verify new controls and generation in the running app. Report quality limitations honestly and keep release/publication separate.
