# Final v10 fixed-corpus review

**Retain final v10.** The final rendering removes the two unsupported broad arrangement claims from v9 while preserving concise photo output and independent OCR. No additional model/code change is requested by this review. These results establish bounded local behavior, not general image-description accuracy.

| Measure | Historical baseline | V9 | V10 |
|---|---:|---:|---:|
| Generated results | 28/30 | 30/30 | 30/30 |
| Photo results / broad subjects covered | 14/14 | 14/14 | 14/14 |
| User-visible exact OCR occurrences | 62/154 | 150/154 | 150/154 |
| Complete OCR content cases | 5/10 | 7/10 | 7/10 |
| Extra literal OCR occurrences | 0 | 0 | 0 |
| Extraction on eight historically observable cases | 62/66 | 62/66 | 62/66 |

**30/30 is completion, not accuracy.** The 88-token delivery gain over baseline is recovered receipt/prompt text after old inference errors. Their old extraction evidence is missing, so underlying recognition improvement cannot be inferred. V9/v10 extraction agrees across all ten readable fixtures.

All 14 photo titles, summaries and optional fields exactly match v9/v8/v7. Photo description words stay at 393 versus the historical baseline's 585, with median 27 versus 41.5. Broad subjects remain useful; no additional photo-accuracy improvement is shown.

Final text-heavy captions are source-supported and intentionally broad:

| Fixture | Final caption |
|---|---|
| Paragraph | A document contains blocks of text. |
| Receipt | A receipt contains blocks of text. |
| Table | A table contains text arranged in a grid. |
| Error text | Text is visible in the image. |
| Prompt text | A document contains text. |

The false v8 centering/line/row counts and v9 wider-scene/visual-element implications are absent. These captions invent no merchant, date, price, item quantity, exact alignment or numeric layout count. Prompt instruction text remains exact OCR content without giraffe/specimen interpretation. Broad captions trade semantic specificity for bounded claims; this is not proof of general prompt-injection resistance.

Table OCR preserves all 15 source cells, including three `1` occurrences, three `$2.00` occurrences, total quantity `3` and `$6.00`. The transcript remains column-major, so correct token recovery does not establish row association.

Independent provenance verification confirms **all five frozen AI pipeline sources exactly match current repository files byte for byte**, and every manifest hash matches, including the runner. [Verification data](final-v10-source-verification.json) records exact paths/hashes and the check time. CLI ImageFile/logging/security-scope adapters differ from production and are documented separately. This verifies source equality; it does not establish binary provenance or full-app integration behavior.

Residual limitations remain: circles described as ovals, falsely centered STOP/東京駅/7, white chart background called black, OCR misses for 7/水/A/B, uncertain water-body/rainbow terminology and uneven photo specificity. Generated tags/details are removed; that is product simplification, not improved tag quality. The factual partial-extraction warning on 水 remains. The separate tall dense OCR resolution probe supports only its fixed-fixture gain and still has substantial errors. This corpus lacks people-focused photos, RAW, HEIC and wide-gamut coverage.

Evidence: `final-v10-comparison.json`, `final-v10-versus-baseline-ocr.json`, `final-v10-versus-v9-ocr.json`, and `final-v10-source-verification.json`. Frozen ground truth and result/source hashes are retained. This review performed no model inference and no repository/app/test edits.
