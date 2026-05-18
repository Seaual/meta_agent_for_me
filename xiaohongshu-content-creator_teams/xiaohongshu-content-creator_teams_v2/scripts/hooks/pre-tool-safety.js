#!/usr/bin/env node
/**
 * PreToolUse safety hook.
 * Exit 0 = allow, Exit 2 = block.
 */

const DANGEROUS_PATTERNS = [
  /rm\s+-rf\s+\//,
  /rm\s+-rf\s+\$/,
  /sk-[a-zA-Z0-9]{20,}/,
  /ghp_[a-zA-Z0-9]{36}/,
  /gho_[a-zA-Z0-9]{36}/,
  /xox[baprs]-[a-zA-Z0-9-]+/,
  /eval\s*\(/,
  /eval\s+\$/,
];

async function main() {
  let input = "";
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  try {
    const data = JSON.parse(input);
    const tool = data.tool || "";
    const command = data.input?.command || "";

    if (tool === "Bash" && command) {
      for (const pattern of DANGEROUS_PATTERNS) {
        if (pattern.test(command)) {
          console.log(JSON.stringify({
            decision: "deny",
            reason: `Blocked: matches dangerous pattern ${pattern}`
          }));
          process.exit(2);
        }
      }
    }

    console.log(JSON.stringify({ decision: "allow" }));
    process.exit(0);
  } catch {
    console.log(JSON.stringify({ decision: "allow" }));
    process.exit(0);
  }
}

main();
