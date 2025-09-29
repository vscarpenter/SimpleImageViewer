# Refactor Plan and Task Tracker (StillView)

This document tracks the ongoing refactor of StillView. It provides clear phases, checklists, naming decisions, and removal criteria for temporary compatibility code. It is Swift/macOS specific — no Java/Swing content belongs here.

Last updated: 2025-09-21

## Important
- This document must not include any unrelated code snippets (e.g., Java/Swing). If you see anything off-topic, replace it with the content in this file.

---

## Goals
- Consolidate and namespace types under `Preferences` and other feature modules.
- Remove ad-hoc or ambiguous type names (e.g., `PreferencesTab`, `AI.*`) in favor of explicit, scoped types (e.g., `Preferences.Tab`, `AIImageAnalysisService`).
- Eliminate temporary compatibility shims after the migration is complete.
- Resolve current build errors and prevent regressions with small, incremental steps.

## Current Build Errors to Address
- Cannot find type 'AI' in scope
- Cannot find type 'PreferencesTab' in scope

These are symptoms of the ongoing namespacing migration. See Phase 1 and Phase 2 below.

## Scope
- Preferences UI and coordination (tabs, focus manager, window controller)
- AI image analysis integrations (search, organization)
- Shared design system references used by Preferences and related modules

---

## Phases Overview
- Phase 1: Stabilize build using compatibility aliases and fix obvious references
- Phase 2: Migrate all call sites to the new namespaced types
- Phase 3: Remove compatibility shims and dead code, tidy imports

---

## Phase 1 — Stabilize Build (Aliases + Quick Fixes)
Focus: Get the project compiling and running while we migrate.

- [ ] Ensure `Compat.swift` is included in the target build settings
  - Comment in file: "Remove this file after Phase 3 of the refactor plan."
- [ ] Standardize references to Preferences tabs
  - Replace `PreferencesTab` usages with `Preferences.Tab` (or rely on the alias for now)
  - Files to check: `PreferencesFocusManager.swift`, other `Preferences*` files
- [ ] Resolve 'AI' type errors
  - Replace `AI.SimilarImageResult` with the concrete type returned by `AIImageAnalysisService`
    - Prefer the local `SimilarImageResult` struct used by Smart Search (see `SmartSearchService.swift`)
    - Or use `AIImageAnalysisService.SimilarImageResult` if that nested type exists
  - Remove `AI.` namespace prefixes if no `AI` module/namespace is present
  - Files to check: `SmartImageOrganizationService.swift`
- [ ] Verify `Preferences.Tab` enum is the single source of truth for tabs
  - File: `PreferencesTab.swift`
- [ ] Confirm Preferences window compiles and opens
  - Files: `PreferencesCoordinator.swift`, `PreferencesWindowController`

Exit criteria for Phase 1:
- [ ] Project compiles and runs
- [ ] No "Cannot find type 'AI'" or "Cannot find type 'PreferencesTab'" errors

---

## Phase 2 — Migrate Call Sites to New Names
Focus: Replace all usages of temporary aliases with the new namespaced types and unify models.

- [ ] Replace all `PreferencesTab` references with `Preferences.Tab`
  - [ ] `PreferencesFocusManager.swift` — field `focusedTab` type
  - [ ] Any view or coordinator files referencing tab types
- [ ] Unify similar image result types
  - [ ] Replace `AI.SimilarImageResult` with `SimilarImageResult` (from Smart Search) or a single canonical type
  - [ ] Update return types and call sites accordingly
  - [ ] Ensure `AIImageAnalysisService` methods return the canonical type
- [ ] Remove stray `AI.` prefixes
  - [ ] Search for `"AI."` in the project and migrate to concrete or namespaced types
- [ ] Document migration decisions inline where ambiguity existed

Exit criteria for Phase 2:
- [ ] No references to `PreferencesTab` remain in code
- [ ] No references to `AI.` remain unless backed by a real module/type
- [ ] Similar image result is a single canonical type across services

---

## Phase 3 — Remove Shims and Clean Up
Focus: Delete compatibility layers and unused code.

- [ ] Remove `Compat.swift` once all aliases are no longer referenced
  - Aliases currently include:
    - `public typealias PreferencesTab = Preferences.Tab`
    - `public typealias ToolbarStyle = Preferences.ToolbarStyle`
    - `public typealias AnimationIntensity = Preferences.AnimationIntensity`
    - `public typealias ThumbnailSize = Preferences.ThumbnailSize`
    - `public typealias ZoomLevel = Preferences.ZoomLevel`
    - `public typealias ShortcutCategory = Shortcuts.Category`
    - `public typealias AIModel = AIImageAnalysisService.Model`
- [ ] Re-run a global search to ensure no alias names remain
- [ ] Remove obsolete comments and TODOs related to the migration
- [ ] Organize imports and remove unused ones

Exit criteria for Phase 3:
- [ ] `Compat.swift` removed
- [ ] No alias names exist in the codebase
- [ ] Build passes with warnings minimized

---

## Migration Map (Before → After)
- `PreferencesTab` → `Preferences.Tab`
- `AI.SimilarImageResult` → `SimilarImageResult` (canonical) or `AIImageAnalysisService.SimilarImageResult`
- `AI.*` (generic) → Concrete services/types (e.g., `AIImageAnalysisService`, `SimilarImageResult`)

---

## Known Touchpoints
- Preferences
  - `PreferencesTab.swift` — source of truth for tabs
  - `PreferencesFocusManager.swift` — uses `focusedTab`
  - `PreferencesCoordinator.swift` / `PreferencesWindowController`
- AI / Smart features
  - `SmartSearchService.swift` — defines `SimilarImageResult` and uses `AIImageAnalysisService`
  - `SmartImageOrganizationService.swift` — currently references `AI.SimilarImageResult`
- Temporary compatibility
  - `Compat.swift` — contains migration aliases; remove in Phase 3

---

## Tracking Checklist (Roll-up)
- [ ] Phase 1: Build stabilization
- [ ] Phase 2: Call site migration
- [ ] Phase 3: Shim removal and cleanup

When you complete a task above, check it off here as well for a high-level view.

---

## How to Work This Plan
1. Start with Phase 1; commit small changes that return the build to a stable state.
2. Create issues (or PRs) per bullet where helpful; link to this document.
3. After Phase 1 compiles cleanly, proceed through Phase 2 replacements systematically.
4. Only after all references are migrated, delete `Compat.swift` (Phase 3) and do final cleanup.

## Notes & Decisions
- We prefer explicit namespacing under `Preferences` for clarity.
- Avoid introducing a new top-level `AI` umbrella unless there is a real module with stable API.
- If `SimilarImageResult` needs to live in a shared module, promote the type to a shared file and import it from both services.
