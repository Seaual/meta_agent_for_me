# Skill 设计规范

> 此规范用于指导 Skill 的创建和改进。参考 `.claude/skills/create-skill/SKILL.md` 获取完整流程。

---

## Skill 文件结构

```
skill-name/
├── SKILL.md (必需)
│   ├── YAML frontmatter
│   └── Markdown 指令
└── Bundled Resources (可选)
    ├── scripts/    — 可执行脚本，用于确定性/重复性任务
    ├── references/ — 参考文档，按需加载到上下文
    └── assets/     — 输出模板、图标、字体等
```

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

### 提取映射表

| Agency-Agent 中的部分 | 提取到 Skill 中 | 操作 |
|---------------------|---------------|------|
| `## Core Mission` / `## Mission` | `## 概述` | 提取核心功能描述（去掉人格语气） |
| `## My Process` / `## Workflow` | `## 执行步骤` | 直接映射，是 skill 的核心 ✅ |
| `## Technical Deliverables` | `## 输出格式` | 转化为格式规范 |
| `## Success Metrics` | `## 完成标准` | 转化为可验证的检查清单 |
| `## Critical Rules` | 嵌入各步骤的约束条件 | 分散到相关步骤中 |
| `## Identity` / `## Personality` | **丢弃** | Skill 不需要人格 |

### 改编后 Frontmatter

```yaml
---
name: [skill-name]
description: |
  [从 agent Mission 改编的触发描述]
  Keywords: [关键词].
  Do NOT use for: [排除项].
  # Adapted from: agency-agents/[division]/[original-agent].md
allowed-tools: [根据实际操作确定]
---
```

---

## 路径 B：从零原创 Skill

### 四问定位

| 问题 | 说明 |
|------|------|
| Q1: 做什么？ | [动词] + [对象] + [目的/约束] |
| Q2: 触发条件？ | 用户说什么话时触发？排除什么？ |
| Q3: 工具权限？ | 最小权限原则 |
| Q4: 输出格式？ | Markdown / 代码文件 / JSON / 终端 |

### 步骤设计原则

将任务分解为 **3-7 个步骤**：

```
步骤名：动词短语（不超过 5 个词）
步骤内容：
  - 明确的操作说明
  - 分支处理：「如果 [条件A]，则 [操作A]；否则 [操作B]」
  - 工具使用：给出具体命令示例
步骤输出：这步完成后产出什么
```

---

## SKILL.md 完整模板

```markdown
---
name: [kebab-case-name]
description: |
  Activate when [触发条件].
  Handles: [场景A], [场景B].
  Keywords: [en-kw-1], [en-kw-2], [中文词].
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

## MCP 需求映射

| Skill 需要做的事 | 需要的 MCP |
|---------------|----------|
| 操作 GitHub Issues/PR | `@anthropic-ai/mcp-server-github` |
| 网络搜索 | `@anthropic-ai/mcp-server-brave-search` |
| 抓取网页内容 | `@anthropic-ai/mcp-server-fetch` |
| 操作 SQLite 数据库 | `@anthropic-ai/mcp-server-sqlite` |
| 读写本地文件系统 | `@anthropic-ai/mcp-server-filesystem` |
| 发送 Slack 消息 | `@modelcontextprotocol/server-slack` |

如果需要 MCP 但尚未配置，在输出中告知用户配置方式。

---

## 创建后自检

```bash
SKILL_FILE=".claude/skills/$SKILL_NAME/SKILL.md"

# 检查必需字段
grep -q "^name:"          "$SKILL_FILE" && echo "✅ name"          || echo "🔴 缺少 name"
grep -q "^description:"   "$SKILL_FILE" && echo "✅ description"   || echo "🔴 缺少 description"
grep -q "^allowed-tools:" "$SKILL_FILE" && echo "✅ allowed-tools" || echo "🔴 缺少 allowed-tools"

# 检查使用示例
grep -q "使用示例\|Example" "$SKILL_FILE" \
  && echo "✅ 有使用示例" || echo "🟡 建议添加使用示例"
```

---

## 测试与评估

### 测试用例结构

```
<skill-name>-workspace/
├── iteration-1/
│   ├── eval-0/
│   │   ├── with_skill/outputs/
│   │   ├── without_skill/outputs/
│   │   ├── eval_metadata.json
│   │   └── grading.json
│   ├── eval-1/
│   └── benchmark.json
└── iteration-2/
```

### 运行测试

1. 为每个测试用例并行启动 with-skill 和 baseline（无 skill）
2. 等待完成后，起草 assertions
3. 运行 grader 评估
4. 汇总成 benchmark.json
5. 启动 eval viewer 供用户查看

### 迭代循环

```
测试 → 用户反馈 → 改进 skill → 重新测试 → ...
```

直到：
- 用户满意
- 反馈全部为空（一切正常）
- 无法继续改进

---

## Description 优化

Description 是触发的关键机制。优化步骤：

1. 生成 20 个触发评估查询（should-trigger + should-not-trigger）
2. 用户审查并调整
3. 运行优化循环（自动迭代改进）
4. 应用最佳 description

### 触发评估查询示例

```json
[
  {"query": "ok so my boss just sent me this xlsx file...", "should_trigger": true},
  {"query": "Write a fibonacci function", "should_trigger": false}
]
```

查询应：
- 具体、有细节（文件路径、业务场景）
- 包含不同长度和语气
- 包含边缘情况而非明显正例

---

## 打包

```bash
python -m scripts.package_skill <path/to/skill-folder>
```

生成 `.skill` 文件供用户安装。