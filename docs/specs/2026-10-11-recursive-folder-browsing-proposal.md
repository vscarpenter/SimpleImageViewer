# StillView: browse images across subfolders

Proposal prepared October 11, 2026 from current code at `9da3f3f`. **Approved October 11, 2026:** implement usability and description/OCR improvements first, then recursive browsing with all images together and a folder tree; verify and commit. Companion: [comprehensive review](../reviews/2026-10-11-comprehensive-macos27-review.md). Implementation and verification are recorded in [the plan](../plans/2026-10-11-macos27-usability-and-browsing.md).

## Outcome

Choose a parent folder once and browse supported images from that folder and all ordinary descendant folders. Keep Single, Strip, Grid, keyboard navigation, Info, and selected-image Insights. A folder filter narrows the discovered collection without reopening the picker.

User preference confirmed October 11: **all images together, with a folder tree for filtering**. Deliver one combined collection and a collapsible native folder tree together as the completed feature. Grouped sections can be a later display option. Preserve current shallow behavior until Include subfolders is explicitly enabled.

The companion Insights work prioritizes more accurate descriptions and text recognition. Folder discovery and filtering must not trigger bulk image analysis; selected-image descriptions and independently available OCR retain their existing local privacy boundaries.

## Experience

```text
Photos ▾    Include subfolders ✓          Single | Strip | Grid     Inspector

Folders                  All images · 426 images                 Info | Insights
All images (426)          Filter by filename or folder…
Photos (12)               [ image ] [ image ] [ image ] [ image ]
  Travel (260)            IMG_001.jpg        IMG_001.jpg
    Italy (180)           Travel/Italy       Family/Birthday
    Japan (80)
  Family (154)            Finding more images… 426 found           [Cancel]
    Birthday (36)

                         Selected: Travel/Italy/IMG_001.jpg
```

This is a layout sketch, not a screenshot. Use the existing viewer palette, type and native control treatment. Keep the image central; use small metadata captions and standard source-list rows. Avoid turning folders or inspector sections into decorative cards.

- **Include subfolders** is a browsing scope, visible in the folder menu/toolbar and available in a scene-focused View command. Display “This folder” or “Including subfolders” so the active collection is clear. Save the scope with the folder session, not as an unexplained global switch.
- **All images** includes root images and discovered descendants. The tree is included in the feature, can be collapsed, and has an explicit “All images” row. Selecting a folder filters to that branch and its descendants; its count is a subtree count. Explain that behavior in help. Use separate scope selection for a future direct-only filter rather than ambiguous counts.
- **Duplicate names** remain separate files. Show a relative folder caption in recursive Grid mode and the full relative path in hover/accessibility/Info. Keep full filenames, including extensions, available.
- **Selection** belongs to the file identity, not the array index. Sort changes, tree updates and scan batches preserve the selected file. If a filter hides it, choose the first visible item and announce the change. If removed, select the nearest surviving neighbor. Counts describe the filtered view.
- **Search** matches filename and relative folder path. It does not generate AI tags for every image. Search/filter use the existing index, and should not restart enumeration or discard progress.
- **Discovery** begins showing images as they arrive. Say “426 images found · scanning…” rather than guessing a percentage. Counts are provisional until completion. One Cancel control stops further work; already discovered images remain browsable and are marked incomplete until Resume/Refresh.
- **Empty state** distinguishes “No images in this folder; include subfolders” from “No supported images in this folder tree” and “No matches.” The last offers Clear filter.
- **Partial access** shows a usable collection plus “Some folders could not be read” and a details/retry action. Root access failure has an explicit reopen/reauthorize action. Do not convert a disconnection into an empty success.

## State ownership

Use a window/session-owned browsing model. Shared decode/thumbnail/Insights services can be app-wide; root URL, bookmark grant, scan generation, scope, folder filter, sort, selected file, and discovered snapshot belong to the browsing session. Menu commands resolve the focused session.

Keep three concepts separate:

| Concept | Responsibility |
| --- | --- |
| Root grant | The user-selected root URL and security-scoped access lifetime. |
| Discovered collection | Stable file/folder records plus revisions, partial errors and scan state. |
| Visible collection | Filtered/sorted projection and selected identity; drives Grid/Strip/Single consistently. |

Do not make every tree click a new root or another security bookmark. The chosen root grant must cover authorized descendants and stay active until scanning/loading workers have finished. Store recent URL/bookmark data together in ordered records rather than parallel arrays.

## Scanner contract

Refactor the active `DefaultFileSystemService` path; do not use the dormant `FolderScanner` stub. Introduce a testable scan-options value rather than adding loosely related Booleans. Suggested responsibilities:

```text
Scan options:
  scope: direct children | descendants
  hidden files: excluded
  packages: excluded
  symlinks/aliases: skipped

Scan events:
  folder discovered
  image batch discovered
  recoverable subtree error
  completed
  cancelled
  root unavailable
```

An async event stream or equivalent existing service abstraction should deliver bounded batches. Enumerate on a background worker with cancellation checks between entries. Throttle/batch publication to the main actor; avoid rebuilding/sorting the entire growing array after every file. An implementation experiment can start with small fixed batches, but batch size and worker count should be tuned from measurements.

Use prefetched URL resource values for filtering and lightweight metadata. Do not decode full images or parse EXIF/GPS merely to enumerate. Child folder records can appear before their final counts are known. If a parent has no direct images but descendants do, it is a valid collection.

Only the active generation can publish. Canceling/root changes must signal the worker, not only hide progress. Hold the grant while an in-progress operation completes; release it after the worker exits and no dependent viewer request remains.

## Traversal policy

| Case | Proposed behavior |
| --- | --- |
| Ordinary descendants | Include supported regular image files at every depth. |
| Hidden files/folders | Skip by default, matching existing behavior. |
| Packages/bundles | Skip descendants of `.app`, `.photoslibrary`, and other packages using resource metadata / package-aware enumeration. Do not treat a Photos library as an ordinary image folder. |
| Symbolic links and aliases | Skip by default. Do not traverse outside the selected root or follow cycles. A future follow-links option needs an explicit containment policy and tests. |
| Duplicate leaf names | Keep each relative path as a separate image. Do not deduplicate by name or image content. |
| Unreadable child | Report a partial error; continue with other branches. |
| Unreadable root | Stop with an unavailable/reauthorization state; retain the prior usable collection during refresh. |
| File removed during enumeration | Skip the disappeared entry and reconcile later; do not fail all siblings. |
| Corrupt supported image | Include a lightweight record if metadata permits; show a per-image decode error and let navigation continue. |
| Cloud placeholder | No blanket download of all full-size images for indexing or AI. Handle provider hydration/errors explicitly when thumbnail/full image is requested. |
| Network/external drive | Cancellable work, clear disconnected state, and retained last-known snapshot; validate on real providers. |

The current production probe enters `Sample.app/Contents/Resources` when recursive scanning is enabled. Package exclusion is therefore required before exposing that switch. The probe's omission of one external symlink does not establish a general link policy.

## Identity, sorting, thumbnails, and Insights

- Replace random per-scan UUID navigation identity with a stable file identity. A normalized authorized URL can be an initial key; resource identity is preferable when rename/move continuity is supported. Preserve the original scoped URL for access and test canonical path aliases. Canonicalization must not weaken root containment.
- Keep content revision separate from identity. A revision change invalidates main image, thumbnail, metadata and Insights together. Timestamp/size heuristics have limits; test same-path replacement and introduce stronger change tokens if the intended workflow needs them.
- Apply the selected comparator to every snapshot. For equal sort values, use relative path as a deterministic tie-breaker. Name sorting uses natural filename order, followed by relative path. “Date Created” uses filesystem creation time; capture sorting is later work.
- Use the shared bounded thumbnail scheduler proposed in the review. Queue only visible/prefetch demand, deduplicate in-flight requests, and release/cancel demand as tiles disappear. Test responsiveness during large scans plus rapid scrolling.
- Run Insights only on explicit user request for the selected image. Recursive discovery must not trigger collection-wide OCR/model inference. Keep completed result caching bounded, revision-aware, and local.
- Persist root, scope, filter, sort and selected identity. Expanded tree branches can be ephemeral per-window state. Migration should recover existing shallow sessions safely.

## Folder changes

First delivery should include Refresh Folder. When refresh runs, retain the usable snapshot and selection until reconciled results arrive. Watcher support follows through a root-tree mechanism such as FSEvents, rather than one filesystem descriptor per folder. Filesystem events are hints: reconcile snapshots, debounce bursts, rescan after dropped events, and handle moved/deleted roots.

Start monitoring before the initial scan or reconcile changes around scan completion to avoid a scan/watch gap. Cancel watchers with the session and never let a former root publish into its replacement. Verify access remains scoped under the chosen mechanism. [Apple FSEvents programming guidance](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/Introduction/Introduction.html).

## Acceptance tests

| Area | Required evidence |
| --- | --- |
| Scope and tree | Root + multiple depths included; root with no direct images works; direct mode remains direct; selected scope survives reopening; folder tree is present and collapsible; branch selection filters the discovered collection without another picker or scan; All images restores the combined view. |
| Traversal | Hidden/package exclusions; regular-file check; in-root/external symlinks, aliases, cycles; inaccessible child versus root; root renamed/moved. |
| Cancellation | A pre-canceled scan does no enumeration; cancel stops subsequent entries; already discovered images remain usable; late batch cannot replace a new root. |
| State | Duplicate names stay distinct; deterministic sort ties; selected file survives batches/sort/refresh; filter clears/replaces selection predictably; reopen restores identity. |
| Rendering | Real row-aware keyboard use; visible focus; Return; VoiceOver tree/grid activation and counts; relative paths readable at narrow widths; inspector does not crowd the image. |
| Revisions | Same-path edited image updates thumbnail/stage/metadata/Insights together; no stale OCR or description; corrupt siblings remain navigable. |
| Access | Real sandbox root grant across descendants and relaunch; cancellation releases access after worker exit; explicit write reauthorization before Trash when needed. |
| Scale | Synthetic 1k/10k/100k metadata entries plus representative actual image folders. Measure first usable image, main-thread stalls, cancellation work, thumbnail hit rate and decoded-memory peak. |
| Providers | Local disk, external volume, cloud placeholders, SMB; hydrate/read failures and removal during scan. |

Use controlled enumerator/service tests for deterministic cancellation and partial errors; app-hosted tests for session/selection; real native walkthroughs for keyboard, accessibility and signed sandbox behavior. Add test sources through Xcode, not manual project-file edits.

## Implementation sequence after design approval

1. Write red regression tests for sort/identity persistence, active scanner cancellation/package policy, and recent-folder bookmark associations; implement the foundation fixes in small commits.
2. Introduce scan events and session scope. Deliver Include subfolders, incremental combined results, real Cancel/partial states, relative paths, and Refresh Folder. Keep existing viewing modes stable.
3. Add the collapsible native folder tree and filename/path filter using the discovered index. This is required before calling the requested browsing feature complete; a combined grid alone is an intermediate implementation stage. Complete grid focus/row navigation and menu command parity.
4. Add shared thumbnail revision/scheduling behavior, then root-tree reconciliation. Measure and tune against the fixed scale/provider matrix.
5. Complete tests/lint/build, native accessibility/appearance checks, and signed sandbox walkthrough. Record performance and limitations. Commit each verified stage; report hosted CI separately.

Design approval should cover the spec → plan → implementation pass continuously, with TDD, verification and frequent commits as requested. No additional spec/plan approval gates are proposed.
