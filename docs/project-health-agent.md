# project-health Agent

## Overview

Dashboard agent. Point it at any local project folder, press run, get an instant health report with a **composite score** (0–100). No accounts, no setup, no API keys — everything runs locally via shell + filesystem tools.

**UX Mode:** Dashboard  
**Required connections:** None  
**Tools:** `shell`, `read_file`, `list_directory`, `search_files`, `search_codebase`

---

## What It Shows

The dashboard is a single scrollable page with scored sections. Each section contributes to the overall **Project Health Score**.

### Project Health Score (0–100)

Weighted composite of six dimensions:

| Dimension | Weight | What it measures |
|-----------|--------|------------------|
| **Security** | 25% | Dependency vulnerabilities, secrets in code, outdated packages |
| **Architecture** | 20% | File structure depth, module coupling, naming conventions |
| **Test Coverage** | 20% | Test file ratio, coverage report parsing, test framework detection |
| **Code Hygiene** | 15% | TODO/FIXME/HACK density, dead code signals, lint config presence |
| **Git Health** | 10% | Commit frequency, branch hygiene, merge conflict markers |
| **Documentation** | 10% | README presence, doc-to-code ratio, inline comment density |

Score ranges:  
- **90–100** — Excellent. Ship with confidence.  
- **70–89** — Healthy. A few things to tighten.  
- **50–69** — Needs attention. Accumulating debt.  
- **0–49** — Critical. Stop and fix before building more.

Each dimension also gets its own A/B/C/D/F letter grade shown in the dashboard.

---

## Dashboard Sections

### 1. Score Card (hero)

Big number (0–100) with color coding + letter grade per dimension. Visual at-a-glance health indicator.

```
╔══════════════════════════════════════╗
║   PROJECT HEALTH SCORE:  74 / 100   ║
║   ██████████████░░░░░░  Grade: B    ║
╠══════════════════════════════════════╣
║ Security      ▓▓▓▓▓▓▓░░░  68  C+   ║
║ Architecture  ▓▓▓▓▓▓▓▓░░  82  B+   ║
║ Test Coverage ▓▓▓▓▓░░░░░  52  D+   ║
║ Code Hygiene  ▓▓▓▓▓▓▓▓░░  78  B    ║
║ Git Health    ▓▓▓▓▓▓▓▓▓░  88  A-   ║
║ Documentation ▓▓▓▓▓▓▓░░░  72  B-   ║
╚══════════════════════════════════════╝
```

### 2. Security Audit

- `npm audit` / `pip audit` / `cargo audit` / `bundler-audit` (auto-detects package manager)
- Scans for leaked secrets patterns (API keys, tokens, passwords in code) via `grep`/`search_files`
- Checks `.gitignore` for sensitive file exclusions (.env, credentials, keys)
- Flags packages with known CVEs
- Detects if `.env.example` exists but `.env` is not gitignored
- **Score formula:** starts at 100, −10 per critical vuln, −5 per high, −2 per moderate, −15 if secrets detected

### 3. Architecture Analysis

- Detects project type (monorepo, frontend, backend, mobile, library, full-stack)
- Maps directory structure depth and breadth
- Measures max nesting level (deep nesting = coupling smell)
- Checks for separation of concerns (is there a clear src/test/docs split?)
- Detects circular dependency indicators (import cycle patterns)
- Counts god files (files > 500 lines)
- Checks naming consistency (camelCase vs snake_case vs kebab-case mixing)
- **Score formula:** baseline 70, +points for clear structure, −points per god file, per deep nesting level, per naming inconsistency

### 4. Test Coverage

- Detects test framework (Jest, pytest, XCTest, Go test, RSpec, JUnit, etc.)
- Counts test files vs source files ratio
- If coverage report exists (lcov, coverage.json, .coverage), parses and extracts %
- Runs `npm test -- --coverage` / `pytest --cov` if safe and user approves
- Identifies untested directories (source dirs with zero corresponding test files)
- **Score formula:** maps coverage % directly. If no coverage tool, uses test-to-source file ratio × 100

### 5. Code Hygiene

- `TODO` / `FIXME` / `HACK` / `XXX` / `TEMP` / `WORKAROUND` scan with file + line locations
- Dead code signals: unused imports (if linter config exists), commented-out code blocks
- Checks for linter config (.eslintrc, .pylintrc, .swiftlint.yml, rustfmt.toml, etc.)
- Checks for formatter config (.prettierrc, .editorconfig, black.toml, etc.)
- Detects `.env` files committed to repo
- Large file detection (files > 1MB that probably shouldn't be in git)
- **Score formula:** 100 − (2 × TODO count capped at 20) − 15 if no linter − 10 if no formatter − 5 per large file

### 6. Git Health

- Commit frequency (last 30 days): daily, weekly, sporadic, dead
- Total branch count + stale branches (no commits in 30+ days)
- Merge conflict markers still in code (`<<<<<<<`, `=======`, `>>>>>>>`)
- Last commit age
- Contributors count (last 90 days)
- Checks if conventional commits are used
- Detects if main/master is protected (branch protection via local config or CI files)
- **Score formula:** baseline 80, +10 for daily commits, −5 per stale branch (cap −20), −20 per conflict marker, −10 if last commit > 14 days

### 7. Documentation

- README.md exists and has content (not just a title)
- CHANGELOG / HISTORY file presence
- LICENSE file presence
- Doc-to-code ratio (markdown/doc files vs source files)
- Inline comment density (comments per 100 lines of code)
- API docs or generated docs presence (JSDoc, Sphinx, Jazzy, etc.)
- **Score formula:** +25 for README with content, +15 for LICENSE, +10 for CHANGELOG, +20 for doc-to-code ratio > 5%, +15 for comment density > 8%, +15 for API doc config

### 8. Hot Files (recently changed)

- Top 10 most-modified files in last 30 days (`git log --name-only`)
- Highlights files that are both hot AND large (churn risk)
- Shows files with most authors (ownership diffusion)

### 9. Quick Stats Bar

- Total lines of code (via `cloc` or `wc -l` fallback)
- Language breakdown (top 5)
- File count by type
- Repo size
- Age (first commit date)

### 10. Action Items (auto-generated)

Based on scores, generates a prioritised fix list:

```
🔴 Critical: 3 high-severity npm vulnerabilities — run `npm audit fix`
🔴 Critical: AWS key pattern detected in src/config.ts:42
🟡 Warning: 47 TODOs across 12 files — oldest is 8 months
🟡 Warning: 6 stale branches — consider deleting
🟢 Suggestion: Add .prettierrc for consistent formatting
🟢 Suggestion: test/ directory covers only 3 of 8 source directories
```

---

## Inputs

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `projectPath` | text | Yes | Absolute path to local project root |
| `runTests` | select | No | `no` (default), `dry-run` (show command), `yes` (execute test suite) |
| `depth` | select | No | `quick` (30s, skips heavy ops), `standard` (default), `deep` (runs audits + coverage) |

---

## Language / Framework Auto-Detection

The agent detects the project type from marker files and adjusts its analysis:

| Marker | Stack | Audit command |
|--------|-------|---------------|
| `package.json` | Node.js | `npm audit` / `yarn audit` / `pnpm audit` |
| `requirements.txt` / `pyproject.toml` | Python | `pip audit` / `safety check` |
| `Cargo.toml` | Rust | `cargo audit` |
| `Gemfile` | Ruby | `bundle audit` |
| `go.mod` | Go | `govulncheck ./...` |
| `*.xcodeproj` / `Package.swift` | Swift | SPM dependency check |
| `pom.xml` / `build.gradle` | Java/Kotlin | `mvn dependency-check:check` |
| `composer.json` | PHP | `composer audit` |

Falls back to generic filesystem analysis if no package manager detected.

---

## Score Persistence & Trends

Each run saves a snapshot to the agent sandbox:

```
~/Library/Application Support/CopilotForge/agent-runs/<sessionId>/
  health-score.json       # full score breakdown
  health-history.json     # appended each run for trend tracking
```

Future dashboard enhancement: show score trend over time (sparkline).

---

## Example Output Template

```
sectionOrder:
  - scoreCard
  - actionItems
  - securityAudit
  - architectureAnalysis
  - testCoverage
  - codeHygiene
  - gitHealth
  - documentation
  - hotFiles
  - quickStats
```

---

## Cool Future Add-ons

- **Diff-aware mode:** after a PR or big commit, re-score and show what changed
- **Team health:** if git has multiple contributors, show per-author stats (who owns what, bus factor)
- **CI config audit:** detect CI files (.github/workflows, .gitlab-ci, Jenkinsfile) and flag misconfigurations
- **License compatibility:** scan dependency licenses for conflicts (MIT mixing with GPL, etc.)
- **Performance signals:** detect large bundles (webpack stats), heavy imports, image assets > 1MB
- **Dependency freshness:** not just vulnerabilities — how outdated are deps? Major versions behind?
- **Badge generation:** export score as a shields.io-style badge for README
- **Scheduled re-scans:** auto-run weekly and notify if score drops below threshold
- **Comparison mode:** compare two project snapshots side-by-side (before/after refactor)

---

## Where to Start (Build Approach)

Build in 4 tight phases so we can ship value early.

### Phase 1 — MVP Dashboard (fast)

Ship read-only cards first:
- Quick Stats
- Git Health
- Code Hygiene (TODO/FIXME/HACK + conflict markers)
- Basic Documentation checks

Deliverables:
- Card renderer in Dashboard mode
- Deterministic score math (weights + grade bands)
- Action items generator

### Phase 2 — Security + Architecture

Add high-value analysis cards:
- Security audit with ecosystem auto-detect
- Secret-pattern scanning
- Architecture heuristics (nesting depth, god files, naming consistency)

Deliverables:
- Security card with severity-based deductions
- Architecture card with measurable smells + evidence

### Phase 3 — Coverage + Hot Files

Add confidence and ownership signals:
- Coverage artifact parsing + optional test execution
- Hot files (churn, large+hot, multi-author)

Deliverables:
- Coverage card with fallback heuristic
- Hot files risk card

### Phase 4 — Trends + Polish

Add persistence and longitudinal value:
- Save per-run snapshots
- Show score trend
- Add comparison mode hooks (future)

Deliverables:
- `health-score.json` + `health-history.json`
- Trend sparkline and “score changed by X” summary

Implementation reference skill:
- `skills/agents/project-health/SKILL.md`
- `skills/agents/project-health/references/cards-and-scoring.md`
