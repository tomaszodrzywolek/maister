---
name: maister-development
skill: maister-development
description: Run the full spec -> plan -> implement -> verify development workflow
argument-hint: "[description | task-path] [--e2e] [--user-docs] [--from=PHASE]"
---

# /maister-development

Run the injected `maister-development` workflow skill for the user request below.

**Usage**:
- `/maister-development "Fix login timeout error"` (new task)
- `/maister-development .maister/tasks/development/2025-10-24-auth/ --from=verify` (resume)
- `/maister-development .maister/tasks/research/2026-01-12-oauth-research` (research-informed)

## User request

$@
