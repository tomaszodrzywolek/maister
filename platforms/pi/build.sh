#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE="$ROOT/plugins/maister"
OUT="$ROOT/plugins/maister-pi"

# Cross-platform sed in-place (macOS needs '' arg, Linux doesn't)
sedi() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

echo "==> Building Pi Coding Agent variant..."
rm -rf "$OUT"
cp -r "$CORE" "$OUT"

# ============================================================
# 1. Remove Claude Code-specific directories
# ============================================================
echo "    Removing Claude Code-specific directories..."
rm -rf "$OUT/hooks"
rm -rf "$OUT/.claude-plugin"

# ============================================================
# 2. Rename CLAUDE.md → AGENTS.md
# ============================================================
echo "    Renaming CLAUDE.md → AGENTS.md..."
mv "$OUT/CLAUDE.md" "$OUT/AGENTS.md"

# ============================================================
# 3. Rename skill directories: prepend maister- prefix
# ============================================================
echo "    Renaming skill directories with maister- prefix..."
for skill_dir in "$OUT/skills"/*/; do
  if [ -d "$skill_dir" ]; then
    dirname=$(basename "$skill_dir")
    if [[ "$dirname" != maister-* ]]; then
      mv "$OUT/skills/$dirname" "$OUT/skills/maister-$dirname"
    fi
  fi
done

# ============================================================
# 4. Rename agent files: prepend maister- prefix
# ============================================================
echo "    Renaming agent files with maister- prefix..."
for agent_file in "$OUT/agents"/*.md; do
  if [ -f "$agent_file" ]; then
    basename=$(basename "$agent_file")
    if [[ "$basename" != maister-* ]]; then
      mv "$agent_file" "$OUT/agents/maister-$basename"
    fi
  fi
done

# ============================================================
# 5. Text transformations on all .md files
# ============================================================
echo "    Applying text transformations..."
find "$OUT" -name "*.md" | while read f; do

  # 5a. CLAUDE.md → AGENTS.md (file references in content)
  sedi 's/CLAUDE\.md/AGENTS.md/g' "$f"

  # 5b. Add maister- prefix to agent and skill frontmatter names
  if [[ "$f" == "$OUT/agents/"* ]]; then
    sedi 's/^name: /name: maister-/' "$f"
  fi
  if [[ "$f" == "$OUT/skills/"*/SKILL.md ]]; then
    # Pi skill names are command names. Keep all Maister skills namespaced
    # so /skill:maister-* references match generated skill metadata and
    # do not collide with user/global skills.
    if ! grep -q '^name: maister-' "$f"; then
      sedi 's/^name: /name: maister-/' "$f"
    fi
  fi

  # 5c. maister: prefix → maister- (all skill, agent, and tool references)
  sedi 's/maister:/maister-/g' "$f"
  # Some source skills are already namespaced as maister:* or maister-*.
  # Collapse accidental double prefixes after the cross-platform rewrite.
  sedi 's/^name: maister-maister-/name: maister-/' "$f"

  # 5d. AskUserQuestion → ask_user_question
  sedi 's/AskUserQuestion/ask_user_question/g' "$f"

  # 5e. TaskCreate/TaskUpdate → todo equivalents
  sedi 's/TaskCreate/todo({ action: "create", ... })/g' "$f"
  sedi 's/TaskUpdate/todo({ action: "update", ... })/g' "$f"

  # 5f. Claude Code Skill tool wording → Pi inline skill loading.
  #     Top-level command templates use pi-prompt-template-model `skill:` frontmatter;
  #     nested skills are loaded from Pi skill discovery and executed inline in the current context.
  sedi 's/Skill tool - `\([^`]*\)`/inline skill `\1`/g' "$f"
  sedi 's/Skill tool with `\([^`]*\)`/inline skill `\1`/g' "$f"
  sedi 's/Skill\/Task tools/inline skills\/subagent tools/g' "$f"
  sedi 's/Skill tool phases/inline skill phases/g' "$f"
  sedi 's/Skill tool call/inline skill execution/g' "$f"
  sedi 's/Skill tool/inline skill loading/g' "$f"
  sedi 's/Use the `EnterPlanMode` tool to present the fix plan for user approval./Present the fix plan to the user and get explicit approval with ask_user_question before editing./g' "$f"
  sedi 's/Invoke the `standards-discover` skill via \/skill:--scope=full/Load and execute the `maister-standards-discover` skill inline with `--scope=full`/g' "$f"

  # 5g. Claude Code Task tool wording → Pi subagent() tool.
  #     Pattern: subagent_type: "maister-xyz" (double-quoted)
  sedi 's/subagent_type: "\([^"]*\)"/subagent({ agent: "\1", ... })/g' "$f"
  #     Pattern: subagent_type: `maister-xyz` (backtick-quoted name)
  sedi 's/subagent_type: `\([^`]*\)`/subagent({ agent: "\1", ... })/g' "$f"
  #     Pattern: `subagent_type: maister-xyz` (whole expression backtick-quoted)
  sedi 's/`subagent_type: \([^`]*\)`/subagent({ agent: "\1", ... })/g' "$f"
  sedi 's/Task tool calls/subagent tool calls/g' "$f"
  sedi 's/Task tool call/subagent tool call/g' "$f"
  sedi 's/Task calls/subagent calls/g' "$f"
  sedi 's/Task call/subagent call/g' "$f"
  sedi 's/Task tool/subagent tool/g' "$f"
  sedi 's/via the Task tool/via the subagent tool/g' "$f"
  sedi 's/via Task tool/via subagent tool/g' "$f"
  sedi 's/Use Task tool/Use subagent({ agent: "...", task: "..." })/g' "$f"
  sedi 's/Explore agent findings/`scout` subagent findings/g' "$f"
  sedi 's/adaptive parallel Explore subagents/adaptive parallel `scout` subagents/g' "$f"
  sedi 's/parallel Explore subagents/parallel `scout` subagents/g' "$f"

  # 5h. Remove Claude Code color: metadata from agent frontmatter
  #      Pi subagents don't support color tags
  sedi '/^color:/d' "$f"

done

# ============================================================
# 5i. Pi-specific skill wording fixes
# ============================================================
echo "    Applying Pi-specific skill wording fixes..."
python3 - <<'PY' "$OUT"
from pathlib import Path
import sys
out = Path(sys.argv[1])

quick_plan = out / "skills" / "maister-quick-plan" / "SKILL.md"
if quick_plan.exists():
    quick_plan.write_text("""---
name: maister-quick-plan
description: Create an approval-gated implementation plan with Maister standards enforcement
argument-hint: "[task description]"
---

# Quick Plan — Approval-Gated Plan with Standards Enforcement

Create a concise implementation plan, discover the relevant Maister standards, present the plan to the user, and get explicit approval with `ask_user_question` before any implementation work.

## Workflow

1. **Get the task** — Use the argument if provided. If none, ask with `ask_user_question`: "What would you like to plan?"

2. **Explore and draft the plan** — Read/search the codebase with Pi-native tools (`read`, `grep`, `find`, `ls`, `bash` only when needed). Identify affected files, integration points, risks, and a practical implementation sequence.

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
""")

quick_bugfix = out / "skills" / "maister-quick-bugfix" / "SKILL.md"
if quick_bugfix.exists():
    text = quick_bugfix.read_text()
    text = text.replace(
        "Lightweight TDD-driven bug fix workflow with planning mode. Analyze the bug, present a fix plan for approval, then reproduce with a failing test, fix, and verify. No orchestrator state, no task directory, no subagents.",
        "Lightweight TDD-driven bug fix workflow with a Pi-native plan approval gate. Analyze the bug, present a fix plan for approval with `ask_user_question`, then reproduce with a failing test, fix, and verify. No orchestrator state, no task directory, no subagents.",
    )
    text = text.replace("### Step 4: Enter Planning Mode", "### Step 4: Plan Approval Gate")
    text = text.replace(
        "### ExitPlanMode Gate: Mandatory Sections\n\n**BLOCKING: Do NOT call `ExitPlanMode` until the plan file contains:**",
        "### Plan Approval Gate: Mandatory Sections\n\n**BLOCKING: Do NOT ask for approval until the presented plan contains:**",
    )
    text = text.replace("If any section is missing, add it before calling ExitPlanMode.", "If any section is missing, add it before asking for approval.")
    text = text.replace(
        "**Present the fix plan to the user and get explicit approval with ask_user_question before editing.**",
        "**Present the fix plan to the user and get explicit approval with `ask_user_question` before editing. Use options: \"Approve plan\", \"Revise plan\", and \"Cancel\".**",
    )
    quick_bugfix.write_text(text)

codebase = out / "skills" / "maister-codebase-analyzer" / "SKILL.md"
if codebase.exists():
    text = codebase.read_text()
    replacements = {
        "Analyzes codebase using adaptive parallel Explore subagents based on task complexity. Selects agent roles from a pool, launches Explore agents, then delegates report generation to codebase-analysis-reporter subagent.":
            "Analyzes codebase using adaptive parallel `scout` subagents based on task complexity. Selects analysis roles from a pool, launches `scout` subagents, then delegates report generation to the maister-codebase-analysis-reporter subagent.",
        "Analyzes codebase using adaptive parallel `scout` subagents based on task complexity. Selects agent roles from a pool, launches Explore agents, then delegates report generation to codebase-analysis-reporter subagent.":
            "Analyzes codebase using adaptive parallel `scout` subagents based on task complexity. Selects analysis roles from a pool, launches `scout` subagents, then delegates report generation to the maister-codebase-analysis-reporter subagent.",
        "Orchestrates parallel codebase analysis using built-in Explore subagents.":
            "Orchestrates parallel codebase analysis using Pi's built-in `scout` subagent.",
        "### Step 3: Read Prompt Templates and Launch Agents":
            "### Step 3: Read Prompt Templates and Launch Scout Subagents",
        "Before launching ANY Explore agent":
            "Before launching ANY `scout` subagent",
        "**3c. Launch agents** — Use the subagent tool with `subagent_type=\"Explore\"` — one call per selected role, all in ONE message.":
            "**3c. Launch agents** — Use the Pi `subagent` tool with a single parallel call: `subagent({ tasks: [{ agent: \"scout\", task: \"...\" }, ...] })`. Create one task per selected role and include the adapted role prompt in that task.",
        "Every Explore agent prompt MUST include this instruction:":
            "Every `scout` subagent task MUST include this instruction:",
        "After all Explore agents complete":
            "After all `scout` subagents complete",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    codebase.write_text(text)

reporter = out / "agents" / "maister-codebase-analysis-reporter.md"
if reporter.exists():
    text = reporter.read_text()
    text = text.replace("parallel Explore agents", "parallel `scout` subagents")
    text = text.replace("multiple parallel Explore agents", "multiple parallel `scout` subagents")
    text = text.replace("Explore agents", "`scout` subagents")
    text = text.replace("each Explore agent", "each `scout` subagent")
    text = text.replace("[N] Explore agents", "[N] `scout` subagents")
    reporter.write_text(text)

standards = out / "skills" / "maister-standards-discover" / "SKILL.md"
if standards.exists():
    text = standards.read_text()
    text = text.replace(
        "**Step 4: Launch subagents in parallel** — Use the subagent tool with subagent({ agent: \"general-purpose\", ... }) for each phase.",
        "**Step 4: Launch subagents in parallel** — Use the Pi `subagent` tool with one parallel call. Use `scout` for config/code/docs analysis tasks and `researcher` for the external-sources task. Prefer `subagent({ tasks: [...] })` with one task per phase; set each task's `output` to the corresponding temp output file so results are persisted for Step 5.",
    )
    text = text.replace("launching ALL applicable agents (2–4 subagent calls) in a SINGLE message", "launching ALL applicable phase tasks in ONE `subagent({ tasks: [...] })` call")
    standards.write_text(text)

orch_patterns = out / "skills" / "maister-orchestrator-framework" / "references" / "orchestrator-patterns.md"
if orch_patterns.exists():
    text = orch_patterns.read_text()
    text = text.replace("Explore agents", "`scout` subagents")
    text = text.replace("Spawning Explore agents", "Spawning `scout` subagents")
    orch_patterns.write_text(text)

perf = out / "skills" / "maister-performance" / "SKILL.md"
if perf.exists():
    text = perf.read_text().replace("parallel Explore agents", "parallel `scout` subagents")
    perf.write_text(text)
PY

# ============================================================
# 5j. Pi terminology cleanup across generated Markdown
# ============================================================
echo "    Applying Pi terminology cleanup..."
python3 - <<'PY' "$OUT"
from pathlib import Path
import re
import sys

out = Path(sys.argv[1])
for path in out.rglob("*.md"):
    text = path.read_text()

    replacements = {
        # Claude-specific platform language that should not appear in Pi-facing workflow docs.
        "Claude Code Skill": "Pi skill",
        "Claude Code Skills": "Pi skills",
        "## Input (from the Task prompt)": "## Input (from the subagent task prompt)",
        "Claude Code's `auto` permission mode instructs the model to execute immediately and minimize clarifying questions. The `→ Pause` gates in this framework are an explicit stated boundary that overrides that instruction.":
            "Pi may be running with permissive execution settings. The `→ Pause` gates in this framework are explicit workflow boundaries that require user confirmation before proceeding.",
        "developers and Claude implementing": "developers and the coding agent implementing",
        "Claude implementing": "the coding agent implementing",
        "Claude: [": "Agent: [",
        "Configure MCP server in Claude Code": "Configure the Playwright MCP server through Pi's MCP adapter",
        "This is a Pi-native replacement for the Claude Code `/maister-work` command logic.":
            "This is the Pi-native implementation of the `/maister-work` command logic.",
        "Never invoke a skill via subagent tool (`subagent_type`) — it will fail with \"Agent type not found.\"":
            "Never invoke a skill via the subagent tool — it will fail because skills and agents are separate Pi concepts.",

        # Documentation terminology in AGENTS.md generated from the Claude variant.
        "If technical details exist in skill.md, reference them in AGENTS.md/commands":
            "If technical details exist in SKILL.md, reference them in AGENTS.md/prompt templates",
        "Commands as Thin Wrappers": "Prompt Templates as Thin Wrappers",
        "User-facing guidance in commands, technical orchestration logic in skills":
            "User-facing guidance in prompt templates, technical orchestration logic in skills",
        "Orchestration logic lives in skill.md": "Orchestration logic lives in SKILL.md",
        "trust Claude to figure out HOW": "trust the coding agent to figure out HOW",
        "Does this duplicate skill.md content?": "Does this duplicate SKILL.md content?",
        "See individual orchestrator `skill.md` files": "See individual orchestrator `SKILL.md` files",
        "`skills/maister-docs-manager/skill.md`": "`skills/maister-docs-manager/SKILL.md`",
        "`codebase-analysis-reporter` subagent": "`maister-codebase-analysis-reporter` subagent",
        "`docs-operator` agent": "`maister-docs-operator` agent",
        "docs-manager skill preloaded": "maister-docs-manager skill preloaded",
        "docs-manager does NOT spawn subagents": "maister-docs-manager does NOT spawn subagents",

        # Pi-native tool names. Keep conceptual lowercase words like glob expansion intact.
        "Read tool renders": "`read` tool renders",
        "Read tool": "`read` tool",
        "Bash tool": "`bash` tool",
        "Edit/Write/Bash tools": "`edit`/`write`/`bash` tools",
        "Read, Grep, Glob, and Bash tools": "`read`, `grep`, `find`, and `bash` tools",
        "Read, Grep, Glob": "`read`, `grep`, `find`",
        "Glob/Grep/Read": "`find`/`grep`/`read`",
        "Glob/Grep": "`find`/`grep`",
        "Glob, Grep, Read": "`find`, `grep`, `read`",
        "Read, Grep": "`read`, `grep`",
        "Glob, Grep": "`find`, `grep`",
        "Grep and Glob": "`grep` and `find`",
        "Grep/Glob": "`grep`/`find`",
        "WebSearch/WebFetch": "`web_search`/`fetch_content`",
        "WebSearch / WebFetch": "`web_search` / `fetch_content`",
        "WebSearch": "`web_search`",
        "WebFetch": "`fetch_content`",
        "Use Glob": "Use `find`",
        "Glob search": "`find` search",
        "Use Grep": "Use `grep`",
        "Grep heuristics": "`grep` heuristics",
        "Grep for": "Use `grep` for",
        "Grep:": "`grep`:",
        "Glob:": "`find`:",
        "File pattern matching with Glob": "File pattern matching with `find`",
        "Code searching with Grep": "Code searching with `grep`",
        "→ Grep": "→ `grep`",
        "**Grep**": "**`grep`**",
        "**Glob**": "**`find`**",
        "**Read**": "**`read`**",
        "**Bash**": "**`bash`**",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)

    # Collapse any namespace duplication introduced by source names plus Pi prefixing.
    text = text.replace("maister-maister-", "maister-")
    text = text.replace("`skills/maister-docs-manager/skill.md`", "`skills/maister-docs-manager/SKILL.md`")

    # Normalize common Maister references after prefixing generated skill/agent files.
    for name in [
        "docs-operator", "project-analyzer", "standards-discover", "standards-update",
        "docs-manager", "codebase-analyzer", "implementation-plan-executor",
        "implementation-verifier", "test-suite-runner", "code-reviewer",
        "code-quality-pragmatist", "production-readiness-checker", "reality-assessor",
        "spec-auditor", "task-classifier", "gap-analyzer", "implementation-planner",
        "specification-creator",
    ]:
        text = text.replace(f"`{name}`", f"`maister-{name}`")
        text = text.replace(f" {name} subagent", f" maister-{name} subagent")
        text = text.replace(f" for {name}", f" for maister-{name}")
    text = text.replace("Invoke the `maister-standards-discover` skill via inline skill `--scope=full`", "Load and execute the `maister-standards-discover` skill inline with `--scope=full`")
    text = text.replace("Invoke the standards-discover skill via inline skill `--scope=full`", "Load and execute the `maister-standards-discover` skill inline with `--scope=full`")

    # Convert leftover Claude-style placeholder calls into valid Pi subagent shape.
    text = re.sub(r'subagent\(\{ agent: "([^"]+)", \.\.\. \}\)', r'subagent({ agent: "\1", task: "..." })', text)

    # Standalone tool-name words in tool lists/headings. Avoid lowercase generic "glob".
    text = re.sub(r"\bGlob\b(?=\s*(?:to|for|with|,|/|\)|$))", "`find`", text)
    text = re.sub(r"\bGrep\b(?=\s*(?:to|for|with|,|/|\)|$))", "`grep`", text)
    text = re.sub(r"\bRead\b(?=\s*(?:to|for|with|,|/|\)|$))", "`read`", text)

    path.write_text(text)
PY

# ============================================================
# 6. Agent tool allowlists & metadata (Issue 02)
# ============================================================
echo "    Adding agent tool allowlists and metadata..."
for agent_file in "$OUT/agents"/*.md; do
  base=$(basename "$agent_file" .md | sed 's/^maister-//')

  case "$base" in
    task-classifier|gap-analyzer|code-reviewer|code-quality-pragmatist|bottleneck-analyzer|spec-auditor|reality-assessor|research-planner|information-gatherer|research-synthesizer|solution-brainstormer|solution-designer|production-readiness-checker|implementation-completeness-checker|project-analyzer|specification-creator|implementation-planner)
      tools_yaml="tools:
  - read
  - grep
  - find
  - ls
  - bash
  - web_search
  - fetch_content
  - get_search_content"
      ;;
    task-group-implementer|docs-operator|html-companion-writer)
      tools_yaml="tools:
  - read
  - grep
  - find
  - ls
  - bash
  - web_search
  - fetch_content
  - get_search_content
  - write
  - edit"
      ;;
    e2e-test-verifier|user-docs-generator)
      tools_yaml="tools:
  - read
  - grep
  - find
  - ls
  - bash
  - web_search
  - fetch_content
  - get_search_content
  - write
  - edit
  - mcp:playwright"
      ;;
    codebase-analysis-reporter|ui-mockup-generator)
      tools_yaml="tools:
  - read
  - grep
  - find
  - ls
  - bash
  - web_search
  - fetch_content
  - get_search_content
  - subagent"
      ;;
    test-suite-runner)
      tools_yaml="tools:
  - read
  - grep
  - find
  - ls
  - bash"
      ;;
    *)
      echo "      Warning: Unknown agent tier for $base, using minimal defaults"
      tools_yaml="tools:
  - read
  - grep
  - find
  - ls
  - bash"
      ;;
  esac

  # Insert metadata after name: line using sed read from temp file
  tmpfile=$(mktemp)
  printf '%s\n' "$tools_yaml" > "$tmpfile"
  printf 'systemPromptMode: append\ninheritProjectContext: true\n' >> "$tmpfile"
  sedi "/^name:/r $tmpfile" "$agent_file"
  rm -f "$tmpfile"
done

# ============================================================
# 7. Remove commands/ directory
# ============================================================
echo "    Removing commands/ directory..."
rm -rf "$OUT/commands"

# ============================================================
# 8. Create Pi-only maister-work skill and prompt templates (Issue 03)
# ============================================================
echo "    Creating Pi-only maister-work skill..."
mkdir -p "$OUT/skills/maister-work"
cat > "$OUT/skills/maister-work/SKILL.md" << 'SKILL_EOF'
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
SKILL_EOF


echo "    Creating prompt templates..."
mkdir -p "$OUT/prompts"

cat > "$OUT/prompts/maister-work.md" << 'PROMPT_EOF'
---
name: maister-work
skill: maister-work
description: Unified entry point — auto-classifies tasks and routes to appropriate workflow.
argument-hint: "[task description | task folder path]"
---

# /maister-work

Run the Maister unified work router for this request:

$@
PROMPT_EOF

cat > "$OUT/prompts/maister-reviews-code.md" << 'PROMPT_EOF'
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
PROMPT_EOF

cat > "$OUT/prompts/maister-reviews-pragmatic.md" << 'PROMPT_EOF'
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
PROMPT_EOF

cat > "$OUT/prompts/maister-reviews-spec-audit.md" << 'PROMPT_EOF'
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
PROMPT_EOF

cat > "$OUT/prompts/maister-reviews-production-readiness.md" << 'PROMPT_EOF'
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
PROMPT_EOF

cat > "$OUT/prompts/maister-reviews-reality-check.md" << 'PROMPT_EOF'
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
PROMPT_EOF

cat > "$OUT/prompts/maister-init.md" << 'PROMPT_EOF'
---
name: maister-init
skill: maister-init
description: Initialize Maister framework with intelligent project analysis
argument-hint: "[--standards-from=PATH]"
---

# /maister-init

Run the injected `maister-init` workflow skill for the user request below. It initializes `.maister/docs/` with analysis and documentation generation.

**Usage**:
- `/maister-init`
- `/maister-init --standards-from=/path/to/other/project`
PROMPT_EOF

cat > "$OUT/prompts/maister-standards-update.md" << 'PROMPT_EOF'
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
PROMPT_EOF

cat > "$OUT/prompts/maister-standards-discover.md" << 'PROMPT_EOF'
---
name: maister-standards-discover
skill: maister-standards-discover
description: Discover coding standards from project configuration files and code patterns
argument-hint: "[--scope=SCOPE]"
---

# /maister-standards-discover

Run the injected `maister-standards-discover` workflow skill for the user request below. It discovers standards from config files, code patterns, documentation, and PRs/CI, then writes them to `.maister/docs/standards/`.

**Usage**:
- `/maister-standards-discover`
- `/maister-standards-discover --scope=full`
PROMPT_EOF

cat > "$OUT/prompts/maister-development.md" << 'PROMPT_EOF'
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
PROMPT_EOF

cat > "$OUT/prompts/maister-performance.md" << 'PROMPT_EOF'
---
name: maister-performance
skill: maister-performance
description: Optimize code speed and efficiency with bottleneck analysis
argument-hint: "[description | task-path] [--from=PHASE]"
---

# /maister-performance

Run the injected `maister-performance` workflow skill for the user request below.

**Usage**:
- `/maister-performance "Optimize slow dashboard queries"`
- `/maister-performance .maister/tasks/performance/2025-10-24-query-opt/ --from=implement`
PROMPT_EOF

cat > "$OUT/prompts/maister-migration.md" << 'PROMPT_EOF'
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
PROMPT_EOF

cat > "$OUT/prompts/maister-research.md" << 'PROMPT_EOF'
---
name: maister-research
skill: maister-research
description: Investigate and document findings with multi-source research
argument-hint: "[question | task-path] [--brainstorm] [--design]"
---

# /maister-research

Run the injected `maister-research` workflow skill for the user request below.

**Usage**:
- `/maister-research "Best React state management in 2026" --brainstorm --design`
- `/maister-research .maister/tasks/research/2026-01-12-auth/ --from=synthesize`

Flags: `--brainstorm` (solution alternatives), `--design` (high-level design)
PROMPT_EOF

cat > "$OUT/prompts/maister-product-design.md" << 'PROMPT_EOF'
---
name: maister-product-design
skill: maister-product-design
description: Interactive feature/product design with visual companion
argument-hint: "[description | task-path] [--research=PATH] [--no-visual]"
---

# /maister-product-design

Run the injected `maister-product-design` workflow skill for the user request below.

**Usage**:
- `/maister-product-design "Design user profile page"`
- `/maister-product-design .maister/tasks/product-design/2026-01-12-profile/ --from=refine`
- `/maister-product-design "Design checkout flow" --research=.maister/tasks/research/2026-01-10-checkout/`
PROMPT_EOF

cat > "$OUT/prompts/maister-quick-plan.md" << 'PROMPT_EOF'
---
name: maister-quick-plan
skill: maister-quick-plan
description: Create an approval-gated plan with standards awareness
argument-hint: "[task description]"
---

# /maister-quick-plan

Run the injected `maister-quick-plan` workflow skill for the user request below.

**Usage**: `/maister-quick-plan "Add email validation to signup form"`

Creates: task breakdown, standards compliance checklist, file modification list
PROMPT_EOF

cat > "$OUT/prompts/maister-quick-dev.md" << 'PROMPT_EOF'
---
name: maister-quick-dev
skill: maister-quick-dev
description: Implement directly with standards awareness (no planning)
argument-hint: "[task description]"
---

# /maister-quick-dev

Run the injected `maister-quick-dev` workflow skill for the user request below.

**Usage**: `/maister-quick-dev "Add email validation to signup form"`
PROMPT_EOF

cat > "$OUT/prompts/maister-quick-bugfix.md" << 'PROMPT_EOF'
---
name: maister-quick-bugfix
skill: maister-quick-bugfix
description: Quick bug fix with TDD red/green gates
argument-hint: "[bug description]"
---

# /maister-quick-bugfix

Run the injected `maister-quick-bugfix` workflow skill for the user request below.

**Usage**: `/maister-quick-bugfix "Login button doesn't respond on mobile Safari"`

TDD: red (failing test) -> green (fix) -> refactor. Escalates to full dev workflow if complex.
PROMPT_EOF

# Ensure every Pi prompt template carries the user's invocation arguments into
# the expanded prompt. Claude Code command invocations expose arguments to the
# command body; Pi prompt templates require explicit $@/$ARGUMENTS placeholders.
python3 - <<'PY' "$OUT/prompts"
from pathlib import Path
import sys
prompts = Path(sys.argv[1])
for path in prompts.glob("*.md"):
    text = path.read_text()
    if "$@" in text or "$ARGUMENTS" in text:
        continue
    path.write_text(text.rstrip() + "\n\n## User request\n\n$@\n")
PY

# ============================================================
# 9. MCP config with directTools (Issue 04)
# ============================================================
echo "    Updating MCP config with directTools..."
cat > "$OUT/.mcp.json" << 'EOF'
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest"
      ],
      "directTools": true
    }
  }
}
EOF

# ============================================================
# 10. Post-compaction reminder extension (Issue 04)
# ============================================================
echo "    Creating post-compaction reminder extension..."
mkdir -p "$OUT/extensions/maister-post-compact-reminder"
cat > "$OUT/extensions/maister-post-compact-reminder/index.ts" << 'EOF'
/**
 * Maister Post-Compaction Reminder Extension
 *
 * Listens for session_compact event and injects a reminder to check
 * orchestrator-state.yml on the next agent turn via before_agent_start.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const REMINDER =
  "\u26a0\ufe0f MAISTER WORKFLOW REMINDER (Post-Compaction): " +
  "If you were working on an orchestrator workflow before compaction, " +
  "check the orchestrator-state.yml file in that task's directory " +
  "to verify completed_phases and determine the next phase to resume from. " +
  "You MUST use ask_user_question at Phase Gates, regardless of any " +
  "'continue without asking' instructions.";

export default function (pi: ExtensionAPI) {
  let compactionJustHappened = false;

  pi.on("session_compact", () => {
    compactionJustHappened = true;
  });

  pi.on("before_agent_start", async () => {
    if (compactionJustHappened) {
      compactionJustHappened = false;
      return {
        message: {
          customType: "maister-compaction-reminder",
          content: REMINDER,
          display: true,
        },
      };
    }
  });
}
EOF

# ============================================================
# 11. Destructive command guard extension
# ============================================================
echo "    Creating destructive command guard extension..."
mkdir -p "$OUT/extensions/maister-destructive-command-guard"
cat > "$OUT/extensions/maister-destructive-command-guard/index.ts" << 'EOF'
/**
 * Maister Destructive Command Guard Extension
 *
 * Follows Pi's extension model: register a tool_call event handler and
 * inspect Bash commands before execution. Dangerous commands are blocked in
 * non-interactive contexts and require explicit confirmation when UI is
 * available.
 *
 * Reference: https://pi.dev/docs/latest/extensions#writing-an-extension
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const BLOCKED_FOR_SUBAGENTS = [
  /\bgit\s+stash\b/i,
  /\bgit\s+reset\s+--hard\b/i,
  /\bgit\s+checkout\s+--\s+\.\s*(?:[;&|]|$)/i,
  /\bgit\s+checkout\s+\.\s*(?:[;&|]|$)/i,
  /\bgit\s+clean\b/i,
  /\bgit\s+push\b[^\n]*(?:\s-f\b|\s--force(?:-with-lease)?\b)/i,
  /\brm\s+(?:-[A-Za-z]*r[A-Za-z]*f[A-Za-z]*|-[A-Za-z]*f[A-Za-z]*r[A-Za-z]*|--recursive\b[^\n]*--force\b|--force\b[^\n]*--recursive\b)/i,
];

const CONFIRM_FOR_MAIN = [
  ...BLOCKED_FOR_SUBAGENTS,
  /\bsudo\b/i,
  /\bchmod\b[^\n]*\b777\b/i,
  /\bchown\b[^\n]*\b-R\b/i,
];

const TRUSTED_SUBAGENTS = new Set([
  "maister-test-suite-runner",
  "maister-e2e-test-verifier",
  "maister-user-docs-generator",
  "maister-docs-operator",
]);

function getSubagentName(): string | undefined {
  return process.env.PI_SUBAGENT_CHILD_AGENT || undefined;
}

function preview(command: string): string {
  return command.length > 500 ? `${command.slice(0, 500)}...` : command;
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return undefined;

    const command = typeof event.input.command === "string" ? event.input.command : "";
    if (!command.trim()) return undefined;

    const subagentName = getSubagentName();
    const isSubagent = process.env.PI_SUBAGENT_CHILD === "1";

    if (isSubagent && !TRUSTED_SUBAGENTS.has(subagentName ?? "")) {
      const isBlocked = BLOCKED_FOR_SUBAGENTS.some((pattern) => pattern.test(command));
      if (isBlocked) {
        return {
          block: true,
          reason: `Destructive command blocked for ${subagentName ?? "subagent"}: ${preview(command)}`,
        };
      }
    }

    const needsConfirmation = CONFIRM_FOR_MAIN.some((pattern) => pattern.test(command));
    if (!needsConfirmation) return undefined;

    if (!ctx.hasUI) {
      return {
        block: true,
        reason: `Destructive command blocked because no interactive UI is available: ${preview(command)}`,
      };
    }

    const allowed = await ctx.ui.confirm(
      "Allow destructive command?",
      `Maister detected a potentially destructive Bash command:\n\n${preview(command)}\n\nOnly allow this if you explicitly intend to modify or delete local state.`,
    );

    if (!allowed) {
      return { block: true, reason: "Destructive command blocked by user" };
    }

    return undefined;
  });
}
EOF

# ============================================================
# 12. Copy install script into output (Issue 05)
# ============================================================
echo "    Copying install script..."
cp "$SCRIPT_DIR/install.sh" "$OUT/"

# ============================================================
# 13. Copy README and add Pi platform notes (Issue 06)
# ============================================================
echo "    Copying README..."
cp "$SCRIPT_DIR/README.md" "$OUT/"

echo "    Sanitizing AGENTS.md for Pi..."
python3 - <<'PY' "$OUT/AGENTS.md"
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()

# Remove Claude Code-only sections from the source plugin guide. Pi equivalents
# are appended below as Platform: Pi notes and implemented as TypeScript extensions.
text = re.sub(r"\n## Hooks\n.*?(?=\n## Claude Code Documentation\n)", "\n", text, flags=re.S)
text = re.sub(r"\n## Claude Code Documentation\n.*?(?=\n---\n\n## Platform: Pi\n|\Z)", "\n", text, flags=re.S)

# General Pi-facing terminology for AGENTS.md.
replacements = {
    "This plugin provides AI-powered Software Development Lifecycle (SDLC) capabilities for Claude Code projects.":
        "This plugin provides AI-powered Software Development Lifecycle (SDLC) capabilities for Pi Coding Agent projects.",
    "- **Workflow Commands**: Slash commands for common SDLC tasks like feature development, bug fixes, and code reviews":
        "- **Prompt Templates**: Slash prompt templates for common SDLC tasks like feature development, bug fixes, and code reviews",
    "These principles guide how we document skills, commands, orchestrators, and agents in this plugin to avoid verbosity and duplication while trusting Claude to reason effectively.":
        "These principles guide how we document skills, prompt templates, orchestrators, and agents in this plugin to avoid verbosity and duplication while trusting the coding agent to reason effectively.",
    "**Trust Claude to reason.** Provide principles and patterns, not prescriptive implementations. Claude can discover technical details from skill.md files when needed—AGENTS.md and commands should guide thinking, not dictate exact steps.":
        "**Trust the coding agent to reason.** Provide principles and patterns, not prescriptive implementations. The agent can discover technical details from SKILL.md files when needed—AGENTS.md and prompt templates should guide thinking, not dictate exact steps.",
    "3. **\"Would Claude need this spelled out?\"** → Probably not, trust reasoning ability":
        "3. **\"Would the agent need this spelled out?\"** → Probably not, trust reasoning ability",
    "Skills are automatically invoked by Claude when appropriate. Details live in each skill's `skill.md` file.":
        "Skills are loaded through Pi skill discovery by `skill:` prompt-template frontmatter or direct `/skill:maister-*` invocation. Details live in each skill's `SKILL.md` file.",
    "## Available Commands": "## Available Prompt Templates",
    "Commands invoke orchestrators and utilities. All orchestrators support `--from=phase` (resume point).":
        "Prompt templates invoke orchestrators and utilities. All orchestrators support `--from=phase` (resume point).",
    "**See**: Individual `commands/` and `skills/*/skill.md` files for detailed documentation.":
        "**See**: Individual `prompts/` and `skills/*/SKILL.md` files for detailed documentation.",
    "| `quick-plan` | Built-in plan mode + standards enforcement: discovers matched standards from INDEX.md during planning and folds a Standards Compliance Checklist into the plan | `skills/quick-plan/SKILL.md` |":
        "| `maister-quick-plan` | Pi approval-gated planning + standards enforcement: discovers matched standards from INDEX.md during planning and folds a Standards Compliance Checklist into the plan | `skills/maister-quick-plan/SKILL.md` |",
    "| `/maister-quick-plan` | `[task description]` | Enter planning mode with standards awareness from INDEX.md |":
        "| `/maister-quick-plan` | `[task description]` | Create an approval-gated plan with standards awareness from INDEX.md |",
    "via parallel `Task` tool calls": "via parallel `subagent({ tasks: [...] })` calls",
    "`/work` command": "`/maister-work` prompt template",
}
for old, new in replacements.items():
    text = text.replace(old, new)

# Normalize generated Maister skill/agent names and paths in overview tables.
skill_names = [
    "codebase-analyzer", "implementation-verifier", "standards-discover", "docs-manager",
    "init", "standards-update", "quick-dev", "quick-bugfix", "development",
    "performance", "migration", "research", "product-design",
]
for name in skill_names:
    text = re.sub(rf"`{re.escape(name)}`(?=\s*\|)", f"`maister-{name}`", text)
    text = text.replace(f"`skills/{name}/", f"`skills/maister-{name}/")

agent_names = [
    "project-analyzer", "docs-operator", "task-classifier", "gap-analyzer",
    "specification-creator", "implementation-planner", "codebase-analysis-reporter",
    "existing-feature-analyzer", "ui-mockup-generator", "e2e-test-verifier",
    "user-docs-generator", "bottleneck-analyzer", "research-planner",
    "information-gatherer", "research-synthesizer", "solution-brainstormer",
    "solution-designer", "implementation-completeness-checker", "test-suite-runner",
    "code-reviewer", "production-readiness-checker", "code-quality-pragmatist",
    "spec-auditor", "reality-assessor",
]
for name in agent_names:
    text = re.sub(rf"`{re.escape(name)}`(?=\s*\|)", f"`maister-{name}`", text)
    text = text.replace(f"`agents/{name}.md`", f"`agents/maister-{name}.md`")

# Fix specific references that are not table cells.
text = text.replace("`docs-manager` skill", "`maister-docs-manager` skill")
text = text.replace("`codebase-analyzer` skill", "`maister-codebase-analyzer` skill")
text = text.replace("`implementation-plan-executor`", "`maister-implementation-plan-executor`")
text = text.replace("`skills/orchestrator-framework/", "`skills/maister-orchestrator-framework/")
text = text.replace("`skills/docs-manager/", "`skills/maister-docs-manager/")
text = text.replace("`skills/implementation-plan-executor/", "`skills/maister-implementation-plan-executor/")
text = text.replace("`skills/init/", "`skills/maister-init/")
text = text.replace("`skills/quick-plan/", "`skills/maister-quick-plan/")
text = text.replace("`skills/quick-dev/", "`skills/maister-quick-dev/")
text = text.replace("`skills/quick-bugfix/", "`skills/maister-quick-bugfix/")
text = text.replace("`skills/maister-docs-manager/skill.md`", "`skills/maister-docs-manager/SKILL.md`")
text = text.replace("individual skill `SKILL.md` files", "individual skill `SKILL.md` files")

path.write_text(text)
PY


echo "    Adding Pi platform notes to AGENTS.md..."
cat >> "$OUT/AGENTS.md" << 'PLATFORM_NOTES'

---

## Platform: Pi

This is the Pi Coding Agent variant. Maister's full workflow experience is available via Pi's native systems.

### Package Dependencies

Install these via `pi install npm:<package>`:
- `pi-subagents` — Sub-agent delegation through the `subagent(...)` tool (replaces Claude Code agent delegation)
- `pi-mcp-adapter` — MCP support (needed for Playwright browser automation)
- `@juicesharp/rpiv-ask-user-question` — Structured user questionnaires with multi-select
- `@juicesharp/rpiv-todo` — 4-state task tracking with dependency visualization
- `pi-web-access` — Web search, content extraction, code search, and URL/GitHub/PDF/video fetching
- `pi-prompt-template-model` — Prompt-template `skill:` frontmatter for reliable `/maister-*` command routing

Optional companion:
- `pi-intercom` — Live parent/supervisor communication for long-running or background subagents that need blocking decisions (`contact_supervisor` via `pi-subagents` integration). Not required for normal Maister workflows.

### Tool Differences from Claude Code

| Claude Code | Pi Equivalent |
|-------------|---------------|
| `AskUserQuestion` | `ask_user_question` (via `@juicesharp/rpiv-ask-user-question`) |
| `TaskCreate` / `TaskUpdate` | `todo` (via `@juicesharp/rpiv-todo`) |
| Claude Code agent delegation with `subagent_type` | `subagent({ agent: "...", task: "..." })` (via `pi-subagents`) |
| Skill tool with `skill:` | Top-level prompt `skill:` frontmatter via `pi-prompt-template-model`; nested skills load inline from Pi skill discovery |
| `Grep` | `grep` (Pi native) |
| `Glob` | `find` (Pi native file discovery; use `grep` for content search) |
| `LS` | `ls` (Pi native) |
| `Read` / `Bash` / `Edit` / `Write` | `read` / `bash` / `edit` / `write` (Pi native lowercase tools) |
| `WebSearch` / `WebFetch` | `web_search` / `fetch_content` (via `pi-web-access`) |
| CLI hooks (bash scripts) | TypeScript extensions (`session_compact`, `tool_call` events) |
| `.claude-plugin/` directory | Not applicable — Pi has no plugin system |

### Key Usage Patterns

- **Top-level Skills**: Prompt templates use `skill: maister-*` frontmatter via `pi-prompt-template-model`; users may also invoke skills directly with `/skill:maister-development`, `/skill:maister-init`, etc.
- **Unified Work Router**: `/maister-work` injects the Pi-only `maister-work` skill, which classifies/resumes work and then loads the selected workflow skill inline.
- **Agents**: Invoked via `subagent({ agent: "maister-task-classifier", task: "...", ... })`
- **Prompt Templates**: Available as `/maister-work`, `/maister-development`, etc. Skill-backed templates inject the correct Maister skill through frontmatter instead of asking the model to run a nested slash command.
- **Multi-select**: Fully supported by `@juicesharp/rpiv-ask-user-question` — used at phase gates in orchestrator workflows

### Correct subagent invocation patterns

Use the `subagent` tool from `pi-subagents` directly. Preferred forms:

```js
// Single subagent
subagent({ agent: "maister-gap-analyzer", task: "Analyze gaps for ..." })

// Parallel subagents
subagent({
  tasks: [
    { agent: "maister-code-reviewer", task: "Review correctness" },
    { agent: "maister-code-quality-pragmatist", task: "Review simplicity" }
  ],
  concurrency: 2
})

// Sequential chain
subagent({
  chain: [
    { agent: "maister-codebase-analysis-reporter", task: "Synthesize findings" },
    { agent: "maister-implementation-planner", task: "Plan from {previous}" }
  ]
})

// Status/control
subagent({ action: "status" })
```

Do not refer to a generic `Task` tool in Pi instructions; that is Claude Code terminology. For MCP direct tools in subagents, use `mcp:<server>` or `mcp:<server>/<tool>` entries in agent frontmatter, e.g. `mcp:playwright`.

### Built-in subagent role mapping

Pi does not provide Claude Code's `Explore` or `general-purpose` built-in agents. Use these Pi subagent roles instead:

| Claude Code role | Pi subagent |
|------------------|-------------|
| `Explore` for codebase reconnaissance | `scout` |
| `general-purpose` for read-only local discovery | `scout` |
| `general-purpose` for external/web research | `researcher` |

### Post-Compaction Reminder

The `extensions/maister-post-compact-reminder/index.ts` extension listens for the `session_compact` event and injects a reminder to check `orchestrator-state.yml` for the active workflow phase. This replaces Claude Code's `post-compact-reminder.sh` hook.

### Destructive Command Protection

The `extensions/maister-destructive-command-guard/index.ts` extension intercepts Bash tool calls with Pi's `tool_call` event and blocks or confirms destructive git/filesystem commands before execution. Agent tool allowlists still restrict subagents that do not need Bash at all.
PLATFORM_NOTES

echo ""
echo "Done! Built Pi Coding Agent variant at:"
echo "  $OUT"