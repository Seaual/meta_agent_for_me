#!/usr/bin/env bash
set -euo pipefail

# infra-hooks-gen 生成脚本
# 用法: bash generate.sh <output_dir> <profile>

OUTPUT_DIR="${1:-.}"
PROFILE="${2:-standard}"

mkdir -p "$OUTPUT_DIR/scripts/hooks"
mkdir -p "$OUTPUT_DIR/.claude"

# 生成 pre-tool-safety.js（所有 Profile 必需）
cat > "$OUTPUT_DIR/scripts/hooks/pre-tool-safety.js" << 'SAFETYEOF'
#!/usr/bin/env node
/**
 * PreToolUse 安全检查 Hook
 * 阻止危险命令执行
 * Exit 0 = 放行, Exit 2 = 阻止
 */

const DANGEROUS_PATTERNS = [
  /rm\s+-rf\s+\//,                    // rm -rf /
  /rm\s+-rf\s+\$/,                    // rm -rf $VAR
  /sk-[a-zA-Z0-9]{20,}/,              // Anthropic API key
  /ghp_[a-zA-Z0-9]{36}/,              // GitHub PAT
  /gho_[a-zA-Z0-9]{36}/,              // GitHub OAuth
  /xox[baprs]-[a-zA-Z0-9-]+/,         // Slack tokens
  /eval\s*\(/,                        // eval injection
  /eval\s+\$/,                        // eval $VAR
];

async function main() {
  let input = '';
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  try {
    const data = JSON.parse(input);
    const tool = data.tool || '';
    const command = data.input?.command || '';

    if (tool === 'Bash' && command) {
      for (const pattern of DANGEROUS_PATTERNS) {
        if (pattern.test(command)) {
          console.log(JSON.stringify({
            decision: 'deny',
            reason: `Blocked: matches dangerous pattern ${pattern}`
          }));
          process.exit(2);
        }
      }
    }

    console.log(JSON.stringify({ decision: 'allow' }));
    process.exit(0);
  } catch (e) {
    console.log(JSON.stringify({ decision: 'allow' }));
    process.exit(0);
  }
}

main();
SAFETYEOF

# 生成 session-summary.js（standard/strict Profile）
if [ "$PROFILE" = "standard" ] || [ "$PROFILE" = "strict" ]; then
  cat > "$OUTPUT_DIR/scripts/hooks/session-summary.js" << 'SUMMARYEOF'
#!/usr/bin/env node
/**
 * Stop Hook: 会话摘要
 * 将关键决策写入 .learnings/
 */

async function main() {
  let input = '';
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  try {
    const data = JSON.parse(input);
    const timestamp = new Date().toISOString();

    // 写入摘要到 .learnings（如果目录存在）
    const fs = await import('fs');
    const path = await import('path');
    const learningsDir = '.learnings';

    if (fs.existsSync(learningsDir)) {
      const summaryFile = path.join(learningsDir, 'last-session.json');
      fs.writeFileSync(summaryFile, JSON.stringify({
        timestamp,
        summary: 'Session completed'
      }, null, 2));
    }

    console.log(JSON.stringify({ status: 'ok' }));
    process.exit(0);
  } catch (e) {
    console.log(JSON.stringify({ status: 'error', message: e.message }));
    process.exit(0);
  }
}

main();
SUMMARYEOF
fi

# 生成 settings.json
echo "=== 生成 settings.json (Profile: $PROFILE) ==="

SETTINGS_FILE="$OUTPUT_DIR/.claude/settings.json"

# 根据 Profile 生成 hooks 配置
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
      },
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

echo "✅ settings.json 已生成: $SETTINGS_FILE"
echo "✅ Hook 脚本已生成: $OUTPUT_DIR/scripts/hooks/"