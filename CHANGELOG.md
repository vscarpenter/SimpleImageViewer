# Changelog

## 5.1.0 (45)

- Browse a folder and its subfolders together with View > Include Subfolders, a collapsible folder tree filter, and filename or path search.
- Extract and copy text with Vision even when AI Insights is off or Apple Intelligence is unavailable; recognized text survives a failed description.
- Restore the last folder, selected image, sort order, subfolder scope, folder filter, and search on relaunch.
- Add Refresh Folder (⌘R), which rescans while keeping the selected file when it remains available.
- Move by row in Grid with Up and Down, show a selection outline, and open the selected image with Return.
- Stream folder discovery in cancellable batches and share one bounded thumbnail pipeline.
- Shorten AI descriptions and add a higher-resolution OCR pass for tall documents.
- Keep recent folder bookmarks paired with their URLs, including folders that are temporarily unavailable.
- Label creation-time sorting Date Created and apply the chosen sort to every loaded snapshot.
- Keep a scan stuck on slow network I/O from delaying the next folder by more than a second.
- Keep the View menu and toolbar Include Subfolders controls in agreement after a canceled scan.
- Copy Image reads and encodes off the main thread; worker access checks cache each folder's resolved path.
- Name the open-folder command Open Folder… everywhere, link stillviewapp.com from Help and About, and list every menu shortcut in Help.
- Keep trashed images out of older scan snapshots, and prevent superseded scans from reopening the previous folder.
- Save read-write folder bookmarks and avoid mounting disconnected volumes when restoring recent-folder bookmarks at launch.
- Skip stale description/OCR input after an external image edit triggers a reload, clarify failed descriptions, and add Check Again when the on-device model is preparing.
- Apply folder sidebar selections after the current view update, and discard a pending selection if its root folder has changed.
- Let Open Folder… and Back to Folder Selection reopen a hidden main window when no browsing scene is focused.

- Preserve unresolved legacy folder grants for safe retry; keep recovered grants through concurrent recent-list edits and respect explicit removal.
- Resolve and validate automatic saved sessions off the main actor without mounting volumes; cancel queued or in-flight restoration on explicit navigation.
- Disable image, subfolder and refresh commands on Folder Selection while retaining the saved collection.
- Invalidate previous description/OCR before externally changed pixels reload, including Refresh Folder; make image preparation cancelable and reject stale completions.

## 5.0.0 (44)

- Require macOS 27 and Apple silicon, with no older-OS compatibility path.
- Describe image pixels directly with Apple's on-device model, including concise visible details and optional suggested tags.
- Read and copy original OCR text with repeated and later lines preserved under an explicit evidence budget.
- Add native Copy description and Refresh actions while preserving cancellation, cached image revisions, and prior results after refresh errors.
- Record model and prompt provenance in local evaluation reports and cache identity.
