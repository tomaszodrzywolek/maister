# Maister for Pi

**Structured, standards-aware development workflows for the Pi coding agent.**

Maister provides AI-powered SDLC capabilities for Pi users: feature development, bug fixes, code reviews, performance optimization, migrations, research, and product design — all with intelligent planning, standards enforcement, and verification.

## Prerequisites

- [Pi](https://github.com/terminal-copilot/pi) installed and configured
- Required Pi packages installed by `install.sh` (including `pi-web-access` and `pi-prompt-template-model`)

## Installation

### Quick Install (from this directory)

```bash
# Global install (available in all projects)
./install.sh --global

# Or project-local install
./install.sh /path/to/your-project
# e.g. ./install.sh .
```

### Build + Install from Repository Root

```bash
# Build the Pi variant (from maister repository root)
make build

# Navigate to the output
cd plugins/maister-pi

# Install
./install.sh
```

### Package Dependencies

The install script will optionally run `pi install` for these packages (you will be prompted during installation):

```bash
pi install npm:pi-subagents
pi install npm:pi-mcp-adapter
pi install npm:@juicesharp/rpiv-ask-user-question
pi install npm:@juicesharp/rpiv-todo
pi install npm:pi-web-access
pi install npm:pi-prompt-template-model
```

Optional companion for long-running/background subagent workflows:

```bash
pi install npm:pi-intercom
```

`pi-intercom` lets subagents contact the parent/supervisor session for blocking decisions while they are running. Maister does not require it for normal foreground workflows.

## Quick Start

### 1. Initialize Maister in Your Project

```bash
/maister-init
```

This discovers your project's coding standards, analyzes the codebase, and generates `.maister/docs/`.

### 2. Start a Development Task

```bash
# Unified entry point — auto-classifies your task
/maister-work "Fix login timeout error on mobile"

# Or use the specific workflow directly
/maister-development "Add user authentication with email/password"
```

### 3. Use Quick Commands for Small Tasks

```bash
/maister-quick-plan "Add email validation to signup form"
/maister-quick-dev "Update button styles"
/maister-quick-bugfix "Login button doesn't respond on mobile Safari"
```

### 4. Run Reviews & Audits

```bash
/maister-reviews-code src/ --scope=security
/maister-reviews-pragmatic src/
/maister-reviews-spec-audit .maister/tasks/.../implementation/spec.md
/maister-reviews-reality-check .maister/tasks/.../
/maister-reviews-production-readiness src/ --target=production
```

### 5. Advanced Workflows

```bash
# Performance optimization
/maister-performance "Optimize slow dashboard queries"

# Code migration
/maister-migration "Migrate from Redux to Zustand" --type=code

# Research
/maister-research "Best React state management in 2026" --brainstorm --design

# Product design
/maister-product-design "Design user profile page"
```

## Available Commands

| Command | Purpose |
|---------|---------|
| `/maister-work` | Unified entry point — auto-classifies tasks |
| `/maister-init` | Initialize Maister framework |
| `/maister-development` | Full spec → plan → implement → verify workflow |
| `/maister-performance` | Performance optimization |
| `/maister-migration` | Code/data/architecture migrations |
| `/maister-research` | Multi-source research |
| `/maister-product-design` | Interactive product/feature design |
| `/maister-quick-plan` | Lightweight planning |
| `/maister-quick-dev` | Direct implementation |
| `/maister-quick-bugfix` | TDD-driven bug fixes |
| `/maister-reviews-code` | Code quality, security, performance analysis |
| `/maister-reviews-pragmatic` | Over-engineering detection |
| `/maister-reviews-spec-audit` | Specification audit |
| `/maister-reviews-reality-check` | Completion validation |
| `/maister-reviews-production-readiness` | Pre-deployment verification |

## Global vs Local Install

- **Global** (`install.sh --global`): Installs to `~/.pi/agent/` — available in all your projects
- **Project-local** (`install.sh <PROJECT_PATH>`): Installs to `.pi/` in the specified directory — scoped to that project

## Documentation

Full Maister documentation is available in the repository:

- [PRD](prd/pi-coding-agent-platform.md) — Product Requirements Document
- [AGENTS.md](AGENTS.md) — Complete plugin documentation with all skills, agents, and workflows
- The `.maister/docs/` directory in your project (after running `/maister-init`)

## Architecture

Maister for Pi follows the same architecture as the Claude Code variant, with Pi-native replacements:

- **Prompt templates** (`/maister-*` commands) use `skill:` frontmatter via `pi-prompt-template-model` for deterministic workflow routing
- **Skills** (`/skill:maister-*`) provide orchestrated workflows
- **Sub-agents** (`subagent({ agent: "...", ... })`) perform specialized tasks
- **Extensions** (`maister-post-compact-reminder`, `maister-destructive-command-guard`) replace Claude Code hooks
- **`AGENTS.md`** provides the LLM with context about available capabilities

## Runtime Compatibility Notes

Validated against current package schemas:

- `pi-subagents@0.33.1` sets `PI_SUBAGENT_CHILD=1` and `PI_SUBAGENT_CHILD_AGENT=<agent-name>` in child processes, which the destructive-command guard uses.
- Pi loads TypeScript extensions directly from `.pi/extensions/**/index.ts` via the documented extension loader.
- `@juicesharp/rpiv-todo@1.20.0` supports `blockedBy`, `addBlockedBy`, `removeBlockedBy`, `owner`, `metadata`, and the `pending` / `in_progress` / `completed` / `deleted` status set used by Maister.
- `@juicesharp/rpiv-ask-user-question@1.20.0` supports `header`, per-option `preview`, and `multiSelect`; keep calls within 1-4 questions and 2-4 options per question.

## License

See [LICENSE](../../LICENSE) in the repository root.