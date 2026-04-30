---
name: infra-hooks-gen
description: |
  Generates settings.json hooks configuration and hook scripts based on
  Profile level and Tech specs. Called by toolsmith-infra in Phase 4a.
  Triggers on: "generate hooks", "生成hooks", "hook配置".
  Do NOT use independently — invoked by toolsmith-infra.
allowed-tools: Read, Write, Bash
---

# Skill: Hooks 配置生成器

## 输入

- `.claude/workspace/profile.txt` — `minimal` / `standard` / `strict`
- `.claude/workspace/phase-2-tech-specs.md` — Hook 配置段（如有自定义 hook）
- `$OUTPUT_DIR` — 目标项目目录

## 执行步骤

### Step 1：读取 Profile 和输出目录

```bash
PROFILE=$(cat .claude/workspace/profile.txt 2>/dev/null || echo "standard")
OUTPUT_DIR=$(cat .claude/workspace/output-dir.txt 2>/dev/null)

[ -z "$OUTPUT_DIR" ] && { echo "🔴 output-dir.txt 为空"; exit 1; }
```

### Step 2：运行生成脚本

```bash
bash .claude/skills/infra-hooks-gen/scripts/generate.sh "$OUTPUT_DIR" "$PROFILE"
```

### Step 3：验证输出

```bash
# 确认 settings.json 存在
[ -f "$OUTPUT_DIR/.claude/settings.json" ] && echo "✅ settings.json" || echo "🔴 settings.json 缺失"

# 确认 hook 脚本存在
[ -f "$OUTPUT_DIR/scripts/hooks/pre-tool-safety.js" ] && echo "✅ pre-tool-safety.js" || echo "🔴 pre-tool-safety.js 缺失"
[ -f "$OUTPUT_DIR/scripts/hooks/session-summary.js" ] || [ "$PROFILE" = "minimal" ] || echo "🔴 session-summary.js 缺失"
[ -f "$OUTPUT_DIR/scripts/hooks/post-write-doc-check.js" ] || [ "$PROFILE" != "strict" ] || echo "🔴 post-write-doc-check.js 缺失"
```

---

## 生成的文件

| 文件 | 用途 | Profile |
|------|------|---------|
| `.claude/settings.json` | 权限 + hooks 配置 | 所有 |
| `scripts/hooks/pre-tool-safety.js` | 安全检查 | 所有 |
| `scripts/hooks/session-summary.js` | 会话摘要 | standard+ |
| `scripts/hooks/post-write-doc-check.js` | 文档提醒 | strict |

---

## settings.json 结构

```json
{
  "skipDangerousModePermissionPrompt": true,
  "permissions": {
    "allow": [
      "Read(**)",
      "Write(**)",
      "Edit(**)",
      "Glob(**)",
      "Grep(**)",
      "Bash(**)",
      "Agent(**)",
      "Skill(**)"
    ]
  },
  "hooks": {
    "PreToolUse": [...],
    "Stop": [...]
  }
}
```

**关键点**：
- `skipDangerousModePermissionPrompt: true` — 跳过危险模式提示
- `permissions.allow` 包含所有常用工具 — 运行时无需确认权限
- hooks 按 Profile 裁剪

---

## Profile 对应的 Hooks

| Profile | PreToolUse (Bash) | Stop (会话摘要) | PostToolUse (Write) |
|---------|-------------------|-----------------|---------------------|
| minimal | ✅ | ❌ | ❌ |
| standard | ✅ | ✅ | ❌ |
| strict | ✅ | ✅ | ✅ |
