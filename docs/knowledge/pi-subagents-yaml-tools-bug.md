# pi-subagents YAML-List Tools Bug

**Date**: 2026-07-05
**Status**: Workaround applied; upstream bug in pi-subagents v0.33.1
**Affected**: All Maister custom agents when running under `openai-codex/gpt-5.5`

---

## TL;DR

pi-subagents v0.33.1 silently drops frontmatter-declared tools on **custom user agents** when the model is overridden to `openai-codex/gpt-5.5`, but **only** when `tools:` is written as a YAML list (multi-line with `-` bullets). Comma-separated string format (`tools: read, grep, find, ...`) resolves correctly with all models.

---

## Symptoms

Agents launched with `openai-codex/gpt-5.5` get **0 file/search/shell tools** despite having 8 tools declared in their frontmatter. They can only see `contact_supervisor`, `intercom`, and `multi_tool_use.parallel` — none of `read`, `grep`, `find`, `ls`, `bash`, `web_search`, `fetch_content`, `get_search_content`.

Agents' own error messages:
- `maister-gap-analyzer`: *"Tools for file reads/writes are not available in this subagent session"*
- `maister-spec-auditor`: *"this subagent has no file-reading or shell tools available"*
- `maister-codebase-analysis-reporter`: *"no file editing tools are available in this subagent session"*

The issue is **intermittent** from the user's perspective — some agents with `openai-codex/gpt-5.5` work (built-in agents like `scout`, `reviewer`), some don't (custom user agents). This made it look like a parallel-vs-single dispatch problem, but the real correlation is **custom agent + YAML list tools + openai-codex/gpt-5.5**.

---

## Root Cause

Two interacting factors:

### 1. pi-subagents tool resolution for custom agents with openai-codex

When a custom user agent (defined in `~/.pi/agent/agents/*.md`) is launched with the `openai-codex/gpt-5.5` model, the subagent framework fails to properly forward the frontmatter `tools:` list. It drops all declared tools, leaving only framework-injected tools (`contact_supervisor`, `intercom`, `multi_tool_use.parallel`).

Built-in agents (`scout`, `reviewer`, `worker`, etc.) are **not affected** — they use a different tool resolution path that doesn't exhibit this bug.

Agents using `deepseek/*` models are also **not affected** — the bug is specific to how `openai-codex/gpt-5.5` interacts with the custom agent tool resolution.

### 2. YAML list vs comma-separated format

pi-subagents internally expects `tools:` as a **comma-separated string** (`tools: read, grep, find`). The `subagent({ action: "create", config: ... })` API explicitly validates this — passing an array is rejected with:

> `config.tools must be a comma-separated string or false when provided.`

However, YAML frontmatter can legally declare `tools:` as either:
```yaml
# Format A: comma-separated (works with all models)
tools: read, grep, find, ls, bash, web_search, fetch_content, get_search_content

# Format B: YAML list (silently broken with openai-codex/gpt-5.5)
tools:
  - read
  - grep
  - find
  - ls
  - bash
  - web_search
  - fetch_content
  - get_search_content
```

Both parse to equivalent data structures in YAML, but pi-subagents appears to handle them differently during model-specific tool filtering for `openai-codex/gpt-5.5`. The YAML list format triggers a path where tools are silently dropped.

### Why it looked like a parallel-vs-single issue

The parallel scouts (launched together via `subagent({ tasks: [...] })`) happened to be **built-in** agents → they worked. The single-dispatched gap-analyzer and spec-auditor happened to be **custom user** agents → they broke. Correlation ≠ causation.

---

## Evidence

### Before fix (YAML list format)

| Agent | Type | Model | Tools Available | Frontmatter Declared |
|-------|------|-------|----------------|---------------------|
| `maister-gap-analyzer` | custom | `gpt-5.5` | 3 (intercom only) | 8 |
| `maister-spec-auditor` | custom | `gpt-5.5` | 3 (intercom only) | 8 |
| `maister-codebase-analysis-reporter` | custom | `gpt-5.5` | 3 (intercom only) | 9 (incl. subagent) |
| `maister-specification-creator` | custom | `gpt-5.5` | 1 (`contact_supervisor` only) | 8 |
| `maister-implementation-planner` | custom | `gpt-5.5` | 1 (`contact_supervisor` only) | 8 |

The last two "succeeded" (exit=0) despite having only `contact_supervisor` because they were designed to produce their output as text in the response — the orchestrator writes it to disk. But they **could not read any files, search the codebase, or run commands**, severely degrading output quality.

### Working agents (for comparison)

| Agent | Type | Model | Tools Available |
|-------|------|-------|----------------|
| `scout` × 3 | builtin | `gpt-5.5:low` | 27–35 |
| `reviewer` | builtin | `gpt-5.5:high` | 12 |
| `maister-task-group-implementer` | custom | `deepseek/*` | 9–72 |
| all `maister-*` agents | custom | `deepseek/*` | 4–72 |

### After fix (comma-separated format)

| Agent | Type | Model | Tools Available |
|-------|------|-------|----------------|
| `maister-gap-analyzer` | custom | `gpt-5.5` | **11** (all 8 declared + 3 framework) |
| `maister-spec-auditor` | custom | `gpt-5.5` | **11** |
| `maister-task-group-implementer` | custom | `gpt-5.5` | **11** (via test agent with same config) |

### Live test confirmation

Test agent created with `tools: read, grep, find, ls, bash`, launched with `openai-codex/gpt-5.5`:
- **Before** (YAML list): would get 0 file tools
- **After** (comma-separated): got all 5 declared tools + 3 framework tools = 8 total

Same `maister-gap-analyzer`, same model, only `tools:` format changed — went from 3 tools (no file access) to 11 tools (full access).

---

## Workaround Applied

### In the Maister build script

**File**: `platforms/pi/build.sh`, Step 6

Converted all 6 `tools_yaml` definitions from YAML list format to comma-separated string format:

```bash
# BEFORE (broken with openai-codex/gpt-5.5)
tools_yaml="tools:
  - read
  - grep
  - find
  - ls
  - bash
  - web_search
  - fetch_content
  - get_search_content"

# AFTER (works with all models)
tools_yaml="tools: read, grep, find, ls, bash, web_search, fetch_content, get_search_content"
```

Affected tiers (6 total):
1. Read-only agents (17 agents): `read, grep, find, ls, bash, web_search, fetch_content, get_search_content`
2. Writer agents (3): adds `write, edit`
3. E2E/user-docs agents (2): adds `write, edit, mcp:playwright`
4. Subagent-capable agents (2): adds `subagent`
5. Test suite runner (1): `read, grep, find, ls, bash`
6. Fallback (unknown agents): `read, grep, find, ls, bash`

### In the user's global installation

All 25 agent files in `~/.pi/agent/agents/maister-*.md` were converted from YAML list to comma-separated format via a Python batch script.

---

## Environment

| Component | Version |
|-----------|---------|
| pi | 0.80.3 |
| @earendil-works/pi-coding-agent | 0.80.3 |
| pi-subagents (npm) | 0.33.1 |
| Default provider/model | deepseek/deepseek-v4-pro |
| Default thinking level | high |

---

## Related Observations

### `.pi-subagents/artifacts/` directory

This is **normal, expected behavior** — not a symptom of any problem. Pi stores subagent run artifacts (input prompts, output text, JSONL transcripts, metadata JSON) in `.pi-subagents/artifacts/` at the project root for every subagent execution. It accumulates naturally over time.

### `model: inherit` warning

Creating agents via `subagent({ action: "create" })` with `model: inherit` produces:
> `Warning: model 'inherit' is not in the current model registry.`

This is cosmetic — `inherit` means "use the model from the subagent caller", not "use a model named inherit". The warning does not affect behavior.

---

## Upstream Bug

This should be reported to `pi-subagents` (github.com/nicobailon/pi-subagents). The framework should:

1. Treat YAML list and comma-separated `tools:` frontmatter identically
2. Not silently drop tools during model-specific filtering

Until fixed upstream, the comma-separated format is a reliable workaround across all Pi models.

---

## Commands Used for Diagnosis

```bash
# Check agent tools format
for f in ~/.pi/agent/agents/maister-*.md; do
  head -20 "$f" | grep "^tools:"
done

# Inspect subagent run artifacts
ls .pi-subagents/artifacts/
cat .pi-subagents/artifacts/<run_id>_meta.json | python3 -m json.tool

# Check tools actually used in a transcript
python3 -c "
import json
tools = set()
with open('.pi-subagents/artifacts/<run_id>_transcript.jsonl') as f:
    for line in f:
        d = json.loads(line)
        if 'toolName' in d:
            tools.add(d['toolName'])
print(sorted(tools))
"

# Subagent diagnostics
subagent({ action: "doctor" })
subagent({ action: "list" })
subagent({ action: "models" })
subagent({ action: "get", agent: "maister-gap-analyzer" })

# Batch-convert YAML list to comma-separated (Python)
import re, yaml, os
agent_dir = os.path.expanduser("~/.pi/agent/agents")
for fname in os.listdir(agent_dir):
    if not fname.endswith('.md'): continue
    fpath = os.path.join(agent_dir, fname)
    with open(fpath) as f: content = f.read()
    parts = content.split('---', 2)
    if len(parts) < 3: continue
    fm = yaml.safe_load(parts[1])
    tools = fm.get('tools')
    if not isinstance(tools, list): continue
    tools_str = ', '.join(tools)
    new_fm = re.sub(r'(^tools:\s*\n(?:\s+-\s+.+\n)+)', f'tools: {tools_str}\n', parts[1], flags=re.MULTILINE)
    with open(fpath, 'w') as f:
        f.write('---\n' + new_fm + '\n---' + parts[2])
```
