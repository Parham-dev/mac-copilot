# Git Feature README & Roadmap

## Why this exists
This document defines the product scope, UX principles, and implementation roadmap for the Git section in the Context Pane.

## Product Goal
Deliver a simple, reliable Git experience inside CopilotForge so users can:
- see repository status quickly,
- review file-level changes,
- create quality commits (with optional Copilot message generation),
- view recent history without leaving the app.

## Non-Goals (MVP)
- Full Git client parity (rebase/cherry-pick/stash UI).
- Complex merge conflict resolution UI.
- Advanced graph interactions (drag, re-layout, branch compare matrix).

## UX Principles
1. **Fast status first**: Always show branch + clean/dirty state immediately.
2. **Single-pane workflow**: Status, changes, commit, history in one scrollable panel.
3. **Safe defaults**: Disable destructive actions when invalid; show clear errors.
4. **Low cognitive load**: Keep actions obvious and labels explicit.
5. **Progressive complexity**: MVP first, advanced controls later.

## Information Architecture (Panel)
1. Repository status header
2. Working tree changes list
3. Commit composer
4. Recent history list + mini graph

## Progress Update (2026-02-26)

### Completed
- **P0 Status + Init**
  - Branch and clean/dirty status shown in panel header.
  - `Init Git` flow works and refreshes state immediately.
  - Status refresh now triggers on panel open, project switch, and chat completion.
- **P1 Change Summary (core)**
  - File changes grouped by `A / M / D`.
  - Per-file `+added / -deleted` displayed.
  - Added-file text fallback counts lines when git numstat returns `0/0`.
- **P2 Commit Workflow (adapted)**
  - Commit composer exists with auto-generated message when left empty.
  - Empty-message generation now uses Copilot prompt flow with selected user model.
  - Commit operation stages all changes internally before commit.
  - Added cooldown after AI connection failure to avoid repeated sidecar errors/log noise.
- **P3 History (minimal)**
  - Recent commit list (message, short SHA, author, relative time) is live.
  - Recent commits section is capped to 3 visible rows with scroll for more.

### In Progress
- **P3 Graph lane**
  - Vertical commit graph lane (dots/lines) not implemented yet.

### Not Started
- **P4 Quality-of-Life**
  - Amend, branch create/switch, ahead/behind, push/pull actions.

## Implemented UX Decisions (Intentional)
- Removed `All / Staged / Unstaged` tabs from the panel (always shows all changes).
- Removed `Stage All / Unstage All` buttons from UI.
- Commit now stages all changes automatically to keep flow single-action.

These decisions were made intentionally during implementation to keep the panel minimal and reduce user friction.

---

## Roadmap (Priority Ordered)

### P0 — Repository Status (Critical)
**User value:** Know repo state at a glance.

Scope:
- Show current branch.
- Show status badge: `Clean` or `N files changed`.
- Show repository path summary.
- Show “Init Git” if no repository exists.

Acceptance criteria:
- Status loads on panel open and project switch.
- `Init Git` creates repository and refreshes status.
- Errors are surfaced with actionable text.

### P1 — Change Summary (Critical)
**User value:** Understand what changed before committing.

Scope:
- List changed files grouped by state (`A`, `M`, `D`).
- Display per-file `+added/-deleted` line counts.
- Add quick filter tabs: `All`, `Staged`, `Unstaged`.

Acceptance criteria:
- Counts reflect git diff output accurately.
- Empty state shown when no changes exist.

### P2 — Commit Workflow (Critical)
**User value:** Make commits without terminal usage.

Scope:
- Commit message input field.
- `Stage All` / `Unstage All` actions.
- `Commit` action with disabled state when invalid.
- `Auto Generate` message button (Copilot-assisted from staged diff).

Acceptance criteria:
- Commit succeeds only when there are staged changes and non-empty message.
- If message is empty and user taps `Auto Generate`, message is inserted, not auto-committed.
- User-edited message is never overwritten implicitly.

### P3 — History + Simple Graph (High)
**User value:** See what happened recently.

Scope:
- Show last 10–20 commits (message, author, relative time, short SHA).
- Add lightweight vertical commit graph lane (simple dots/lines).

Acceptance criteria:
- History renders in under 500ms for typical repos.
- Graph is stable and readable; no interactive complexity required.

### P4 — Quality-of-Life (Medium)
**User value:** Reduce context switches.

Scope:
- Amend last commit.
- Create/switch branch.
- Ahead/behind indicator.
- Push/Pull status + actions.

Acceptance criteria:
- Branch and remote operations show clear success/failure messages.
- Loading/progress states prevent duplicate requests.

---

## Copilot-Assisted Commit Message Rules
- Input: staged diff summary + changed file names.
- Output: concise, actionable commit message.
- Optional style toggle:
  - Plain sentence (default)
  - Conventional commits (`feat:`, `fix:`, `chore:`)
- No auto-commit side effects from generation.

## Error Handling Requirements
- Distinguish:
  - `Not a git repository`
  - `Git executable missing`
  - `Permission denied`
  - `Nothing to commit`
- Provide recoverable actions where possible (`Init Git`, `Retry`, `Open folder`).

## Performance Requirements
- Repository status refresh target: < 300ms median.
- History load target: < 500ms median.
- All git operations off main thread.

## Telemetry (Optional but Recommended)
- `git_panel_opened`
- `git_status_refreshed` (latency + result)
- `git_commit_generated_message`
- `git_commit_success` / `git_commit_failed`

## Suggested Implementation Order (Engineering)
1. ✅ Stabilize status + init flow.
2. ✅ Add changed-file summary + line stats.
3. ✅ Add commit composer (adapted single-action flow).
4. ⏳ Add history list + mini graph (list done, graph pending).
5. ⏳ Add QoL branch/remote features.

## Current Baseline Notes
- Existing implementation now includes status, grouped changes, commit composer, AI-assisted empty-message generation, and minimal recent history list.
- Remaining milestones are graph visualization and branch/remote quality-of-life actions.
