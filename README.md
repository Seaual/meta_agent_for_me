# Meta-Agents v8 — Multi-Visionary Agent Team Generator

[English](#english) | [中文](#中文)

---

<a id="中文"></a>

## 中文

> **通过多专家并行协作，自动生成生产级 Claude Code Agent Team 配置。**

Meta-Agents 是一个运行在 Claude Code 中的系统，通过 6 阶段流水线分析用户需求，自动生成完整的 Agent Team 配置——包括 agent、skill、脚本、workspace 协议和文档——每个阶段都有质量把关。

### v8 新增（相比 v7）

- **Task Board** — 集中式进度看板 + Event Log 审计日志，替代分散的文件存在性检查
- **Worktree 隔离** — Phase 4b 并行 Toolsmith 在独立 git worktree 中工作，避免写冲突
- **Context Compaction** — 长任务 agent 自行压缩上下文，写入摘要继续工作
- **快速通道修正** — Phase 0（Q1-Q8）始终执行，简单需求跳过 Phase 1 Council 三方分析
- **Slash Commands** — 生成的 Team 自带 `.claude/commands/` 入口，用户用 `/project:team` 启动
- **Hook 系统** — 生成的 Team 包含 hooks（安全检查/会话摘要/文档提醒），配置在 settings.json
- **运行时 Profile** — minimal/standard/strict 三级约束，Phase 0 Q8 选择，运行时可切换
- **Instincts 持续学习** — .learnings/ 从扁平条目升级为两层结构（entries/ + instincts/），带置信度和衰减
- **Agent/Skill Scout 分离** — 原 library-scout 拆分为 agent-scout 和 skill-scout，并保留 legacy 兼容入口

### 核心特性

- **Director Council 议事会** — 三个并行 Director（战略/批判/技术）分析每个需求，加权规则自动收敛
- **多 Visionary 架构** — 架构审查后，UX + Tech 并行规格设计
- **4 个用户检查点** — Council 结论、架构方案、规格确认、最终交付
- **Agent/Skill Scout** — 搜索 VoltAgent（100+ agent）和 skills.sh（7000+ skill），100 分制评分，四层决策
- **Sentinel 六维评分** — 格式合规、协作冲突、逻辑可行性、代码安全、内容质量、可执行性
- **自我改进** — 可选的 `.learnings/` 集成，记录运行时经验
- **版本升级** — 在现有 team 基础上增量迭代

### 架构

```
用户需求
    │
    ▼
🏛️ Director Council（需求收集 Q1-Q7 + 初始化 Task Board）
    │
    ├── 简单需求（≤3 agent）→ Task Board Phase 1 标记 ⏭️ → 直接 Phase 2
    │
    ├── 复杂需求 ↓
    ▼  [并行 × 3，context: fork]
┌─────────────────────────────────────┐
│ 🎯 Strategic │ 🔍 Critical │ 📐 Tech │
└─────────────────────────────────────┘
    │ 自动收敛（加权规则裁决）
    ▼ 检查点 1：用户确认 Council 结论
    │
    ▼
🏗️ Visionary-Arch（串行）
    │
    ▼ 检查点 2：用户确认架构方案
    │
    ▼  [并行 × 2+，context: fork]
┌──────────────────────────────────┐
│ 🎨 UX (≤5 agent: 1个)           │
│ 🎨 UX-1, UX-2... (>5: 分组并行) │
│              🔧 Tech              │
└──────────────────────────────────┘
    │ 检查点 3：用户确认差异摘要
    │
    ▼
🔭 Agent Scout ‖ Skill Scout（并行搜索）
    │
    ▼
🏗️ Infra → [📝 Agents ‖ 🔌 Skills] → 📦 Assembler
    │         (Worktree 隔离)
    ▼
🔍 Sentinel（6 维度并行评分，最多 3 轮）
    │
    ▼
检查点 4：最终交付
```

### 团队成员（15 个 Agent）

| 组 | Agent | 职责 |
|---|-------|------|
| Council | `director-council` | 流程控制 + 需求收集 + 全部检查点 + Task Board 管理 |
| | `director-strategic` | 价值交付 + 边界定义 |
| | `director-critical` | 风险识别 + 简化建议 |
| | `director-technical` | 技术分解 + 数据流 |
| Visionary | `visionary-arch` | 架构设计 + Agent 矩阵 + 拓扑 |
| | `visionary-ux` | 五层 Prompt 精雕（支持分组并行）|
| | `visionary-tech` | Skill/MCP 选型 + 工具权限 |
| Scout | `agent-scout` | VoltAgent + agency-agents 搜索 + 100 分制评分 |
| | `skill-scout` | 本地 + skills.sh 在线搜索 + 100 分制评分 |
| Toolsmith | `toolsmith-infra` | 基础设施 + hooks 配置 + self-improving 配置 |
| | `toolsmith-agents` | Agent 文件生成（Worktree 隔离）|
| | `toolsmith-skills` | Skill 搜索/安装/创建 |
| | `create-skill-agent` | 从零创建 skill / 改编 agency-agents |
| | `toolsmith-assembler` | Worktree 合并 + README + Slash Commands |
| 审查 | `sentinel` | 六维并行评分引擎 |

### 复用管道

| 分数 | 决策 | 操作 |
|-----|------|------|
| ≥70 | ✅ 直接复用 | 复制并调整 frontmatter |
| 50-69 | 🔧 下载改编 | 保留核心结构，改编业务逻辑 |
| <50 | ✏️ 参考原创 | 输出 Top 2-3 候选的可参考设计模式 |
| 无候选 | ✏️ 纯原创 | 从零创建 |

### Sentinel 六维评分

| 维度 | 检查内容 |
|------|---------|
| 格式合规 | frontmatter、命名、文件结构、执行模型合规 |
| 协作冲突 | 触发词重叠、workspace 写入冲突、共享资源初始化 |
| 逻辑可行性 | 上下文传递协议、workspace 覆盖 |
| 代码安全 | 凭证、eval 注入、bash 白名单 |
| 内容质量 | 执行框架、降级行为、错误处理完整性 |
| 可执行性 | workspace 路径、工具权限、团队入口 SKILL.md |

### 快速启动

```bash
# 克隆本仓库
git clone https://github.com/Seaual/meta_agent_for_me.git
cd meta_agent_for_me

# （可选）预先 clone agent 库
git clone --depth 1 https://github.com/VoltAgent/awesome-claude-code-subagents.git
git clone https://github.com/msitarzewski/agency-agents

# （可选）全局安装 self-improving skill
npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y
```

在 Claude Code 中打开项目目录，输入：

```
/meta-agent
```

或直接描述需求：

```
创建一个 agent team：[你的 team 描述]
```

### 生成的 Team 结构

```
[team_name]_teams/[team_name]_teams_v1/
├── CLAUDE.md              # Team 配置入口
├── CONVENTIONS.md         # 规范文件
├── README.md              # 使用说明
└── .claude/
    ├── agents/            # Agent 文件
    ├── skills/            # Skill 文件
    ├── commands/          # Slash Commands（v8 新增）
    │   └── team           # /project:team 入口
    ├── scripts/           # Hook 脚本（v8 新增）
    │   └── hooks/
    └── workspace/         # 运行时数据
```

### 运行时 Profile

| Profile | Hook 行为 | 适用场景 |
|---------|----------|---------|
| `minimal` | 仅安全检查 | 个人项目、快速原型 |
| `standard` | 安全 + 会话摘要 | 团队日常开发（默认）|
| `strict` | 全部 hook + 审批 | 生产环境、安全敏感 |

### Windows 注意事项

```bash
# 如果 npx 不可用
export PATH="$PATH:$APPDATA/npm"
export PATH="$PATH:C:/Program Files/nodejs"
```

Sentinel and several generator helper steps currently rely on Bash scripts. On Windows, use Git Bash or WSL in addition to Node.js.

---

<a id="english"></a>

## English

> **Automatically generate production-ready Claude Code Agent Teams through multi-expert parallel collaboration.**

Meta-Agents runs inside Claude Code to analyze user requirements and generate complete Agent Team configurations — agents, skills, scripts, workspace protocols, and documentation — through a 6-phase pipeline with quality gates.

### What's New in v8

- **Task Board** — Centralized progress dashboard + Event Log audit trail
- **Worktree Isolation** — Phase 4b parallel Toolsmith works in isolated git worktrees
- **Context Compaction** — Long-running agents self-compress context and continue
- **Fast Track** — Phase 0 always runs; simple needs skip Council analysis
- **Slash Commands** — Generated teams include `.claude/commands/` entry points
- **Hook System** — Teams include security/session-summary/doc-reminder hooks
- **Runtime Profile** — minimal/standard/strict constraint levels
- **Instincts** — Two-layer .learnings/ with confidence and decay
- **Scout Separation** — library-scout split into agent-scout + skill-scout, with a legacy compatibility alias retained

### Key Features

- **Director Council** — Three parallel directors with weighted auto-convergence
- **Multi-Visionary Architecture** — Parallel UX + Tech spec design
- **4 User Checkpoints** — Council, architecture, specs, delivery
- **Agent/Skill Scout** — VoltAgent + skills.sh search, 100-point scoring
- **Sentinel 6-Dimension Scoring** — Parallel execution, up to 3 auto-fix rounds
- **Self-Improving** — Optional `.learnings/` integration
- **Version Upgrade** — Increment existing teams

### Team Members (15 Core Agents + 1 Legacy Compatibility Agent)

| Group | Agent | Role |
|-------|-------|------|
| Council | `director-council` | Flow control + requirements + Task Board |
| | `director-strategic` | Value delivery + boundaries |
| | `director-critical` | Risk identification + simplification |
| | `director-technical` | Technical decomposition |
| Visionary | `visionary-arch` | Architecture + topology |
| | `visionary-ux` | 5-layer prompt design |
| | `visionary-tech` | Skill/MCP selection + permissions |
| Scout | `agent-scout` | VoltAgent + agency-agents search |
| | `skill-scout` | Local + skills.sh online search |
| Toolsmith | `toolsmith-infra` | Infrastructure + hooks + self-improving |
| | `toolsmith-agents` | Agent generation (Worktree) |
| | `toolsmith-skills` | Skill search/install/create |
| | `create-skill-agent` | Create skill from scratch/adapt |
| | `toolsmith-assembler` | Merge worktrees + Slash Commands |
| Review | `sentinel` | 6-dimension parallel scoring |
| Legacy | `library-scout` | Backward-compatible pre-v8 scout entry point |

### Quick Start

```bash
git clone https://github.com/Seaual/meta_agent_for_me.git
cd meta_agent_for_me

# Optional
git clone --depth 1 https://github.com/VoltAgent/awesome-claude-code-subagents.git
git clone https://github.com/msitarzewski/agency-agents
npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y
```

```
/meta-agent
```

### Generated Team Structure

```
[team_name]_teams/[team_name]_teams_v1/
├── CLAUDE.md
├── CONVENTIONS.md
├── README.md
└── .claude/
    ├── agents/
    ├── skills/
    ├── commands/          # Slash Commands (new in v8)
    └── workspace/
├── scripts/
│   └── hooks/            # Runtime hook scripts (new in v8)
```

---

## File Structure | 文件结构

```
meta_agent_for_me/
├── CLAUDE.md                              # System config
├── CONVENTIONS.md                         # Conventions
├── USER.md                                # User preferences
├── README.md
├── .claude/
│   ├── agents/                            # 16 files: 15 core + 1 legacy compatibility agent
│   │   ├── director-council.md
│   │   ├── director-strategic.md
│   │   ├── director-critical.md
│   │   ├── director-technical.md
│   │   ├── visionary-arch.md
│   │   ├── visionary-ux.md
│   │   ├── visionary-tech.md
│   │   ├── agent-scout.md                 # v8: new
│   │   ├── skill-scout.md                 # v8: new
│   │   ├── library-scout.md               # legacy compatibility alias
│   │   ├── toolsmith-infra.md
│   │   ├── toolsmith-agents.md
│   │   ├── toolsmith-skills.md
│   │   ├── create-skill-agent.md          # v8: new
│   │   ├── toolsmith-assembler.md
│   │   └── sentinel.md
│   ├── skills/                            # 11 skills
│   │   ├── agent-architect-build/
│   │   ├── agency-agents-search/
│   │   ├── find-skill/
│   │   ├── create-skill/
│   │   ├── tool-forge/
│   │   ├── workspace-init/
│   │   ├── output-validator/
│   │   ├── sentinel-score/
│   │   ├── pipeline-check/
│   │   ├── infra-hooks-gen/               # v8: new
│   │   └── infra-self-improving/          # v8: new
│   ├── commands/
│   │   └── meta-agent.md
│   ├── rules/                             # v8: modular rules
│   │   ├── core.md
│   │   ├── workspace.md
│   │   ├── execution.md
│   │   ├── task-board.md
│   │   ├── hooks.md
│   │   ├── skill-design.md
│   │   └── instincts.md
│   ├── scripts/
│   └── templates/
└── [team]_teams/                          # Output
```

## License

MIT

## Acknowledgments | 致谢

- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
- [skills.sh](https://skills.sh) / [vercel-labs/skills](https://github.com/vercel-labs/skills)
- [openclaw/skills](https://github.com/openclaw/skills)
- [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
