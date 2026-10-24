/**
 * Keeps agent commits behind the repository's pre-commit hooks (gitleaks,
 * private-key detection, Nix lint). The hooks themselves live in flake.nix;
 * this only stops the model from skipping them.
 */

import { existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const COMMIT = /\bgit\b[^;&|\n]*\bcommit\b/;
const BYPASSES: Array<[RegExp, string]> = [
	[/--no-verify\b/, "--no-verify skips the pre-commit hooks"],
	[/\bcommit\b[^;&|\n]*\s-[a-zA-Z]*n[a-zA-Z]*\b/, "-n skips the pre-commit hooks"],
	[/\bSKIP=/, "SKIP= disables pre-commit hooks"],
	[/\bPRE_COMMIT_ALLOW_NO_CONFIG=/, "PRE_COMMIT_ALLOW_NO_CONFIG= disables the hook config check"],
	[/core\.hooksPath/, "overriding core.hooksPath bypasses the installed hooks"],
];

function hookInstalled(cwd: string): boolean {
	try {
		const hooksDir = execFileSync("git", ["rev-parse", "--git-path", "hooks"], { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
		return existsSync(path.resolve(cwd, hooksDir, "pre-commit"));
	} catch {
		return false;
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return undefined;
		const command = String(event.input.command ?? "");
		if (!COMMIT.test(command) && !/core\.hooksPath/.test(command)) return undefined;

		for (const [pattern, why] of BYPASSES) {
			if (pattern.test(command)) {
				return { block: true, reason: `commit-gate: ${why}. Fix what the hook reports and commit normally.` };
			}
		}
		if (COMMIT.test(command) && !hookInstalled(ctx.cwd)) {
			return {
				block: true,
				reason: "commit-gate: the pre-commit hook is not installed. Run `direnv allow` or `nix develop -c true` in the repo root, then commit.",
			};
		}
		return undefined;
	});
}
