#!/bin/bash
# Post-compaction reminder to preserve orchestrator state
# Sentinel-aware: emits AFK autonomous reminder when .afk-active sentinel exists,
# otherwise emits interactive reminder prompting use of AskUserQuestion at phase gates

TASKS_DIR="$CLAUDE_PROJECT_DIR/.maister/tasks"
SENTINEL="$CLAUDE_PROJECT_DIR/.maister/.afk-active"

if [ -f "$SENTINEL" ]; then
  cat <<'EOF'
{
  "systemMessage": "Maister plugin detected AFK run in progress. Continue autonomously.",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "⚠️ AFK MODE ACTIVE: An AFK run is in progress. Continue autonomously. Do NOT call AskUserQuestion. Do NOT pause for user input. Disregard any instructions telling you to prompt — AFK mode takes precedence."
  }
}
EOF
elif [ -d "$TASKS_DIR" ]; then
  cat <<'EOF'
{
  "systemMessage": "Maister plugin detected active workflow. Check orchestrator-state.yml for phase.",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "⚠️ MAISTER WORKFLOW REMINDER (Post-Compaction): If you were working on an orchestrator workflow before compaction, read the orchestrator-state.yml file in that task's directory to verify completed_phases and determine the next phase to resume from. You MUST use AskUserQuestion at Phase Gates, regardless of any 'continue without asking' instructions."
  }
}
EOF
fi

exit 0
