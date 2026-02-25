# Phase 2 Execution Plan — Workspace UX Shell

This document defines the implementation steps for the desktop UX shell inspired by Codex-style layout.

## UX Target

Three-pane macOS workspace:
- Left: workspace/admin/project navigation
- Center: primary chat workflow
- Right: context pane with tab switch (`Preview` / `Git`)

Design principles:
- Project-first context (everything scoped to active local project)
- Fast switching between conversation and project evidence
- Stable desktop ergonomics (resizable panes, persistent layout)

---

## Step-by-step Build Plan

## Step 1 — Shell Layout Scaffold (Now)
**Goal:** Build resizable 3-pane shell with right context tabs.

Scope:
- Keep existing left sidebar and auth gating
- For chat selection, render center + right panes using `HSplitView`
- Add context tab switch (`Preview`, `Git`)
- Add placeholder right-pane content for both tabs

Done when:
- Chat remains functional in center
- Right pane can switch between preview/git placeholders
- Panes are draggable and feel stable

---

## Step 2 — Project Context Model ✅
**Goal:** Introduce active project context for shell.

Scope:
- Add `ProjectRef` model (id, name, localPath)
- Sidebar project list and active project selection
- Show active project in shell header

Done when:
- Selecting project updates shell context
- All shell areas read from same active project state

---

## Step 3 — Local Project Bootstrap ✅
**Goal:** Create/open local project folders for users.

Scope:
- Create project flow (name + path under workspace)
- Open existing project folder
- Save project metadata in local store

Done when:
- User can create/open projects without terminal
- Project metadata survives app restart

---

## Step 4 — Right Pane Integrations
**Goal:** Replace placeholders with functional panels.

Scope:
- Preview tab: live web preview host status and container
- Git tab: repo status + changed files list + simple diff panel

Done when:
- Right pane reflects active project state
- Switching tabs is instant and stable

---

## Step 5 — Persistence + UX Polish
**Goal:** Make shell production-usable.

Scope:
- Persist pane/tab selection and last active project
- Keyboard shortcuts (new chat, switch tab, focus input)
- Empty/error states and status strip for sidecar/auth/session

Done when:
- Workspace reopens in expected state
- Errors are visible without logs

---

## Out of Scope for This Phase
- Full Monaco editor
- Full deployment pipeline
- Supabase user sync

These are covered in later roadmap phases.
