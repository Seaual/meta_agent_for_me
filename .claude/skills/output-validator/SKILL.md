---
name: output-validator
description: |
  Validates generated Agent Team output: frontmatter, permissions, hooks,
  slash commands, self-improving, instincts. Called by toolsmith-assembler
  after all files are generated.
  Triggers on: "validate output", "校验输出", "output check", "质量自检".
  Do NOT use for Sentinel scoring (use sentinel-score instead).
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Skill: Output Validator — 输出校验器

## 概述

对生成的 Agent Team 执行全面质量自检，覆盖：格式合规、权限一致性、Slash Commands 完整性、Hook 完整性、self-improving 一致性、Instincts 完整性。

由 toolsmith-assembler 在所有文件生成后调用。修复能力有限的问题直接修复，复杂问题记录到日志供 Sentinel 处理。

---

## 输入

- `$OUTPUT_DIR` — 从 `.claude/workspace/output-dir.txt` 读取
- `profile.txt` — 运行时 Profile
- `self-improving.txt` — 是否启用自我改进
- `instincts-enabled.txt` — 是否启用 Instincts

---

## 检查项

### 1. 基础格式

```bash
cd "$OUTPUT_DIR"
PASS=true

for f in .claude/agents/*.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q "^---$" || { echo "🔴 frontmatter: $f"; PASS=false; }
  grep -q "^name:" "$f"          || { echo "🔴 缺 name: $f"; PASS=false; }
  grep -q "^description:" "$f"   || { echo "🔴 缺 description: $f"; PASS=false; }
  grep -q "^allowed-tools:" "$f" || { echo "🔴 缺 allowed-tools: $f"; PASS=false; }
done

for f in .claude/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q "^---$" || { echo "🔴 frontmatter: $f"; PASS=false; }
done

grep -rn "TODO\|\[待填写\]\|PLACEHOLDER" .claude/ 2>/dev/null | grep -v ".git" \
  && echo "🟡 发现占位符" || echo "✅ 无占位符"

[ -f "CONVENTIONS.md" ] || { echo "🔴 缺 CONVENTIONS.md"; PASS=false; }
[ -f "README.md" ]      || { echo "🔴 缺 README.md"; PASS=false; }
```

### 2. 权限一致性

对每个 agent，检查正文中的写入/执行动作是否有对应的 allowed-tools，自动修正。

### 3. Slash Commands 完整性

```bash
COMMANDS_DIR=".claude/commands"
AGENTS_DIR=".claude/agents"

[ -d "$COMMANDS_DIR" ]          || { echo "❌ 缺 commands/"; PASS=false; }
[ -f "$COMMANDS_DIR/team.md" ]  || { echo "❌ 缺 commands/team.md"; PASS=false; }

for f in "$AGENTS_DIR"/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  [ -f "$COMMANDS_DIR/$name" ] || { echo "❌ 缺 commands/$name"; PASS=false; }
done
```

### 4. Hook 完整性 + 权限配置

```bash
PROFILE=$(cat ../.claude/workspace/profile.txt 2>/dev/null || echo "standard")

[ -f ".claude/settings.json" ] || { echo "🔴 缺 settings.json"; PASS=false; }

# 检查权限配置
grep -q '"skipDangerousModePermissionPrompt"' ".claude/settings.json" 2>/dev/null \
  || { echo "🔴 缺 skipDangerousModePermissionPrompt"; PASS=false; }
grep -q '"permissions"' ".claude/settings.json" 2>/dev/null \
  || { echo "🔴 缺 permissions 配置"; PASS=false; }
grep -q '"allow"' ".claude/settings.json" 2>/dev/null \
  || { echo "🔴 缺 permissions.allow"; PASS=false; }

# 检查 hooks 配置
grep -q '"hooks"' ".claude/settings.json" 2>/dev/null || { echo "🔴 无 hooks 配置"; PASS=false; }

[ -f "scripts/hooks/pre-tool-safety.js" ] || { echo "🔴 缺安全检查 hook"; PASS=false; }

if [ "$PROFILE" = "standard" ] || [ "$PROFILE" = "strict" ]; then
  [ -f "scripts/hooks/session-summary.js" ] || { echo "🔴 缺会话摘要 hook"; PASS=false; }
fi

if [ "$PROFILE" = "strict" ]; then
  [ -f "scripts/hooks/post-write-doc-check.js" ] || { echo "🔴 缺文档提醒 hook"; PASS=false; }
fi
```

### 5. Self-Improving 一致性

```bash
SELF_IMPROVING=$(cat ../.claude/workspace/self-improving.txt 2>/dev/null || echo "no")
[ "$SELF_IMPROVING" = "yes" ] && {
  [ -d ".claude/skills/self-improving-agent" ] || echo "🔧 需要 self-improving skill"
  [ -d ".learnings" ]                          || echo "🔧 需要 .learnings/"
  grep -q "@.claude/skills/self-improving-agent" "CLAUDE.md" || echo "🔧 需要 @引用"
  # 自动修复逻辑（从全局复制、创建目录、插入引用）同 v7
}
```

### 6. Instincts 完整性（v8.1）

```bash
INSTINCTS=$(cat ../.claude/workspace/instincts-enabled.txt 2>/dev/null || echo "no")
[ "$INSTINCTS" = "yes" ] && {
  [ -d ".learnings/entries" ]   || { echo "🔴 缺 entries/"; PASS=false; }
  [ -d ".learnings/instincts" ] || { echo "🔴 缺 instincts/"; PASS=false; }
  [ -f ".claude/skills/instinct-engine/SKILL.md" ] || echo "🔧 需要 instinct-engine skill"
  grep -q "@.claude/skills/instinct-engine" "CLAUDE.md" || echo "🔧 需要 @引用"
}
```

### 7. 脚本权限

```bash
find .claude -name "*.sh" 2>/dev/null | while read s; do
  [ -x "$s" ] || { chmod +x "$s"; echo "🔧 修复权限: $s"; }
done
find scripts -name "*.js" 2>/dev/null | while read s; do
  head -1 "$s" | grep -q "node" || echo "🟡 缺 node shebang: $s"
done
```

---

## 输出

```bash
$PASS && echo "✅ 全部校验通过" || echo "⚠️ 存在问题，Sentinel 将详细审查"
```
