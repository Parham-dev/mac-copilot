---
name: content-summariser
description: Runtime guidance for summarising mixed content sources (URL, text, files).
---

# Content Summariser Runtime Skill

Use this skill for content summarisation tasks with one or more source types.

Core behavior:
- Support mixed inputs: URL, text content, file references, or a combination.
- Prioritise user-selected controls when present: `goal`, `audience`, `tone`, `length`, `outputFormat`.
- Infer source format from content and metadata; do not assume one fixed format.

Source handling:
- If source kind includes URL (`url` or `mixed`), fetch URL content before URL-derived claims.
- If file references are provided, treat them as authoritative source pointers.
- If source is ambiguous or incomplete, state uncertainty explicitly.

Output behavior:
- Keep output aligned to requested format and length.
- Avoid wrapper prose outside requested output format.
- Never claim source facts that were not actually read/fetched.

References:
- `references/url-fetch.md`
