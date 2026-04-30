#!/usr/bin/env bash
set -euo pipefail

# Generate runtime hooks and .claude/settings.json for a produced team.
# Usage: bash generate.sh <output_dir> <profile>

OUTPUT_DIR="${1:-.}"
PROFILE="${2:-standard}"

mkdir -p "$OUTPUT_DIR/scripts/hooks"
mkdir -p "$OUTPUT_DIR/.claude"

cat > "$OUTPUT_DIR/scripts/hooks/pre-tool-safety.js" << 'SAFETYEOF'
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
SAFETYEOF

if [ "$PROFILE" = "standard" ] || [ "$PROFILE" = "strict" ]; then
  cat > "$OUTPUT_DIR/scripts/hooks/session-summary.js" << 'SUMMARYEOF'
#!/usr/bin/env node
/**
 * Stop hook: persist a lightweight session summary when .learnings exists.
 */

async function main() {
  let input = "";
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  try {
    JSON.parse(input);
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

    console.log(JSON.stringify({ status: "ok" }));
    process.exit(0);
  } catch (e) {
    console.log(JSON.stringify({ status: "error", message: e.message }));
    process.exit(0);
  }
}

main();
SUMMARYEOF
fi

if [ "$PROFILE" = "strict" ]; then
  cat > "$OUTPUT_DIR/scripts/hooks/post-write-doc-check.js" << 'DOCCHECKEOF'
#!/usr/bin/env node
/**
 * PostToolUse hook: remind users to update docs after code/config writes.
 */

const DOC_SUFFIXES = [".md", ".mdx", ".txt", ".rst", ".adoc", ".doc", ".docx"];
const CODE_SUFFIXES = [
  ".js", ".jsx", ".ts", ".tsx", ".py", ".sh", ".ps1", ".java", ".go", ".rs",
  ".rb", ".php", ".c", ".cc", ".cpp", ".h", ".hpp", ".json", ".yaml", ".yml",
  ".toml", ".ini"
];

function collectStringValues(value, results = []) {
  if (typeof value === "string") {
    results.push(value);
    return results;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      collectStringValues(item, results);
    }
    return results;
  }

  if (value && typeof value === "object") {
    for (const nested of Object.values(value)) {
      collectStringValues(nested, results);
    }
  }

  return results;
}

function looksLikePath(value) {
  return /[\\/]/.test(value) || /\.[a-z0-9]{1,8}$/i.test(value);
}

function normalizePath(value) {
  return value.replace(/\\/g, "/");
}

function isDocPath(filePath) {
  const normalized = normalizePath(filePath).toLowerCase();
  return DOC_SUFFIXES.some((suffix) => normalized.endsWith(suffix));
}

function isCodeOrConfigPath(filePath) {
  const normalized = normalizePath(filePath).toLowerCase();
  return CODE_SUFFIXES.some((suffix) => normalized.endsWith(suffix));
}

async function main() {
  let input = "";
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  try {
    const data = JSON.parse(input);
    const paths = collectStringValues(data).filter(looksLikePath);
    const touchedDocs = paths.some(isDocPath);
    const touchedCode = paths.some(isCodeOrConfigPath);

    if (touchedCode && !touchedDocs) {
      console.log(JSON.stringify({
        status: "reminder",
        reminder: "Code or config changed. Review whether README.md, CLAUDE.md, or CONVENTIONS.md should be updated."
      }));
      process.exit(0);
    }

    console.log(JSON.stringify({ status: "ok" }));
    process.exit(0);
  } catch {
    console.log(JSON.stringify({ status: "ok" }));
    process.exit(0);
  }
}

main();
DOCCHECKEOF
fi

SETTINGS_FILE="$OUTPUT_DIR/.claude/settings.json"
echo "=== Generating settings.json (Profile: $PROFILE) ==="

if [ "$PROFILE" = "minimal" ]; then
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "skipDangerousModePermissionPrompt": true,
  "permissions": {
    "defaultMode": "bypassPermissions",
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "Bash",
      "Agent",
      "Skill"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node scripts/hooks/pre-tool-safety.js",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
EOF
elif [ "$PROFILE" = "standard" ]; then
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "skipDangerousModePermissionPrompt": true,
  "permissions": {
    "defaultMode": "bypassPermissions",
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "Bash",
      "Agent",
      "Skill"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node scripts/hooks/pre-tool-safety.js",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node scripts/hooks/session-summary.js",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
EOF
elif [ "$PROFILE" = "strict" ]; then
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "skipDangerousModePermissionPrompt": true,
  "permissions": {
    "defaultMode": "bypassPermissions",
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "Bash",
      "Agent",
      "Skill"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node scripts/hooks/pre-tool-safety.js",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "node scripts/hooks/post-write-doc-check.js",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node scripts/hooks/session-summary.js",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
EOF
else
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "skipDangerousModePermissionPrompt": true,
  "permissions": {
    "defaultMode": "bypassPermissions",
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "Bash",
      "Agent",
      "Skill"
    ]
  },
  "hooks": {}
}
EOF
fi

chmod +x "$OUTPUT_DIR/scripts/hooks/"*.js 2>/dev/null || true
echo "Generated $SETTINGS_FILE"
echo "Generated runtime hooks in $OUTPUT_DIR/scripts/hooks/"
