# Local evaluation evidence

Start with [comparison.md](comparison.md). Raw JSONL contains one run header and one record per image. Raw records and source-hash manifests are copied without changing their contents. Rendered Markdown reports are normalized to one final newline. The file `failed-v3.jsonl` intentionally retains its original run label `new`; its header points to `new-source-sha256.txt`.

- `fixture-manifest.json`: image hashes, dimensions/frames, expected features and exact authored fixture text.
- `environment.json`: runtime/toolchain and hardware family; no device identifiers.
- `manual-scores.json`: final comparative ordinal rubric and every image's review notes.
- `*-corpus-checks.json`: narrow outcome/OCR checks. A failed run has no published result, so its OCR checks cannot establish internal retention; the receipt's v4 diagnostics supply that separate evidence.
- `diagnostics/`: only the four key text logs establishing the attachment-token-count failure, successful text-only diagnostic usage, two v4 rejected descriptions, and raw single-character OCR limits. Diagnostic snapshots are not claimed as final production.
- `scripts/`: small reproducibility tools; no executables, frameworks, screenshots, or fixture images are bundled here.

## Reproducing the corpus and runner

These scripts preserve the exact original run setup and contain hardcoded `/private/tmp` paths. Review/update those paths before reuse. They assume:

1. `/private/tmp/stillview-macos27-baseline` contains the frozen pre-change source and repository marketing sample photos. Use the source-hash manifests to verify a proposed reconstruction; a Git SHA alone may omit the initial dirty edits.
2. `/private/tmp/stillview-macos27-evidence` contains the script copies, and `/private/tmp/stillview-macos27-eval` is the fixture output folder.
3. Python 3 with Pillow is available. The generator uses the macOS Arial and Hiragino system fonts. Different font versions can change fixture hashes; compare with `fixture-manifest.json`.
4. Xcode is at `/Applications/Xcode.app`; the compile script explicitly selects its macOS SDK and FoundationModels macro plugin. The ordinary selected Command Line Tools compiler lacks that plugin path.
5. Compilation and live inference have the user's required local sandbox permissions. Use sequential model requests. Images remain local.

`compile-runner.sh SOURCE_ROOT LABEL [EXTRA_SOURCE_FILES...]` accepts the source tree and label. It records exact compiled sources and selects the old or new runner API automatically. The baseline also compiles its classifier; the new pipeline omits it when deleted. The only stubs are ImageFile URL/type/size construction and silent logging; analysis uses genuine production code.

Example after placing the scripts in their recorded location:

```sh
python3 /private/tmp/stillview-macos27-evidence/create-fixtures.py
bash /private/tmp/stillview-macos27-evidence/compile-runner.sh SOURCE_ROOT fresh-label
/private/tmp/stillview-macos27-evidence/fresh-label-runner /private/tmp/stillview-macos27-eval /private/tmp/stillview-macos27-evidence/fresh-label.jsonl fresh-label
python3 /private/tmp/stillview-macos27-evidence/render-report.py fresh-label
python3 /private/tmp/stillview-macos27-evidence/check-evidence.py fresh-label
```

Never overwrite a recorded run label when evaluating changed source. The runner writes each result immediately to JSONL, preserving completed evidence if interrupted. Latency is elapsed service time including metadata, decoding, OCR, and generation; it excludes compilation.

Native inspector verification is outside this CLI evidence and remains pending user approval for app launch. See the implementation task for independent build/app-hosted test results.
