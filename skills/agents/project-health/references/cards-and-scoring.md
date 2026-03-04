---
name: project-health-cards-and-scoring
description: Scoring rubric, command strategy, and fallback matrix for Project Health.
---

# Project Health Cards and Scoring

## Weight model

Use this exact weighted formula:

- Security: 25%
- Architecture: 20%
- Test Coverage: 20%
- Code Hygiene: 15%
- Git Health: 10%
- Documentation: 10%

Composite:
`round(0.25*S + 0.20*A + 0.20*T + 0.15*H + 0.10*G + 0.10*D)`

Grade bands:
- A: 90-100
- B: 80-89
- C: 70-79
- D: 60-69
- F: 0-59

## Command strategy (safe-first)

Run read-only and low-risk commands first.

### Core filesystem profile
- `find <path> -type f`
- `find <path> -type d`
- `du -sh <path>`
- `git -C <path> rev-list --count HEAD`

### Language and LOC
Preferred:
- `cloc <path> --json`

Fallback:
- `find` + `wc -l` per extension bucket

### Git health
- `git -C <path> log --since='30 days ago' --oneline`
- `git -C <path> branch --format='%(refname:short) %(committerdate:relative)'`
- `git -C <path> shortlog -sn --since='90 days ago'`
- churn: `git -C <path> log --since='30 days ago' --name-only --pretty=format: | sort | uniq -c | sort -nr`

### Code hygiene scans
- TODO scan terms: `TODO|FIXME|HACK|XXX|TEMP|WORKAROUND`
- conflict markers: `^<<<<<<<|^=======|^>>>>>>>`

### Security scans (best effort)
By ecosystem marker:
- Node: `npm audit --json` (or package-manager equivalent)
- Python: `pip-audit -f json`
- Rust: `cargo audit --json`
- Go: `govulncheck ./...`

Secret pattern checks (regex families):
- AWS access keys
- GitHub tokens
- private key headers
- generic `api[_-]?key` + assignment

## Fallback matrix

If audit tool missing:
- mark "audit-tool-unavailable"
- continue with secret scan + dependency freshness hints

If git unavailable/not repo:
- set Git Health to neutral baseline 65
- note limitation explicitly

If no coverage artifacts and tests not run:
- compute heuristic from test/source file ratio
- cap Test Coverage score at 70 unless real coverage evidence exists

## Score impact hints for action items

Use these expected-impact ranges:
- Fix critical security vulnerabilities: +8 to +20
- Add/repair test coverage in top untested dirs: +6 to +15
- Resolve stale branches and conflict markers: +4 to +10
- Add linter/formatter config: +4 to +8
- Improve README + CHANGELOG + LICENSE: +3 to +8

## Output schema suggestion

For each card:
- `title`
- `score`
- `grade`
- `highlights[]`
- `issues[]`
- `evidence[]`
- `actions[]`

For overall:
- `compositeScore`
- `compositeGrade`
- `topRisks[]`
- `quickWins[]`
- `limitations[]`
