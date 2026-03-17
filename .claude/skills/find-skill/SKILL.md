---
name: find-skill
description: |
  Search skills.sh marketplace and install skills using npx skills CLI.
  Handles: online skill search, download, install to global and project.
  Triggers on: "find skill", "查找skill", "有没有现成的skill", "search for skill",
  "is there a skill for", "找一个能做X的skill", "skills.sh上有没有", "帮我找一个skill",
  "download skill", "安装skill到项目".
  Do NOT use for creating new skills from scratch — use create-skill instead.
allowed-tools: Read, Write, Bash, Glob
---

# Skill: Find Skill — skills.sh 在线搜索 & 安装

## 概述
通过 `npx skills find` 在 skills.sh 市场上搜索 skill，找到后用 `npx skills add` 下载安装，最后复制到项目的 `.claude/skills/`。

**不依赖任何前置 skill**，直接使用 `npx skills` CLI（由 vercel-labs/skills 提供）。

---

## 前置检查

```bash
# 确认 npx 可用
if ! command -v npx &>/dev/null; then
  echo "🔴 npx 不可用，请先安装 Node.js"
  echo "  安装方式：https://nodejs.org/"
  # 停止执行，告知用户需要安装 Node.js
fi

echo "✅ npx 可用"

# 检查全局已安装的 skill
echo "全局已安装 skill："
npx skills list -g 2>/dev/null | head -20 || ls ~/.claude/skills/ 2>/dev/null | sed 's/^/  /'
```

---

## 执行步骤

### Step 1：在线搜索

```bash
KEYWORD="$1"  # 搜索关键词，如 "python audit", "react", "code review"

echo "=== 在线搜索：$KEYWORD ==="
npx skills find "$KEYWORD"
```

搜索结果会显示候选 skill 列表，包含：
- skill 全名（owner/repo@skill-name 格式）
- 安装量
- 简短描述

**如果搜索无结果**，尝试更宽泛的关键词：
```bash
# 原关键词无结果时，拆分后重试
echo "未找到 '$KEYWORD'，尝试更宽泛的关键词..."
BROAD_KEYWORD=$(echo "$KEYWORD" | awk '{print $1}')
npx skills find "$BROAD_KEYWORD"
```

### Step 2：评估候选

从搜索结果中选择最佳候选，优先考虑：
1. **安装量最高**的（社区验证）
2. **来自知名仓库**的（anthropics/skills, vercel-labs/, github/awesome-copilot）
3. **功能描述最匹配**的

### Step 3：安装到全局

```bash
SKILL_SOURCE="$1"   # 如：wdm0006/python-skills@auditing-python-security
                     # 或：owner/repo --skill skill-name

echo "=== 安装 $SKILL_SOURCE ==="

# 方式 A：owner/repo@skill-name 格式
npx skills add "$SKILL_SOURCE" -a claude-code -g -y

# 方式 B：如果 A 失败，尝试 --skill 语法
# npx skills add "owner/repo" --skill "skill-name" -a claude-code -g -y

echo "检查安装结果..."
npx skills list -g 2>/dev/null | grep -i "$SKILL_NAME" \
  && echo "✅ 安装成功" \
  || echo "⚠️  安装后未找到，检查 skill 名称"
```

### Step 4：复制到项目

```bash
SKILL_NAME="$1"     # 安装后的 skill 目录名
PROJECT_DIR="${2:-.}"
TARGET="$PROJECT_DIR/.claude/skills/$SKILL_NAME"

# 在全局 skill 中查找
GLOBAL_SKILL=$(find ~/.claude/skills -maxdepth 2 -name "SKILL.md" \
  | xargs grep -l "$SKILL_NAME" 2>/dev/null | head -1)

if [ -z "$GLOBAL_SKILL" ]; then
  # 直接按目录名查找
  GLOBAL_DIR="$HOME/.claude/skills/$SKILL_NAME"
  [ -d "$GLOBAL_DIR" ] && GLOBAL_SKILL="$GLOBAL_DIR/SKILL.md"
fi

if [ -n "$GLOBAL_SKILL" ]; then
  SRC_DIR=$(dirname "$GLOBAL_SKILL")
  mkdir -p "$PROJECT_DIR/.claude/skills"
  cp -r "$SRC_DIR" "$TARGET"
  echo "✅ 已复制到：$TARGET"
else
  echo "⚠️  未在全局找到 $SKILL_NAME"
  echo "全局 skill 列表："
  ls ~/.claude/skills/ 2>/dev/null
fi
```

### Step 5：验证

```bash
if [ -f "$TARGET/SKILL.md" ]; then
  echo "=== 安装成功 ==="
  head -15 "$TARGET/SKILL.md"
  echo ""
  echo "Skill 路径：$TARGET"

  # 检查 frontmatter 完整性
  head -1 "$TARGET/SKILL.md" | grep -q "^---$" \
    && echo "✅ frontmatter 存在" \
    || echo "⚠️  frontmatter 缺失，可能需要补充"
else
  echo "🔴 安装失败：$TARGET/SKILL.md 不存在"
fi
```

---

## 输出格式

```markdown
## ✅ Skill 搜索 & 安装完成

**Skill**：[skill-name]
**来源**：[owner/repo@skill-name]
**安装量**：[N]
**全局路径**：~/.claude/skills/[skill-name]/
**项目路径**：.claude/skills/[skill-name]/

### 使用方式
[从 SKILL.md 的 description 提取]

### skills.sh 页面
https://skills.sh/[owner]/[repo]/[skill-name]
```

---

## 未找到时的处理

```markdown
## ⚠️ 未找到匹配「[需求]」的 skill

已搜索关键词：[keyword1], [keyword2]
skills.sh 无合适结果。

**建议**：
1. 尝试更宽泛的关键词重新搜索
2. 使用 create-skill 从零创建
3. 手动浏览 skills.sh 市场：https://skills.sh
4. 手动浏览社区聚合站：https://skillsmp.com
```
