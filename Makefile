.PHONY: build build-copilot build-pi validate validate-copilot validate-pi clean watch

build: build-copilot build-pi

build-copilot:
	bash platforms/copilot-cli/build.sh

build-pi:
	bash platforms/pi/build.sh 2>&1 | tee /tmp/maister-build-pi.log
	@! grep -q "Unknown agent tier" /tmp/maister-build-pi.log || (echo "FAIL: Unknown agent tier warning during Pi build" && exit 1)

validate: validate-copilot validate-pi

validate-copilot:
	@echo "Checking no colons in command names..."
	@! grep -r '^name:.*:' plugins/maister-copilot/commands/ 2>/dev/null || (echo "FAIL: colons in command names" && exit 1)
	@echo "Checking no multi-select references..."
	@! grep -ri 'multi.select\|multiSelect' plugins/maister-copilot/skills/ 2>/dev/null || (echo "FAIL: multi-select found in skills" && exit 1)
	@echo "Checking commands are flat (no subdirectories)..."
	@test $$(find plugins/maister-copilot/commands -mindepth 2 -name "*.md" 2>/dev/null | wc -l) -eq 0 || (echo "FAIL: nested command directories found" && exit 1)
	@echo "Checking no CLAUDE.md references in skills..."
	@! grep -ri 'CLAUDE\.md' plugins/maister-copilot/skills/ 2>/dev/null || (echo "FAIL: CLAUDE.md references found in skills" && exit 1)
	@echo "Checking no maister- prefix in copilot command names..."
	@! grep -r '^name: maister-' plugins/maister-copilot/commands/ 2>/dev/null || (echo "FAIL: maister- prefix in command names" && exit 1)
	@echo "Checking no maister: prefixes in copilot variant..."
	@! grep -r 'maister:' plugins/maister-copilot/ --include="*.md" 2>/dev/null || (echo "FAIL: maister: prefix found" && exit 1)
	@echo "All copilot checks passed"

validate-pi:
	@echo "Checking no Claude Code Task tool references..."
	@! grep -r 'Task tool' plugins/maister-pi/agents plugins/maister-pi/skills plugins/maister-pi/prompts --include="*.md" 2>/dev/null || (echo "FAIL: 'Task tool' reference found" && exit 1)
	@echo "Checking no subagent_type references..."
	@! grep -r 'subagent_type' plugins/maister-pi/agents plugins/maister-pi/skills plugins/maister-pi/prompts --include="*.md" 2>/dev/null || (echo "FAIL: subagent_type reference found" && exit 1)
	@echo "Checking no AskUserQuestion references..."
	@! grep -r 'AskUserQuestion' plugins/maister-pi/agents plugins/maister-pi/skills plugins/maister-pi/prompts --include="*.md" 2>/dev/null || (echo "FAIL: AskUserQuestion reference found" && exit 1)
	@echo "Checking no TaskCreate/TaskUpdate references..."
	@! grep -rE 'TaskCreate|TaskUpdate' plugins/maister-pi/agents plugins/maister-pi/skills plugins/maister-pi/prompts --include="*.md" 2>/dev/null || (echo "FAIL: TaskCreate/TaskUpdate reference found" && exit 1)
	@echo "Checking no maister: (colon form) references..."
	@! grep -r 'maister:' plugins/maister-pi/agents plugins/maister-pi/skills plugins/maister-pi/prompts --include="*.md" 2>/dev/null || (echo "FAIL: maister: (colon form) reference found" && exit 1)
	@echo "Checking no CLAUDE.md references..."
	@! grep -r 'CLAUDE\.md' plugins/maister-pi/agents plugins/maister-pi/skills plugins/maister-pi/prompts 2>/dev/null || (echo "FAIL: CLAUDE.md reference found" && exit 1)
	@echo "Checking operator dashboard asset survived the build..."
	@test -f plugins/maister-pi/skills/maister-orchestrator-framework/assets/dashboard.html || (echo "FAIL: dashboard.html missing" && exit 1)
	@echo "Checking HTML report style guide survived the build..."
	@test -f plugins/maister-pi/skills/maister-orchestrator-framework/references/html-report-style.md || (echo "FAIL: html-report-style.md missing" && exit 1)
	@echo "Checking html-companion-writer agent has write/edit tools..."
	@test -f plugins/maister-pi/agents/maister-html-companion-writer.md || (echo "FAIL: maister-html-companion-writer.md missing" && exit 1)
	@grep -A20 '^tools:' plugins/maister-pi/agents/maister-html-companion-writer.md | grep -q '\- write' || (echo "FAIL: html-companion-writer missing write tool" && exit 1)
	@grep -A20 '^tools:' plugins/maister-pi/agents/maister-html-companion-writer.md | grep -q '\- edit' || (echo "FAIL: html-companion-writer missing edit tool" && exit 1)
	@echo "Checking new standards prompt templates exist..."
	@test -f plugins/maister-pi/prompts/maister-standards-update.md || (echo "FAIL: maister-standards-update.md missing" && exit 1)
	@test -f plugins/maister-pi/prompts/maister-standards-discover.md || (echo "FAIL: maister-standards-discover.md missing" && exit 1)
	@echo "Checking visibility-layer prose survived..."
	@grep -q 'html_output' plugins/maister-pi/skills/maister-orchestrator-framework/references/orchestrator-patterns.md || (echo "FAIL: html_output missing from orchestrator-patterns.md" && exit 1)
	@grep -q 'dashboard-data.js' plugins/maister-pi/skills/maister-orchestrator-framework/references/orchestrator-patterns.md || (echo "FAIL: dashboard-data.js missing from orchestrator-patterns.md" && exit 1)
	@echo "All Pi checks passed"

clean:
	rm -rf plugins/maister-copilot/ plugins/maister-pi/

watch:
	fswatch -o plugins/maister/ | xargs -n1 -I{} make build
