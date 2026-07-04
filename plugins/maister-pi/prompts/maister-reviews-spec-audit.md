---
name: maister-reviews-spec-audit
description: Independent specification audit for completeness and clarity
argument-hint: "[spec-path]"
---

# /maister-reviews-spec-audit

**Action required**: Invoke the `maister-spec-auditor` subagent now. Do not perform the audit in the main session.

Parse the user request below. If no spec path was provided, ask with `ask_user_question`.

Use this Pi tool shape:

```js
subagent({
  agent: "maister-spec-auditor",
  task: `Audit the specification at: <spec-path>\nAssess completeness, clarity, testability, edge cases, and implementation readiness.\nIf post-implementation was requested, compare against the implementation.\nSave report to: verification/spec-audit.md`
})
```

Wait for the subagent to complete, then summarize its findings.

**Usage**: `/maister-reviews-spec-audit .maister/tasks/2025-10-24-auth/implementation/spec.md`

## User request

$@
