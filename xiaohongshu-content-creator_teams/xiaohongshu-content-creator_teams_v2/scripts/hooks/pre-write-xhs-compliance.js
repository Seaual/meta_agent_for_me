#!/usr/bin/env node
/**
 * PreToolUse (Write) hook: XiaoHongShu platform compliance scan before writing.
 * Exit 0 = allow, Exit 2 = block.
 */

const fs = require("fs");
const path = require("path");

const TARGET_PATTERNS = [
  /xiaohongshu-policy-guard-output\.md$/,
  /content-creator-output\.md$/,
];
const MAX_SCAN_CHARS = 12000;

async function main() {
  let input = "";
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  try {
    const data = JSON.parse(input);
    const tool = data.tool || "";
    const filePath = data.input?.file_path || "";
    const content = data.input?.content || "";

    if (tool !== "Write") {
      console.log(JSON.stringify({ decision: "allow" }));
      process.exit(0);
    }

    const isTarget = TARGET_PATTERNS.some((p) => p.test(filePath));
    if (!isTarget) {
      console.log(JSON.stringify({ decision: "allow" }));
      process.exit(0);
    }

    const scanContent = content.length > MAX_SCAN_CHARS ? content.slice(0, MAX_SCAN_CHARS) : content;

    const rulesPath = path.join(".claude", "data", "xiaohongshu-rules.txt");
    if (!fs.existsSync(rulesPath)) {
      console.log(JSON.stringify({ decision: "allow", note: "xiaohongshu-rules.txt not found" }));
      process.exit(0);
    }

    const rules = fs.readFileSync(rulesPath, "utf-8").split("\n").filter(Boolean);
    const hits = [];
    for (const line of rules) {
      const parts = line.split("|");
      const category = parts[0] || "";
      const pattern = parts[1] || "";
      const suggestion = parts[2] || "";
      const level = parts[3] || "";
      if (!pattern) continue;
      let regex;
      try {
        regex = new RegExp(pattern, "i");
      } catch (reErr) {
        console.error(JSON.stringify({ note: `Invalid regex skipped: ${pattern}` }));
        continue;
      }
      if (regex.test(scanContent)) {
        hits.push({ category, pattern, suggestion, level });
      }
    }

    const fatalHits = hits.filter((h) => h.level === "fatal");
    if (fatalHits.length > 0) {
      console.log(JSON.stringify({
        decision: "deny",
        reason: `Blocked: fatal-level XHS compliance violations: ${fatalHits.map((h) => `${h.category}(${h.pattern})`).join(", ")}`
      }));
      process.exit(2);
    }

    console.log(JSON.stringify({
      decision: "allow",
      note: `xhs-compliance: ${hits.length} non-fatal hits`,
      truncated: content.length > MAX_SCAN_CHARS
    }));
    process.exit(0);
  } catch (e) {
    console.log(JSON.stringify({ decision: "allow", note: "parse error, allowing" }));
    process.exit(0);
  }
}

main();
