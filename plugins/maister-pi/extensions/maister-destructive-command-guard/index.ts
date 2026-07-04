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
