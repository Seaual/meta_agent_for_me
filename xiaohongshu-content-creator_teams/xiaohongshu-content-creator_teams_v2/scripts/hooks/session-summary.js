#!/usr/bin/env node
/**
 * Stop hook: fast no-op by default.
 * Set TEAM_ENABLE_SESSION_SUMMARY=1 to enable summary persistence.
 */

async function main() {
  try {
    if (process.env.TEAM_ENABLE_SESSION_SUMMARY !== "1") {
      console.log(JSON.stringify({ status: "ok", skipped: "disabled" }));
      process.exit(0);
    }

    let input = "";
    for await (const chunk of process.stdin) {
      input += chunk;
    }

    JSON.parse(input || "{}");
    const timestamp = new Date().toISOString();
    const fs = await import("fs");
    const path = await import("path");
    const learningsDir = ".learnings";

    if (fs.existsSync(learningsDir)) {
      const summaryFile = path.join(learningsDir, "last-session.json");
      fs.writeFileSync(summaryFile, JSON.stringify({
        timestamp,
        summary: "Session completed"
      }, null, 2));
    }

    console.log(JSON.stringify({ status: "ok", persisted: true }));
    process.exit(0);
  } catch (e) {
    console.log(JSON.stringify({ status: "error", message: e.message }));
    process.exit(0);
  }
}

main();
