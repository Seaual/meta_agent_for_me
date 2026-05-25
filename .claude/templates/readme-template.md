# [项目名称] Agent Team

> [一句话描述这个团队的核心价值]

---

## 架构概览

[从 phase-1-architecture.md 的协作拓扑直接引用 ASCII 图]

**拓扑类型**：[串行 / 并行 / 混合 / 反馈循环]

**设计决策**：[2-3句话说明为什么这样拆分]

---

## Harness 设计

### 1. 上下文管理

- **上下文载体**：[例如 `.claude/workspace/*.md`、`*-done.txt`、中间产物目录]
- **传递方式**：[哪些 agent 写入，哪些 agent 读取]
- **压缩/简化策略**：[是否有 context compaction，或为何不需要]

### 2. 工具系统

- **Agent 工具权限**：[allowed-tools 的分层原则]
- **Skill / Hook / Command**：[当前 Team 实际启用的 skills、hooks、commands]
- **外部能力**：[MCP / API / 本地脚本；如无则明确写无]

### 3. 执行编排

- **触发入口**：[用户如何启动 Team 或关键 agent]
- **拓扑与阶段**：[串行/并行/检查点/回路]
- **失败处理**：[重试、降级、fallback 路径]

### 4. 状态和记忆

- **运行状态**：[done/error/task board/event log 等状态文件]
- **长期记忆**：[`.learnings/`、instincts；如无则说明原因]
- **恢复方式**：[中断后靠什么继续]

### 5. 评估和观察

- **质量校验**：[output-validator / sentinel / 本地校验规则]
- **可观测信号**：[日志、评分、报告、审计文件]
- **人工检查点**：[用户在哪些节点需要确认]

### 6. 约束和回复

- **安全约束**：[guard agent、pre-tool hook、profile]
- **输出契约**：[每个关键 agent 的输出文件或格式]
- **用户回复风格**：[最终交付、失败、部分完成时如何回应]

---

## Team 成员

| Agent | 职责 | 工具权限 | 来源 |
|-------|------|---------|------|
| [name] | [一句话核心职责] | [Read/Write/...] | 原创 / agency-agents:[文件名] |

### 各 Agent 详细说明

#### [agent-name]
- **使命**：[从 Layer 1 提取]
- **输入**：[从哪里读取数据]
- **输出**：[写入 workspace 的哪个文件]
- **触发关键词**：[从 description 提取]

---

## 文件树

```
[项目根目录]/
├── README.md
├── CLAUDE.md
├── CONVENTIONS.md
└── .claude/
    ├── settings.json
    ├── agents/
    │   ├── [agent-1].md
    │   └── [agent-N].md
    ├── commands/
    │   ├── team.md
    │   └── [agent-N].md
    ├── skills/
    │   └── [skill-N]/SKILL.md
    └── workspace/
        ├── README.md
        ├── [agent-name]-output.md
        └── [agent-name]-done.txt
└── .learnings/
    ├── entries/
    └── instincts/
```

---

## 协作流程

```
Step 1: [触发语句示例]
         │
         ▼
[Agent A] — [做什么] → workspace/[file].md
         │
         ▼
[Agent B] — [读取 A 的输出] → workspace/[file].md
```

### 上下文传递

| 文件 | 写入者 | 读取者 | 内容 |
|-----|-------|-------|------|
| `workspace/[name]-output.md` | [agent] | [next agent] | [内容] |

### 检查点

[列出用户需要确认的节点]

---

## 可用 Skills

| Skill | 触发场景 | 来源 |
|-------|---------|------|
| [skill-name] | [触发场景] | skills.sh / 原创 / agency-agents 改编 |

---

## MCP 配置

[如无 MCP，替换为：「此团队只操作本地文件，无需 MCP 配置。」]

### 已集成的外部服务

| 服务 | 用途 | 使用它的 Agent |
|-----|------|--------------|
| [服务名] | [用途] | [agent-name] |

### 安装步骤

```bash
# 安装 MCP 包（按需）
```

配置 `.claude/settings.json`：

```json
{
  "mcpServers": {
    "[key]": {
      "command": "npx",
      "args": ["-y", "[package]"],
      "env": { "[TOKEN_VAR]": "请填入你的 Token" }
    }
  }
}
```

| 环境变量 | 获取方式 |
|---------|---------|
| `GITHUB_TOKEN` | GitHub → Settings → Developer Settings → Personal Access Tokens |
| `BRAVE_API_KEY` | https://api.search.brave.com/ |
| `SLACK_BOT_TOKEN` | Slack App → OAuth & Permissions |

---

## 快速启动

```bash
cd [项目路径]
# git clone https://github.com/msitarzewski/agency-agents ./agency-agents  # 如需复用
claude
```

触发语句：
- `「[最典型触发语句 1]」`
- `「[最典型触发语句 2]」`

---

## 注意事项

- `.claude/workspace/` 建议加入 `.gitignore`
- 新构建前运行 `workspace-init` skill 清理旧数据
- Sentinel 评分：`bash .claude/skills/sentinel-score/run.sh`
- [其他项目特定注意事项]

---

## 清理与卸载

### 清理运行时数据（每次新构建前）

```bash
# 清理 workspace 临时文件，保留版本信息
rm -f .claude/workspace/phase-*.md
rm -f .claude/workspace/council-*.md
rm -f .claude/workspace/sentinel-*.txt
rm -f .claude/workspace/sentinel-*.md
rm -f .claude/workspace/*-done.txt
rm -f .claude/workspace/*-count.txt
echo "✅ workspace 已清理"
```

或使用 `workspace-init` skill 自动处理。

### 卸载 MCP 集成

[如无 MCP，删除此章节]

从 `.claude/settings.json` 中移除对应的 `mcpServers` 条目：

```bash
# 手动编辑 settings.json，删除不再需要的 mcpServers 块
# 例如移除 GitHub MCP：
# 删除 "github": { ... } 条目
```

### 卸载 Skill

```bash
# 移除项目本地 skill
rm -rf .claude/skills/[skill-name]

# 如已安装到全局，移除全局 skill
rm -rf ~/.claude/skills/[skill-name]
```

### 完全清除此 Team

```bash
# 删除整个 team 目录（不可恢复）
rm -rf [TEAM_NAME]_teams/[VERSION]/

# 如需保留历史，仅归档
mv [TEAM_NAME]_teams/[VERSION]/ [TEAM_NAME]_teams/archived/[VERSION]/
```

---

*由 Meta-Agents 自动生成 · [生成时间戳]*
