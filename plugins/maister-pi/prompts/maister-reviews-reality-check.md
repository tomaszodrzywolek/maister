---
name: maister-reviews-reality-check
description: Validate completed work actually solves the problem
argument-hint: "[task-path]"
---

# /maister-reviews-reality-check

**Action required**: Invoke the `maister-reality-assessor` subagent now. Do not perform the assessment in the main session.

Parse the user request below. If no task path was provided, ask with `ask_user_question`.

Use this Pi tool shape:

```js
subagent({
  agent: "maister-reality-assessor",
  task: `Assess the reality of completion for: <task-path>\nVerify it actually solves the business problem, handles edge cases, integrates correctly, and is production-ready.\nSave report to: verification/reality-check.md`
})
```

Wait for the subagent to complete, then summarize its deployment decision.

**Usage**: `/maister-reviews-reality-check .maister/tasks/development/2025-10-24-auth/`

## User request

$@
