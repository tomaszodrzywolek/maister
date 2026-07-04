---
name: maister-standards-update
skill: maister-standards-update
description: Update or create project standards from conversation context or explicit description
argument-hint: "[description] [--from=PATH]"
---

# /maister-standards-update

Run the injected `maister-standards-update` workflow skill for the user request below. It updates or creates standards in `.maister/docs/standards/` from conversation context, an explicit description, or another project's standards via `--from`.

**Usage**:
- `/maister-standards-update "Always use snake_case for database columns"`
- `/maister-standards-update --from=/path/to/other/project`

## User request

$@
