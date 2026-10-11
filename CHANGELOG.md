# Changelog

## 5.1.0 (45)

- Browse a folder and its subfolders together with View > Include Subfolders, a collapsible folder tree filter, and filename or path search.
- Extract and copy text with Vision even when AI Insights is off or Apple Intelligence is unavailable; recognized text survives a failed description.
- Restore the last folder, selected image, sort order, subfolder scope, folder filter, and search on relaunch.
- Add Refresh Folder (⌘R), which rescans while keeping the selected image.
- Move by row in Grid with Up and Down, show a selection outline, and open the selected image with Return.
- Stream folder discovery in cancellable batches and share one bounded thumbnail pipeline.
- Shorten AI descriptions and add a higher-resolution OCR pass for tall documents.
- Keep recent folder bookmarks paired with their URLs, including folders that are temporarily unavailable.
- Label creation-time sorting Date Created and apply the chosen sort to every loaded snapshot.

## 5.0.0 (44)

- Require macOS 27 and Apple silicon, with no older-OS compatibility path.
- Describe image pixels directly with Apple's on-device model, including concise visible details and optional suggested tags.
- Read and copy original OCR text with repeated and later lines preserved under an explicit evidence budget.
- Add native Copy description and Refresh actions while preserving cancellation, cached image revisions, and prior results after refresh errors.
- Record model and prompt provenance in local evaluation reports and cache identity.
