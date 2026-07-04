---
name: maister-reviews-production-readiness
description: Verify production deployment readiness with comprehensive checks
argument-hint: "[path] [--target=ENV]"
---

# /maister-reviews-production-readiness

**Action required**: Invoke the `maister-production-readiness-checker` subagent now. Do not perform the readiness check in the main session.

Parse the user request below:
- Path: use the provided path, or ask with `ask_user_question` if missing.
- Target: `production` by default, or `staging` if requested.

Use this Pi tool shape:

```js
subagent({
  agent: "maister-production-readiness-checker",
  task: `Verify production readiness at: <path>\nTarget: <production|staging>\nReport path: <path>/production-readiness-report.md`
})
```

Wait for the subagent to complete, then summarize its go/no-go recommendation.

**Usage**:
- `/maister-reviews-production-readiness src/ --target=production`
- `/maister-reviews-production-readiness .maister/tasks/2025-10-24-auth/`

## User request

$@
