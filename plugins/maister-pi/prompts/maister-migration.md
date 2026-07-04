---
name: maister-migration
skill: maister-migration
description: Orchestrate code, data, or architecture migrations
argument-hint: "[description | task-path] [--type=TYPE] [--from=PHASE]"
---

# /maister-migration

Run the injected `maister-migration` workflow skill for the user request below.

**Usage**:
- `/maister-migration "Migrate from Redux to Zustand" --type=code`
- `/maister-migration .maister/tasks/migrations/2025-10-24-redux/ --from=verify`

Types: `code`, `data`, `architecture`, `platform`

## User request

$@
