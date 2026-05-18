#!/usr/bin/env node
/**
 * PreToolUse (Write) hook: content safety scan before writing.
 * Exit 0 = allow, Exit 2 = block.
 */

const fs = require("fs");
const path = require("path");

const TARGET_PATTERNS = [
  /keyword-guard-output\.md$/,
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

    const wordListPath = path.join(".claude", "data", "sensitive-words.txt");
    if (!fs.existsSync(wordListPath)) {
      console.log(JSON.stringify({ decision: "allow", note: "sensitive-words.txt not found" }));
      process.exit(0);
    }

    const wordList = fs.readFileSync(wordListPath, "utf-8").split("\n").filter(Boolean);
    const hits = [];
    for (const line of wordList) {
      const parts = line.split("|");
      const level = parts[0] || "";
      const word = parts[2] || "";
      if (!word) continue;
      if (scanContent.includes(word)) {
        hits.push({ level, word });
      }
    }

    const fatalHits = hits.filter((h) => h.level === "fatal");
    if (fatalHits.length > 0) {
      console.log(JSON.stringify({
        decision: "deny",
        reason: `Blocked: fatal-level sensitive words detected: ${fatalHits.map((h) => h.word).join(", ")}`
      }));
      process.exit(2);
    }

    console.log(JSON.stringify({
      decision: "allow",
      note: `content-safety: ${hits.length} non-fatal hits`,
      truncated: content.length > MAX_SCAN_CHARS
    }));
    process.exit(0);
  } catch (e) {
    console.log(JSON.stringify({ decision: "allow", note: "parse error, allowing" }));
    process.exit(0);
  }
}

main();
