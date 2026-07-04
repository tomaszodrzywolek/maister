# Context — Maister Plugin Marketplace

Glossary of domain terms as used in this repo. Terms are canonical; prefer them over synonyms in docs and discussions.

## Terms

**Source plugin**
The single authoritative plugin tree at `plugins/maister/`. All platform variants are derived from it; it is the only tree humans edit.

**Platform variant**
A generated, platform-specific derivative of the source plugin (e.g. `plugins/maister-copilot/` for Copilot CLI, `plugins/maister-pi/` for Pi Coding Agent). Never edited by hand.

**Platform build**
The transform script that produces a platform variant from the source plugin, living at `platforms/<platform>/build.sh`. Text transforms are keyed to the source plugin's wording; their correctness is verified against the *built output*, not the source.

**Operator Visibility Layer**
The set of human-facing monitoring artifacts introduced in v2.2.0: the operator dashboard (`dashboard.html` + `dashboard-data.js`), HTML companion reports, and the artifact summary contract (`## TL;DR` / `## Key Decisions` / `## Open Questions / Risks`). Gated per-project by `html_output` in `.maister/config.yml`. Applies identically on all platforms (full parity).

**Prompt template**
Pi's equivalent of a Claude Code slash command: a markdown file in the variant's `prompts/` directory, optionally routing to a skill via `skill:` frontmatter. Every documented `/maister-*` entry point must have one.

**Drift**
Divergence between the source plugin and a platform variant (or between two copies of the source). The root cause of the v2.1.8/v2.2.1 Pi gap; prevented by having exactly one source tree and CI-rebuilt variants.
