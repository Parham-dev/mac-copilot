---
name: content-summariser
description: Guidance for content summarisation across URLs, files, and pasted text.
---

# Content Summariser Skills

This document defines the content-summarisation skill intent and maintainer rules.

## Purpose

- Summarise mixed sources (URL, file content, pasted text) into decision-ready output.
- Keep source handling robust while avoiding rigid source-type assumptions.
- Prioritise user-selected inputs when present (`url`, `goal`, `audience`, `tone`, `length`, `outputFormat`, `advancedCitationMode`, `advancedExtraContext`, plus any requirements/constraints fields).

## Source Handling

- Keep the URL path documented, but do not hard-code source format rules.
- Let the agent infer source format from actual input/content signals.
- If source parsing is uncertain, return uncertainty clearly instead of fabricating details.

## Authoring Rules

- Keep runtime prompts concise and task-focused.
- Keep deeper implementation notes under `references/`.
- Use relative links and avoid duplicated/conflicting instructions.

## References

- `references/url-fetch.md`
- Official docs index: https://agentskills.io/llms.txt

## Maintenance Checklist

- Validate links and paths after refactors.
- Keep references focused and non-duplicative.
- Confirm guidance still matches current app behavior and tool policy.
