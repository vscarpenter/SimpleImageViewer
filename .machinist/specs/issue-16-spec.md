# Spec: Update dependencies (#16)

## Summary

An audit of every dependency surface in this repository shows the app itself has **zero third-party dependencies**: there is no `Package.swift`, `Package.resolved`, `Podfile`, or `Cartfile`, the pbxproj contains no `XCRemoteSwiftPackageReference` entries, and every `import` in the app and test sources is an Apple system framework (SwiftUI, AppKit, Combine, Vision, FoundationModels, ImageIO, Metal, Carbon, etc.). The only updatable "includes" are the GitHub Actions version pins in `.github/workflows/`. This task bumps the stale action pins to their current stable majors and adds a Dependabot configuration so future action updates are surfaced automatically instead of requiring another manual audit.

## Requirements

Interpretation chosen: the issue's "check to see if there any inclues that need to be update" is read as "audit all dependencies and update any that are stale." Since no package-manager dependencies exist, the actionable scope is CI workflow action pins.

1. Every third-party GitHub Action referenced in `.github/workflows/*.yml` is pinned to its latest stable **major** version tag, as verified against each action's GitHub releases at implementation time (e.g. `gh api repos/actions/checkout/releases/latest --jq .tag_name`). Known-stale as of the audit: `actions/checkout@v4` (v5+ exists) and likely `github/codeql-action@v3` (v4 announced); the rest must be verified, not assumed.
2. Workflow behavior is unchanged apart from the version bumps. If a major bump changes a default (e.g. a newer `actions/checkout` altering `persist-credentials` or Node runtime requirements), the workflow is adjusted to preserve current behavior, and the adjustment is called out in the PR description.
3. A new `.github/dependabot.yml` exists with the `github-actions` package ecosystem on a weekly schedule, so this audit does not need to be repeated by hand.
4. No app source, test source, or `StillView - Simple Image Viewer.xcodeproj/project.pbxproj` changes are made (AGENTS.md forbids hand-editing Xcode project files, and there is nothing to update there anyway).
5. The full build and test suite still passes, and all PR-triggered workflows run green with the new pins.

## Proposed approach

This is a Standard-tier change: a handful of YAML files, no public contract, no Swift code.

**Step 1 — Verify current versions (implementation-time, not from memory).** For each action below, query the latest release tag before editing. The complete inventory of action references in this repo:

| Workflow file | Actions referenced |
|---|---|
| `.github/workflows/ci.yml` | `actions/checkout@v4`, `maxim-lobanov/setup-xcode@v1` |
| `.github/workflows/build.yml` | `actions/checkout@v4` (×4), `maxim-lobanov/setup-xcode@v1` (×3), `actions/cache@v4`, `actions/upload-artifact@v4` (×3) |
| `.github/workflows/codeql.yml` | `actions/checkout@v4`, `maxim-lobanov/setup-xcode@v1`, `github/codeql-action/init@v3`, `github/codeql-action/analyze@v3` |
| `.github/workflows/claude.yml` | `actions/checkout@v4`, `anthropics/claude-code-action@v1` |
| `.github/workflows/claude-code-review.yml` | `actions/checkout@v4`, `anthropics/claude-code-action@v1` |
| `.github/workflows/release-drafter.yml` | `release-drafter/release-drafter@v6` |
| `.github/workflows/machinist-approve.yml` | none (pure `run:` steps using `gh`) — no change |

**Step 2 — Bump stale pins.** Edit only the `uses:` lines in the seven workflow files, keeping the repo's existing convention of major-version tags (`@vN`), not commit SHAs. For each action already on its latest major (`release-drafter@v6`, `claude-code-action@v1`, `setup-xcode@v1` are expected to be current), leave the pin untouched. For `github/codeql-action`, bump `init` and `analyze` together — they must share a major version.

**Step 3 — Add Dependabot.** Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

**Step 4 — Record the audit result.** The PR description (not a new doc file) states the audit conclusion: no SPM/CocoaPods/Carthage/pbxproj dependencies exist; `build.yml`'s "Install Dependencies" step already documents this ("No external dependencies to install") and stays as-is. SwiftLint is installed unpinned via `brew install swiftlint` in `build.yml` and `.githooks/pre-commit`, which already means "latest" — nothing to update there.

## Testing plan

1. **Static workflow validation:** run `actionlint` (install via `brew install actionlint` if absent) against `.github/workflows/` — zero errors. This catches typo'd tags and invalid inputs before CI does.
2. **Pin verification:** `grep -RIn "uses:" .github/workflows/` and confirm every third-party action matches the latest-major table produced in Step 1; specifically, no `actions/checkout@v4` or `codeql-action/...@v3` references remain if newer majors were confirmed.
3. **No app regression:** run the AGENTS.md commands locally —
   `xcodebuild -project "StillView - Simple Image Viewer.xcodeproj" -scheme "StillView - Simple Image Viewer" -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO` and the corresponding `xcodebuild test` invocation — both must pass (they touch no changed files, so this is a sanity gate).
4. **End-to-end proof:** open the PR against `main`; `ci.yml`, `build.yml`, `codeql.yml`, and `claude-code-review.yml` all trigger on `pull_request` and must complete green with the new action versions. This is the authoritative test that the bumped actions actually work on `macos-latest` runners.
5. **Dependabot config validity:** after the branch is pushed, confirm GitHub reports no parse errors for `.github/dependabot.yml` (repo **Insights → Dependency graph → Dependabot** shows the ecosystem as configured; a malformed file surfaces an error banner there).

## Out of scope

- Adding any Swift Package Manager, CocoaPods, or Carthage dependency — the app intentionally has none, and none is needed.
- Changing `MACOSX_DEPLOYMENT_TARGET` (26.0), `SWIFT_VERSION` (5.0), the `xcode-version: latest-stable` selection, or anything in `project.pbxproj`.
- Fixing the stale README prerequisites (`README.md` still says "Xcode 15.0+" and "macOS 12.0 deployment" while the project targets macOS 26.0) — worth a separate docs issue.
- Pinning actions to full commit SHAs; the repo's established convention is major-version tags and this task follows it.
- Restructuring, consolidating, or otherwise refactoring the workflows (e.g. merging the overlapping `ci.yml` and `build.yml`).
- Enabling Dependabot for ecosystems other than `github-actions` (there are none to enable).

## Open questions

1. Is the weekly Dependabot cadence acceptable, or would the owner prefer `monthly` (fewer PRs) or no Dependabot at all (one-time bump only)? Default if unanswered: weekly, as specified above.
2. If `github/codeql-action@v4` (or any other new major) requires a runner or permissions change beyond a drop-in tag bump, should the implementation take the migration in this PR or stay on the current major and note it? Default if unanswered: take the migration if it is confined to the workflow file; otherwise stay and note it in the PR.
