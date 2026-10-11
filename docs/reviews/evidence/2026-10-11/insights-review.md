# Image Insights review — 2026-10-11

Scope: read-only review of current production sources, inspector integration, test membership, archived evaluation evidence, and a fresh local regression smoke. No app source or project file was changed. No private photographs were searched. Memory was used only for orientation; the current five engine/metadata sources were independently hashed and match the archived v5 source manifest exactly.

## Assessment

The app already has the macOS 27 direct-image architecture the request calls for. It decodes oriented, bounded first-frame pixels; passes the same pixels to Vision OCR and a fresh on-device Foundation Models session; measures supported text/schema/instructions; retries context overflow once without OCR; preserves original retained OCR; and rejects stale/cancelled results. A rewrite to adopt direct image input would duplicate current behavior.

There is real, qualified quality evidence: the archived 30-fixture v5 run produced 29 results, compared with the category-template baseline, and the unblinded ordinal review improved from 25/60 to 53/60 in main-subject coverage and from 23/60 to 53/60 in usefulness. This is a small regression corpus and one unblinded assistant review, not representative accuracy evidence. Warm median service time was 3.55 seconds; the baseline usually did not invoke a model. Current-source SHA256 equality ties those observations to the current engine, but they do not establish current runtime/model quality. Evidence: `docs/evaluations/2026-09-14-macos27-insights/comparison.md:5-22,24-28,59`; `v5-source-sha256.txt:1-5`.

Fresh runtime evidence was collected separately under `/private/tmp/stillview-review-insights-2026-10-11`. Its regenerated corpus has matching dimensions/frame counts for all 30 images and byte-identical fixture hashes for 21/30. The nine differing PNGs include authored Latin text and blur fixtures. Original archived image pixels are not bundled, so byte differences cannot be characterized as encoding-only differences. It must be described as a current regression smoke, not a controlled old/new quality benchmark.

## Actionable findings and proposals

### P1 quality: document guard checks form, not the promised semantic boundary (confirmed limitation)

The prompt explicitly forbids transcribed labels/values, including values rewritten as words, and document-row counting (`Models/ImageInsightCore.swift:200-205`). The validator only rejects literal decimal digits and certain quote pairs (`Services/InsightOutputValidator.swift:62-75`). Plain labels and number words therefore pass. The matching archived production run demonstrates both: receipt title `Receipt from NORTH MARKET` and table detail `The total quantity is three items.` (`docs/evaluations/2026-09-14-macos27-insights/v5.jsonl:20,28`). The comparison acknowledges the table value leak at `comparison.md:42-43`. This is not evidence of general factual verification, and the code comment correctly says shape checks do not establish accuracy.

Impact: a user can mistake generated document relationships/counts for extracted source text. The current digit/quote guard prevents a useful subset of transcription mistakes, but does not enforce the complete prompt contract.

Recommended direction: constrain the document output to kind/layout, keep exact text independent, and evaluate removing OCR from the *description* prompt for documents. If document Q&A/table understanding is added later, use an explicit evidence-citation contract and a separate evaluation rather than relaxing this boundary silently. Do not attempt a general semantic guarantee with a number-word blacklist; it would reject legitimate object counts and still miss language variants.

Falsification: add current-validator cases `The total quantity is three items.` and `Receipt from NORTH MARKET`; both currently pass. In a fresh document corpus, count unsupported value/relationship claims separately from subject coverage. Require zero such claims for the bounded description mode before claiming this is fixed.

### P1 usability: successful OCR is discarded when the model or output validation fails (confirmed behavior; product improvement)

OCR succeeds before model inference (`Services/AppleIntelligenceInsightsService.swift:75-79`), but `ImageInsightAnalysis` is returned only after model completion and validation (`:92-100`). A refusal/error throws without exposing perception. The initial-failure UI displays only a failure message (`Views/InspectorView.swift:429-430,489-499`); full recognized text is rendered only inside a successful result (`:515-538,566-607`). The eval harness similarly records `perception: nil` on errors (`Services/InsightEvalHarness.swift:90-94`). The archived adversarial-text screenshot is a genuine refusal, not an empty-OCR success (`v5.jsonl:18`).

Impact: reading/copying text depends on an unrelated language-model success. A screenshot with usable OCR can lose all text utility because the model declines to describe it; Apple Intelligence unavailable/disabled also blocks the current route to text extraction.

Recommended direction: introduce independent OCR state, disclose recognized text as soon as it is available, and preserve it after model refusal/timeout/invalid prose. Keep model failure honest; do not synthesize a fake AI result. An explicit Extract text action can work when Apple Intelligence is unavailable while retaining current user-controlled initiation.

Falsification: inject successful OCR plus a refusing response generator and assert retained OCR/copy availability despite failed description. Separately test no OCR, Vision failure, cancel during OCR, AI disabled, and image navigation so text from an earlier image cannot persist.

### P2 usability/performance: Insights input construction performs synchronous metadata/file work on every image selection (confirmed blocking path; latency unmeasured)

`ImageViewerViewModel` is a main-actor object; `loadCurrentImage` calls `prepareImageInsightForCurrentImage` before starting the asynchronous image loader (`ViewModels/ImageViewerViewModel.swift:7-8,554-577`). Input preparation calls `insightInputProvider(imageFile)` regardless of whether Insights is enabled or the inspector is visible (`:514-532`). The default provider performs file-stat operations and full `ImageMetadataService.extractMetadata` synchronously (`Services/AppleIntelligenceInsightsService.swift:29-48`), which opens ImageIO sources and parses EXIF/GPS/keywords even though only dimensions/profile are retained (`Services/ImageMetadataService.swift:166-211`). App activation and inspector open perform it again (`ViewModels/ImageViewerViewModel.swift:186-191,875-879`).

Impact: slow/network-backed/iCloud file metadata can stall browsing before visible image loading begins, even with Insights off. This is a confirmed synchronous I/O path, not yet a measured frame-time regression.

Recommended direction: make revision preparation lightweight, defer/offload descriptive metadata, avoid full EXIF/GPS extraction for AI input, and reuse already-loaded metadata for the same revision. Retain freshness checks before generation and publication. Gate optional work by actual Insights demand without making cache invalidation dependent on inspector visibility.

Falsification: inject a slow input provider; rapid Next should not block the main actor after the refactor. Profile a locally cached file and a network/cloud file with Insights disabled/enabled, recording time-to-next-image and main-thread stalls rather than only model duration.

### P2 OCR fidelity: bounded scene preview is also the only OCR input; low-confidence omissions are invisible (confirmed design limits; quality gain requires evaluation)

Both model and OCR use the same maximum-2048-pixel thumbnail (`Services/ImagePerceptionService.swift:75-78,89-102,153-158`). A long receipt/tall screenshot therefore loses small-text resolution globally. The cleaner silently filters observations below confidence 0.5; only line/character-budget omission sets `textWasTruncated` (`:48-71`). The full text disclosure is absent for empty OCR (`Views/InspectorView.swift:566-607`). The archived isolated numeral produced no Vision candidate, and single CJK glyph produced a rejected low-confidence candidate (`comparison.md:41`). Preserving accepted OCR exactly is valuable, but does not mean complete/accurate OCR.

Recommended direction: keep bounded scene pixels for inference, experiment with a separately budgeted higher-resolution/tiled text pass for tall documents, preserve original position/confidence per observation, and display an explicit no-text/partial-text status. Report discarded-count/coverage reasons without presenting low-confidence guesses as verified transcription. Do not deduplicate repeated numeric values or merge rows until ordering/association is tested.

Falsification: scale the existing receipt to phone-scan dimensions and add dense, multicolumn, rotated, low-contrast, Arabic/CJK mixed, and isolated-symbol fixtures. Compare character/word error rates, reading order, accepted/rejected counts, memory and cancellation. Current Vision observation order is not reconstructed row/column order (`comparison.md:40`).

### P2 quality/latency: model is asked to choose OCR highlights that the inspector never uses (confirmed redundant output)

The schema generates up to three `selectedTextLineIndices` (`Services/AppleIntelligenceInsightsService.swift:244-245`); prompt construction includes indexed OCR positions (`Models/ImageInsightCore.swift:203,208-225`); the validator resolves them to `selectedTextLines` (`Services/InsightOutputValidator.swift:35-57`). The inspector renders only all `recognizedText`, not selected excerpts (`Views/InspectorView.swift:534-537,566-607`). An empty selection described as valid/optional in prompt/schema is treated as invalid and replaced with the first three OCR lines (`Services/InsightOutputValidator.swift:7-12,39-41`). This is unused internal behavior, not a visible excerpt bug today.

Recommended direction: remove unused selection generation/result plumbing, or give highlights a defined user task. If removed, version the prompt/schema and re-evaluate quality/token/latency impact; do not assume a smaller schema automatically improves quality. Plain photo analysis may also need no OCR tokens when text extraction is independent.

Falsification: prove no production consumer uses selected excerpts; compare current vs reduced schema on a fixed corpus while checking full OCR retains repeats, order and exact strings. Verify nil/empty selections remain empty if they continue to exist.

### P2 evaluation: archived evidence is candid but coverage is narrow; no general quality promise is supported

The archival corpus is 14 landscape/product repository photographs and 16 synthetics, with one unblinded reviewer. Portraits, pets, RAW/HEIC, wide-gamut correctness, the smaller Core 3 model, memory pressure and long cache sessions were not established (`comparison.md:59`). It already records wrong circles/ovals, relative sizes, left-aligned text called centered, movement inferred from still pixels, repetitive detail, and low-value uncertainty (`:45-51`). All 29 successful v5 responses still included a detail despite its schema being normally nil (`docs/reviews/2026-09-14-macos27-insights-implementation.md:44`). This demonstrates room for better quality but not that a speculative prompt change is an improvement.

Recommended direction: create a versioned scorecard with independently checked subject accuracy, salient detail usefulness, unsupported claim count, meaningful uncertainty, text fidelity, refusal/success, and stage timings. Use normal photos people actually browse, with consent and local-only storage, plus difficult formats. Retain the regression set. Evaluate prompts/models blind where practical; set an explicit quality acceptance threshold, not just a response-success threshold. Profile decoding/OCR/token-budget/model stages independently before optimizing cold/warm latency.

Falsification: same source/OS/model, same pixels and randomized paired outputs; separate semantic-quality scores from OCR and timing; retain every failure and raw response. A successful unit suite or fresh 30-image smoke does not prove quality gain.

## Lifecycle, availability and privacy that should be preserved

- UUID plus input identity prevents cancelled/old completions from publishing (`ViewModels/ImageInsightViewModel.swift:72-99,103-115`). Results cache is bounded (20 by default) and least-recently-viewed; prior revisions of the same URL are discarded (`:19-22,134-154`). Tests cover revision changes, late cancellation/failure, cache eviction and model/prompt identity changes.
- A failed/cancelled refresh preserves the previous result and explains failure (`ViewModels/ImageInsightViewModel.swift:90-98,122-131`; `Views/InspectorView.swift:425-427,502-512`). Navigation and leaving the Insights inspector cancel model work (`ViewModels/ImageViewerViewModel.swift:875-879`). Do not replace these protections while improving presentation.
- File identity uses URL, size, modification time plus model display name/context and prompt version (`Models/ImageInsightCore.swift:3-14`; `Services/AppleIntelligenceInsightsService.swift:64-85,137-143`). Same-size timestamp-preserving replacement or an in-place model update with the same public display name/context could evade this heuristic. This is an unverified edge case, not a demonstrated stale-result bug. Add a file-identity/change-token strategy only if the target workflows require it; test timestamp-preserving swaps before severity claims.
- Model readiness checks remain useful even on macOS 27 (`Services/AppleIntelligenceInsightsService.swift:56-61,146-155`). Context, locale, timeout, unsupported-capability and refusal recovery are explicitly mapped (`:114-134`). Current locale failure UI explains the cause but offers only generic retry; actionable system-settings recovery and an availability retry action would improve usability.
- Generation is fresh on-device Foundation Models with bounded image attachment (`Services/AppleIntelligenceInsightsService.swift:200-214`). No network API is present in these services. OCR prompts exclude filenames/EXIF/GPS, although synchronous metadata preparation unnecessarily parses them. DEBUG eval writes original recognized content and file names to local temporary reports by explicit user choice (`Services/InsightEvalHarness.swift:6,47-74,131-160`); app content does not enter unified logs. Copy actions explicitly place text in the system clipboard (`Views/InspectorView.swift:748-758`). No cloud fallback is needed for the requested optimization.

## Test membership and verification limits

Ran the read-only membership checker: `python3 scripts/check-test-target.py` reports 15 app-hosted test sources and all required viewing/Insights suites. Current active project includes `ImageInsightTests`, `ImageInsightLifecycleRegressionTests`, `ImagePerceptionServiceTests`, and `InsightOutputValidatorTests` (`StillView - Simple Image Viewer.xcodeproj/project.pbxproj:736-740`). `InsightEvalHarnessTests.swift` is an intentionally empty, non-member file, not evidence of executable quality tests; its old comment about TEST_HOST being empty is stale (`StillView - Simple Image Viewer Tests/Services/InsightEvalHarnessTests.swift:1-7`). The real harness is DEBUG app source (`project.pbxproj:642`).

Controlled tests cover input races, cancellation, exact OCR, output shape, orientation and context recovery. They mock model generation and therefore cannot validate real image understanding. No full suite/build/app launch was run by this reviewer; root owns those checks. No prompt/model implementation improvement was made in this review.

## Fresh local smoke results

Ran the freshly compiled current production service sequentially on 30 recreated fixtures on macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), AFM 3 Core Advanced with 8,192 context tokens, Mac16,11/48 GiB. Availability was available. User app preferences and Apple Intelligence settings were untouched.

- 28/30 returned a result; all 14 byte-identical repository photographs succeeded.
- `prompt-injection.png` produced the mapped model refusal (0.44s).
- `receipt-long.png` produced invalidGeneratedContent (5.98s). The diagnostic message does not distinguish empty/overlong prose from disallowed digit/quote output; the exact invalid generated response is not retained by this production runner, so its cause is unknown. The recreated receipt hash differs from the archived receipt, so this is not evidence of an OS-only regression. It confirms a current failure on a normal authored receipt fixture.
- Median end-to-end service time 2.78s; range 0.44–17.70s; total 111.61s. Cold first sample (`abstract-shapes.png`) took 17.70s; chart took 15.82s. These uncontrolled timings include file metadata, decoding, OCR, token counting and model completion, and other review processes were running. Do not claim faster model throughput than the prior warm run.
- All 28 successful outputs still include a supplementary detail; 16 include uncertainty. The normally-nil schema/instructions do not reliably suppress filler.
- The byte-identical abstract/orientation fixtures still call a circle an oval; orientation positions are correct but relative size is wrong. A byte-identical blank image still receives an artistic-intent uncertainty, contrary to the prompt guidance.
- The current table still emits `The total quantity is three items.` and CJK sign title repeats source text `東京駅`, confirming word-form/label leakage. The table's exact repeated `$2.00` and quantity-one OCR remain preserved; CJK station/STOP text remain exact. Table hash differs from the old fixture but this is a current observation, not a historical delta.
- The isolated numeral and isolated CJK character still have no retained OCR. The model spells seven from pixels, while exact text remains empty.

Machine-readable raw results and same-pass successful OCR: `/private/tmp/stillview-review-insights-2026-10-11/current-2026-10-11.jsonl`; rendered report: `current-2026-10-11-report.md`; summary: `summary.json`; runtime/source hashes/fixture comparisons: `environment.json`, `current-2026-10-11-source-sha256.txt`, `fixture-hash-comparison.json`. `current-2026-10-11-corpus-checks.json` records narrow checks: overall outcomes, receipt published OCR, isolated numeral/CJK OCR failed; repeated table prices, station/STOP text and selected-excerpt membership passed. A failed result does not retain perception in this runner, so the receipt's failed published-OCR check cannot prove that Vision internally omitted the total.

This was a genuine current-runtime regression smoke using unchanged production inference/perception/validation code and minimal CLI ImageFile/logging adapters. No speculative improvement was implemented or measured. It does not establish app-hosted performance, wide-gamut/HEIC/RAW/portrait/pet quality, VoiceOver or release behavior.
