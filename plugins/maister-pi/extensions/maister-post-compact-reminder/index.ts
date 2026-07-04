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
