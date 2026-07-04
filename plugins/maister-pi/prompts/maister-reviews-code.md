---
name: maister-reviews-code
description: Run automated code quality, security, and performance analysis
argument-hint: "[path] [--scope=SCOPE]"
---

# /maister-reviews-code

**Action required**: Invoke the `maister-code-reviewer` subagent now. Do not perform the review in the main session.

Parse the user request below:
- Path: use the provided path, or ask with `ask_user_question` if missing.
- Scope: `quality`, `security`, `performance`, or `all`; default to `all`.

Use this Pi tool shape:

```js
subagent({
  agent: "maister-code-reviewer",
  task: `Analyze code at: <path>\nScope: <quality|security|performance|all>\nReport path: <path>/code-review-report.md`
})
```

Wait for the subagent to complete, then summarize its findings.

**Usage**:
- `/maister-reviews-code src/`
- `/maister-reviews-code src/api/ --scope=security`
- `/maister-reviews-code .maister/tasks/2025-10-24-auth/`

## User request

$@
