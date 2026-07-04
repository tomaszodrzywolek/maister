---
name: maister-quick-plan
description: Create an approval-gated implementation plan with Maister standards enforcement
argument-hint: "[task description]"
---

# Quick Plan — Approval-Gated Plan with Standards Enforcement

Create a concise implementation plan, discover the relevant Maister standards, present the plan to the user, and get explicit approval with `ask_user_question` before any implementation work.

## Workflow

1. **Get the task** — Use the argument if provided. If none, ask with `ask_user_question`: "What would you like to plan?"

2. **Explore and draft the plan** — `read`/search the codebase with Pi-native tools (`read`, `grep`, `find`, `ls`, `bash` only when needed). Identify affected files, integration points, risks, and a practical implementation sequence.

3. **Discover and enforce standards** — While planning:
   - Read `.maister/docs/INDEX.md` to find which standards exist.
   - **Then read the specific standard files it points to that are relevant to this task.** Reading INDEX.md alone is NOT sufficient — this is mandatory.
   - Fold the matched standards into the plan itself: reference the governing standard where it shapes a step, and include a **`## Standards Compliance Checklist`** — one checkbox per applicable guideline the implementation must satisfy (each annotated with its source file, e.g. `(from standards/backend/api.md)`). This checklist is verified after implementation.

   If `.maister/docs/INDEX.md` does not exist, plan normally and note in the plan: "No Maister standards found. Consider running `/maister-init`."

4. **Present the plan and ask for approval** — Show the complete plan in the conversation, then call `ask_user_question` with options:
   - "Approve plan" — proceed to implementation if the user wants it
   - "Revise plan" — incorporate feedback and present the revised plan again
   - "Cancel" — stop without editing files

   Do not implement until the user explicitly approves the plan.

5. **After approval — implement and verify if requested** — If the user asks you to continue into implementation, go through the `## Standards Compliance Checklist` and verify each item — mark pass/fail and report it. Address any failure before marking the task complete.
