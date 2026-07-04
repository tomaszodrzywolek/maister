---
name: maister-reviews-pragmatic
description: Detect over-engineering and ensure code matches project scale
argument-hint: "[path]"
---

# /maister-reviews-pragmatic

**Action required**: Invoke the `maister-code-quality-pragmatist` subagent now. Do not perform the review in the main session.

Parse the user request below. If no path was provided, ask with `ask_user_question`.

Use this Pi tool shape:

```js
subagent({
  agent: "maister-code-quality-pragmatist",
  task: `Review the code at: <path>\nFocus: over-engineering, unnecessary complexity, YAGNI violations, framework lock-in, and developer experience.\nSave report to: verification/pragmatic-review.md`
})
```

Wait for the subagent to complete, then summarize its findings.

**Usage**: `/maister-reviews-pragmatic src/`

## User request

$@
