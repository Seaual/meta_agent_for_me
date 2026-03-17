---
name: create-skill
description: |
  Activate when a new skill needs to be created from scratch, or when adapting an
  agency-agents agent's Process/Deliverables sections into a skill format.
  Use after find-skill confirms no suitable skill exists.
  Triggers on: "create skill", "新建skill", "创建技能", "make a skill for",
  "写一个skill来做X", "build skill", "skill不存在需要新建", "从零创建skill".
  Do NOT use if a suitable skill already exists (run find-skill first to check).
allowed-tools: Read, Write, Edit, Bash, Glob
---

# Skill: Create Skill — 技能锻造炉

## 概述
从零创建一个全新的 `SKILL.md`，或将 agency-agents 仓库中某个 agent 的执行逻辑（Process / Deliverables）改编为 skill 格式。

---

## 创建路径选择

```
用户描述需求
       │
       ├── agency-agents 库中有类似 agent？
       │         │
       │      是 ─┤─── 否
       │         │         │
       │         ▼         ▼
       │     改编路径    原创路径
       │   (提取执行逻辑) (从零构建)
       │
       └── 需要调用外部工具/MCP？
                 │
              是 ─┤─── 否
                 │         │
                 ▼         ▼
           MCP-aware    标准 skill
             skill
```

---

## 路径 A：改编 Agency-Agents Agent

agency-agents 的 agent 是**有人格的专家**，不能直接当 skill 用。
但它们的「执行流程」部分非常高质量，值得提取。

### Step 1：识别可提取的内容

```bash
AGENCY_PATH="${AGENCY_AGENTS_PATH:-./agency-agents}"
AGENT_FILE="$AGENCY_PATH/[division]/[agent-name].md"

echo "=== 分析原 Agent ==="
cat "$AGENT_FILE"
```

**提取映射表**：

| Agency-Agent 中的部分 | 提取到 Skill 中 | 操作 |
|---------------------|---------------|------|
| `## Core Mission` / `## Mission` | `## 概述` | 提取核心功能描述（去掉人格语气） |
| `## My Process` / `## Workflow` | `## 执行步骤` | 直接映射，是 skill 的核心 ✅ |
| `## Technical Deliverables` / `## Deliverables` | `## 输出格式` | 转化为格式规范 |
| `## Success Metrics` | `## 完成标准` | 转化为可验证的检查清单 |
| `## Critical Rules` | 嵌入各步骤的约束条件 | 分散到相关步骤中 |
| `## Identity` / `## Personality` | **丢弃** | Skill 不需要人格 |
| `## Communication Style` | **丢弃** | Skill 不需要语气描述 |
| `## Memory` / `## Background` | **丢弃** | Skill 不保存状态 |

### Step 2：生成改编后的 SKILL.md

```bash
SKILL_NAME="[改编后的 skill 名称]"
SKILL_DIR=".claude/skills/$SKILL_NAME"
mkdir -p "$SKILL_DIR"
```

在 frontmatter 中注明来源：
```yaml
---
name: [skill-name]
description: |
  [从 agent Mission 改编的触发描述]
  Keywords: [从 agent 名称和功能提取].
  Do NOT use for: [明确排除].
  # Adapted from: agency-agents/[division]/[original-agent].md
allowed-tools: [根据 agent 实际操作确定]
---
```

---

## 路径 B：从零原创 Skill

### Step 1：四问定位

```
Q1: 这个 skill 做什么？（一句话）
    格式：[动词] + [对象] + [目的/约束]
    例：「扫描 Python 代码中的安全漏洞，生成带行号的报告」

Q2: 触发条件是什么？
    - 用户说什么话时应该触发？
    - 哪些场景不该触发（排除项）？

Q3: 需要哪些工具权限？（最小原则）
    只读：Read, Grep, Glob
    读写：+ Write 或 Edit（优先 Edit）
    执行命令：+ Bash（需要明确理由）

Q4: 输出是什么格式？
    Markdown 报告 / 生成的代码文件 / JSON 结构 / 终端输出
```

### Step 2：判断是否需要 MCP

如果 skill 需要调用**外部服务**，先确认 MCP 可用性：

```bash
# 检查 Claude Code 的 MCP 配置
echo "=== 已配置的 MCP ==="
cat ~/.claude/settings.json 2>/dev/null \
  | grep -A5 '"mcpServers"' \
  | grep '"name"\|"command"' \
  || echo "（未找到 MCP 配置，或路径不同）"

# 也可以检查项目级配置
cat .claude/settings.json 2>/dev/null \
  | grep -A5 '"mcpServers"' \
  || echo "（无项目级 MCP 配置）"
```

**常见 MCP 需求映射**：

| Skill 需要做的事 | 需要的 MCP | 配置示例 |
|---------------|----------|---------|
| 操作 GitHub Issues/PR | `@anthropic-ai/mcp-server-github` | `"github"` |
| 网络搜索 | `@anthropic-ai/mcp-server-brave-search` | `"brave-search"` |
| 抓取网页内容 | `@anthropic-ai/mcp-server-fetch` | `"fetch"` |
| 操作 SQLite 数据库 | `@anthropic-ai/mcp-server-sqlite` | `"sqlite"` |
| 读写本地文件系统 | `@anthropic-ai/mcp-server-filesystem` | `"filesystem"` |
| 运行 Python 代码 | 无需 MCP（用 Bash） | — |
| 发送 Slack 消息 | `@modelcontextprotocol/server-slack` | `"slack"` |

如果需要 MCP 但尚未配置，在输出中告知用户：
```markdown
⚠️  此 skill 需要 MCP：[mcp-name]
配置方式（添加到 ~/.claude/settings.json）：
\`\`\`json
{
  "mcpServers": {
    "[mcp-name]": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-[name]"]
    }
  }
}
\`\`\`
配置完成后，skill 中的工具调用即可生效。
```

### Step 3：步骤设计原则

将任务分解为 **3-7 个步骤**，遵循：

```
步骤名：动词短语（不超过 5 个词）
步骤内容：
  - 明确的操作说明
  - 分支处理：「如果 [条件A]，则 [操作A]；否则 [操作B]」
  - 工具使用：给出具体命令示例（而非「用 Bash 执行」这种废话）
步骤输出：这步完成后产出什么
```

**步骤数量参考**：
- 简单 skill（单一功能）：3-4 步
- 中等 skill（有判断分支）：5-6 步
- 复杂 skill（多阶段流程）：7 步上限（超过则考虑拆分）

### Step 4：生成完整 SKILL.md

```bash
SKILL_NAME="[kebab-case-name]"
SKILL_DIR=".claude/skills/$SKILL_NAME"
mkdir -p "$SKILL_DIR"
```

**完整模板**：

```markdown
---
name: [kebab-case-name]
description: |
  Activate when [触发动词短语].
  Handles: [场景A], [场景B].
  Keywords: [en-kw-1], [en-kw-2], [中文词1], [中文词2].
  Do NOT use for: [排除场景] (use [替代方案] instead).
allowed-tools: [最小权限]
---

# Skill: [人类可读标题]

## 概述
[1-2句话：做什么，解决什么问题]

## 前置检查
\`\`\`bash
# 验证必要工具/环境/MCP
[具体检查命令]
\`\`\`

## 执行步骤

### Step 1：[动词短语]
[说明]
\`\`\`bash
[具体命令示例]
\`\`\`

### Step 2：[动词短语]
[说明，含分支处理]

[...继续直到覆盖所有步骤]

## 输出格式
\`\`\`
[输出结构样例]
\`\`\`

## 完成标准
- [ ] [可验证的标准 1]
- [ ] [可验证的标准 2]

## 错误处理
| 错误 | 原因 | 处理方式 |
|-----|------|---------|
| [错误1] | [原因] | [如何处理] |

## 使用示例
用户输入：「[典型触发语句]」
Skill 行为：[简述执行过程]
输出样例：[预期输出片段]
```

---

## 创建后自检

```bash
SKILL_FILE=".claude/skills/$SKILL_NAME/SKILL.md"

echo "=== Create-Skill 自检 ==="
grep -q "^name:"          "$SKILL_FILE" && echo "✅ name"          || echo "🔴 缺少 name"
grep -q "^description:"   "$SKILL_FILE" && echo "✅ description"   || echo "🔴 缺少 description"
grep -q "^allowed-tools:" "$SKILL_FILE" && echo "✅ allowed-tools" || echo "🔴 缺少 allowed-tools"

# description 长度
lines=$(awk '/^description:/,/^[a-z][^:]*:/' "$SKILL_FILE" \
  | grep -v "^description:\|^allowed\|^name\|^context\|^---" | wc -l)
[ "$lines" -ge 3 ] \
  && echo "✅ description 长度 ($lines 行)" \
  || echo "🟡 description 偏短 ($lines 行，建议 3+ 行)"

# 使用示例
grep -q "使用示例\|Example" "$SKILL_FILE" \
  && echo "✅ 有使用示例" || echo "🟡 建议添加使用示例"

echo "Skill 路径：$SKILL_FILE"
echo "=== 自检完成 ==="
```

---

## 输出汇报格式

```markdown
## ✅ Skill 创建完成

**名称**：[skill-name]
**路径**：`.claude/skills/[name]/SKILL.md`
**创建方式**：从零原创 / 改编自 agency-agents/[path]
**需要 MCP**：[无 / [mcp-name]（配置说明见上方）]

### 触发测试
应触发：
- ✅ 「[触发语句 1]」
- ✅ 「[触发语句 2]」

不应触发：
- ❌ 「[排除语句]」（会触发 [其他 skill/agent]）

### 部署
\`\`\`bash
# 全局安装
cp -r .claude/skills/[name]/ ~/.claude/skills/

# 仅当前项目
# 已在 .claude/skills/[name]/ 就位，无需操作
\`\`\`
```
