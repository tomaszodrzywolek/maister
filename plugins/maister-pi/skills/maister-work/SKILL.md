---
name: maister-work
description: Unified Maister entry point for Pi. Use when the user invokes /maister-work to resume an existing task or classify a new task and route to the correct Maister workflow.
argument-hint: "[task description | task folder path | issue identifier]"
---

# Maister Work

Unified entry point that detects existing Maister task folders, classifies new work, and routes to the appropriate Maister workflow skill. This is the Pi-native implementation of the `/maister-work` command logic.

## Routing targets

| Classification | Inline skill to load |
|----------------|----------------------|
| development | `maister-development` |
| performance | `maister-performance` |
| migration | `maister-migration` |
| research | `maister-research` |
| product-design | `maister-product-design` |

## Workflow

### 1. Parse input

Use the prompt arguments if provided. If no useful input was provided, ask with `ask_user_question`: "What would you like to work on?" Include examples for a task description, task folder path, or issue identifier.

### 2. Detect existing task folder

Check whether the input identifies an existing Maister task:

1. Try the input as an absolute or relative path.
2. Try prepending `.maister/`.
3. Search `.maister/tasks/*/` for a folder-name match.

If a folder exists and contains `orchestrator-state.yml`, read it and infer the workflow from the folder path:

| Folder segment | Workflow |
|----------------|----------|
| `development/` | development |
| `performance/` | performance |
| `migrations/` | migration |
| `research/` | research |
| `product-design/` | product-design |

Present the task status and ask how to proceed with `ask_user_question`:

- In-progress: "Resume from next incomplete phase", "Restart from specific phase", "Cancel"
- Completed: "View task details", "Create follow-up development task", "Re-run verification phase", "Cancel"
- Failed: "Resume with fresh attempts", "Retry failed phase", "Restart from specific phase", "Cancel"

Then load the matching Maister workflow skill inline from Pi skill discovery and execute it in the current context with resume arguments such as:

```text
--resume <task_path>
--resume <task_path> --from=verify
--resume <task_path> --reset-attempts --clear-failures
```

Do not call a nested `/skill:*` slash command. Load the named skill's `SKILL.md` from Pi's available skills catalog, or search `.pi/skills` and `~/.pi/agent/skills` if needed, then follow it inline.

### 3. Classify and route new work

For new task descriptions or issue identifiers, invoke the Pi `subagent` tool:

```js
subagent({
  agent: "maister-task-classifier",
  task: "Classify this task into a Maister workflow type and return YAML with task_type, confidence, and reasoning: <task description>"
})
```

The classifier may fetch issue details, inspect local code context, and return one of: `development`, `performance`, `migration`, `research`, `product-design`.

If classification succeeds, display the classification and confidence, then load the matching Maister workflow skill inline and execute it in the current context with the original task description.

If classification fails or confidence is too low, ask the user to choose manually with `ask_user_question`:

- "Development" — fix bugs, improve features, or add capabilities
- "Performance" — optimize speed or efficiency
- "Migration" — move to new technology, architecture, or data model
- "Research" — investigate and document findings
- "Product Design" — design features/products before building

Then load and execute the selected workflow skill inline.

## Important Pi semantics

- Use `subagent({ agent: "...", task: "..." })` for classifier delegation.
- Use inline skill loading for workflow routing. Do not rely on nested `/skill:*` slash commands.
- Preserve the original user request exactly when passing it into the routed workflow.
- Ask before destructive rollback or restart choices.
