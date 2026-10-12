# PR 27 Codex review follow-up

Checked the completed Codex code and security review summaries for `272d1196cfb27635b606ede766468cb75414e26b`. The PR contained one published code finding and no published security finding. The code finding was verified against the current welcome-screen, toolbar and view-model callers before implementation.

## Confirmed finding and correction

The [P2 review thread](https://github.com/vscarpenter/SimpleImageViewer/pull/27#discussion_r4249778905) identified explicit folder choices that bypassed startup restoration cancellation. The welcome button, context menu and recent-folder tiles called the picker directly. If startup provider validation finished before the chosen folder's first scan publication, the old folder could win.

Fixed in `da2f495763837e9ce4063aa57353e9ab29229e0c`. `ContentView` initializes its picker StateObject with a callback bound to its exact restoration manager. The picker records explicit intent in both public selection entry points, before picker filesystem/presentation work and before recent-folder resolution or scanning. This also covers toolbar and empty-state choices. A duplicate request for an already open picker does not notify again. Automatic restoration, Refresh and subfolder rescans retain their existing paths.

## Verification

| Check | Result |
|---|---|
| Behavioral RED | Release compiled; 11 restoration tests ran with four expected assertion failures |
| Focused GREEN | 39 restoration, folder-presentation and viewing-lifecycle tests passed |
| Full app-hosted Release suite | **340 passed, zero failures, zero skipped**, no test runtime warnings |
| Normal Debug build | Passed |
| Unsigned Release archive | Passed |
| SwiftLint | Zero serious violations; one existing complexity warning |
| Test membership and whitespace | All 15 active test sources and `git diff --check` passed |
| Independent source review | All live explicit callers reach the callback; no remaining concrete findings |

Five additional regressions hold provider validation open while exercising picker intent/cancellation, a recent scan before its first batch, and an unavailable recent choice. Negative controls cover automatic restoration/Refresh/scope operations and duplicate picker presentation. These are controlled app-hosted tests; no additional native disconnected-provider test was performed.

The new archive is `/tmp/stillview-pr27-review-2026-10-12.xcarchive`, with unsigned executable SHA-256 `885feefe0e0679a3d3920f6944df4b2cedaffc40d59a3a3ef58ae2bd924a068d`. Version remains 5.1.0 (45). Archived What’s New and the privacy manifest match source; DEBUG snapshot helper/menu/capture symbol strings are absent. The previous native-testing and Store-submission bounds in the [release report](2026-10-12-release-readiness-fixes-verification.md) remain applicable.

The user's existing screenshot helper is unchanged and excluded from these commits, with its original diff SHA-256 `82438b26a4237c3ba90af16f2bb55a903edba03db3a1e7e80fca47ec01b44ae2`. No Xcode project, entitlement, version, release-copy or website changes were needed for this follow-up. Live hosted checks and review-thread status are reported separately on the PR.

Evidence: [RED assertions](evidence/2026-10-12/pr27-review-red.txt), [full suite summary](evidence/2026-10-12/pr27-review-full-test-summary.json), and [build/preservation validation](evidence/2026-10-12/pr27-review-validation.json).
