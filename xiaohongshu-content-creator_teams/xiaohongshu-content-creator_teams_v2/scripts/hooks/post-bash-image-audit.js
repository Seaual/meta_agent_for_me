#!/usr/bin/env node
/**
 * PostToolUse (Bash) hook: audit image2 operations.
 */

const fs = require("fs");
const path = require("path");

async function main() {
  let input = "";
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  try {
    const data = JSON.parse(input);
    const tool = data.tool || "";
    const command = data.input?.command || "";

    if (tool !== "Bash" || !command.includes("image2")) {
      console.log(JSON.stringify({ status: "ok", note: "not an image2 command" }));
      process.exit(0);
    }

    const auditLogPath = path.join(".claude", "workspace", "image-audit.log");
    const timestamp = new Date().toISOString();

    const subcommandMatch = command.match(/image2\s+(\w+)/);
    const subcommand = subcommandMatch ? subcommandMatch[1] : "unknown";

    const outputMatch = command.match(/--output\s+["']?([^"'\s]+)["']?/);
    const outputPath = outputMatch ? outputMatch[1] : "unknown";

    const promptMatch = command.match(/--prompt\s+["']([^"']+)["']/);
    const promptText = promptMatch ? promptMatch[1] : "";
    const promptHash = promptText ? require("crypto").createHash("sha256").update(promptText).digest("hex").slice(0, 16) : "none";

    const logLine = `[${timestamp}] image2 ${subcommand} output=${outputPath} prompt_hash=${promptHash}\n`;

    fs.appendFileSync(auditLogPath, logLine);

    console.log(JSON.stringify({ status: "ok", note: "audit logged" }));
    process.exit(0);
  } catch (e) {
    console.log(JSON.stringify({ status: "error", message: e.message }));
    process.exit(0);
  }
}

main();
