---
name: agency-agents-search
description: |
  Search agent libraries (VoltAgent primary, agency-agents fallback) for reusable agent files.
  Scores each candidate on a 100-point matrix and recommends direct reuse, adaptation, or original creation.
  Triggers on: "search agents", "从库中找agent", "find existing agent", "复用agent",
  "agent库搜索", "look up agent library", "check agent library for", "voltagent搜索".
  Do NOT use for searching skills (use find-skill) or creating files (use toolsmith).
allowed-tools: Read, Bash, Glob, Grep
---

# Skill: Agent Library Search — 多源库搜索器

## 概述
在 VoltAgent（主库）和 agency-agents（备选库）中按关键词搜索可复用的 agent，对每个候选文件按 100 分制评分，输出「直接复用 / 下载改编 / 参考原创 / 纯原创」的明确建议。

---

## 前置检查

```bash
# 主库：VoltAgent
VOLTAGENT_PATH="${VOLTAGENT_PATH:-./awesome-claude-code-subagents}"
if [ ! -d "$VOLTAGENT_PATH" ]; then
  echo "📥 VoltAgent 库不存在，尝试浅克隆..."
  git clone --depth 1 https://github.com/VoltAgent/awesome-claude-code-subagents.git \
    "$VOLTAGENT_PATH" 2>/dev/null
fi

VOLTAGENT_AVAILABLE=false
[ -d "$VOLTAGENT_PATH" ] && VOLTAGENT_AVAILABLE=true && \
  echo "✅ VoltAgent 主库就位"

# 备选库：agency-agents
AGENCY_PATH="${AGENCY_AGENTS_PATH:-./agency-agents}"
AGENCY_AVAILABLE=false
[ -d "$AGENCY_PATH" ] && AGENCY_AVAILABLE=true && \
  echo "✅ agency-agents 备选库就位"

if ! $VOLTAGENT_AVAILABLE && ! $AGENCY_AVAILABLE; then
  echo "🔴 两个库均不可用"
  echo "  git clone --depth 1 https://github.com/VoltAgent/awesome-claude-code-subagents.git"
  # 停止执行，告知用户需要先 clone agent 库
fi
```

```

---

## 执行步骤

### Step 1：提取搜索关键词

从调用方（通常是 ToolSmith）传入的需求描述中提取：
- **职能关键词**：frontend / backend / security / data / design / marketing / devops / test...
- **动词关键词**：review / generate / analyze / build / write / optimize...
- **技术关键词**：python / react / sql / api / docker / cloud...

### Step 2：执行关键词搜索

```bash
AGENCY_PATH="${AGENCY_AGENTS_PATH:-./agency-agents}"
KEYWORD="${1:-}"  # 由调用方传入

echo "=== 搜索关键词：$KEYWORD ==="

# 搜索文件内容匹配
MATCHES=$(find "$AGENCY_PATH" -name "*.md" \
  -not -path "*/.git/*" \
  -not -path "*/scripts/*" \
  -not -path "*/docs/*" \
  -not -path "*/README*" \
  | xargs grep -li "$KEYWORD" 2>/dev/null \
  | head -10)

if [ -z "$MATCHES" ]; then
  echo "未找到匹配「$KEYWORD」的 agent"
  echo "建议尝试相关词：$(echo "$KEYWORD" | sed 's/er$//' | sed 's/ing$//')"
  exit 0
fi

echo "找到以下候选文件："
echo "$MATCHES" | while read f; do
  division=$(dirname "$f" | xargs basename)
  agent=$(basename "$f" .md)
  echo "  📄 $division/$agent"
done
```

### Step 3：预览候选文件

```bash
preview_agent() {
  local filepath="$1"
  local division=$(dirname "$filepath" | xargs basename)
  local agent=$(basename "$filepath" .md)

  echo ""
  echo "══ $division/$agent ══"

  # 显示 frontmatter（如有）
  if head -1 "$filepath" | grep -q "^---"; then
    awk '/^---$/{if(c++){exit};c=1;next}c' "$filepath" | head -10
    echo "---"
  fi

  # 显示前15行正文（使命/角色描述）
  awk '/^---$/{c++;next} c>=2{print}' "$filepath" 2>/dev/null \
    | head -15 \
    | grep -v "^$" \
    | head -8
  echo "..."
}
```

### Step 4：100 分制评分

对每个候选 agent 按以下矩阵评分：

```
职责匹配度（40分）
  agent 的核心职责与需求完全一致：40
  主要功能匹配，有小部分偏差：25
  有部分相关功能，需要补充：10

个性风格匹配（20分）
  风格与目标 agent 期望一致：20
  风格中性，无特殊要求时默认给：15
  风格明显不符合需求：0

工具权限兼容（20分）
  所需工具与 allowed-tools 完全兼容：20
  需要增减 1-2 个工具：10
  工具集差异较大需要重新定义：0

定制改造成本（20分）
  无需修改，直接可用：20
  小幅调整（修改 <30% 内容）：15
  中等改动（修改 30-60%）：8
  大幅改写（>60% 需要重写）：2
```

### Step 5：输出决策

```bash
# 根据总分决策
score_to_decision() {
  local score=$1
  if [ "$score" -ge 70 ]; then
    echo "✅ 直接复用（仅调整 name/description）"
  elif [ "$score" -ge 50 ]; then
    echo "🔧 改编复用（保留核心逻辑，重写执行框架）"
  else
    echo "✏️  建议原创（相似度不足，从 Visionary-B 规格从零创作）"
  fi
}
```

---

## 输出格式

```markdown
## Agency-Agents 搜索结果

**搜索需求**：[需求描述]
**搜索关键词**：[使用的关键词]
**库路径**：[AGENCY_PATH]

### 候选 Agent

#### 1. [division/agent-name]（[分数]/100）
- **决策**：✅ 直接复用 / 🔧 改编复用 / ✏️ 建议原创
- **职责匹配**：[分数]/40 — [说明]
- **风格匹配**：[分数]/20 — [说明]
- **工具兼容**：[分数]/20 — [说明]
- **改造成本**：[分数]/20 — [说明]
- **改编要点**（如需改编）：
  - [ ] [具体修改点1]
  - [ ] [具体修改点2]

#### 2. [division/agent-name]（[分数]/100）
...

### 结论
**推荐采用**：[文件路径]
**理由**：[2-3句话]
**下一步**：
- 直接复用：`cp $AGENCY_PATH/[path] .claude/agents/[name].md`，修改 name 和 description
- 改编复用：交由 ToolSmith 按改编要点重写
- 原创：返回 Visionary-B 规格说明，由 ToolSmith 从零生成
```
