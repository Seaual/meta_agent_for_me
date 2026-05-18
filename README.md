# Meta-Agents v8 — 小白也能用的 AI 助手团队生成器

[English](#english) | [中文小白版](#中文小白版) | [中文技术版](#中文技术版)

---

<a id="中文小白版"></a>

## 中文小白版

### 一句话介绍

**Meta-Agents 是一个"AI 助手团队生成器"。**

你只需要用自然语言告诉它"我想做一个能帮我干某某事的 AI 团队"，它就会自动分析需求、设计角色、生成配置文件——直接就能在 Claude Code 里使用。

### 能做什么？举几个例子

| 你说 | 它生成 |
|-----|-------|
| "帮我做一个写小红书文案的团队" | 文案写手 + 图片生成提示词专家 + 合规审核员 + 排版优化师 |
| "帮我做一个审查代码的团队" | 代码审查员 + 安全分析师 + 测试生成器 + 性能优化师 |
| "帮我做一个写技术文档的团队" | 文档架构师 + 内容写手 + 示例代码生成器 + 格式检查员 |
| "帮我做一个做数据分析的团队" | 数据清洗员 + 分析师 + 可视化设计师 + 报告撰写员 |

**不需要写代码，不需要懂配置，说话就行。**

### 使用前的准备

#### 1. 安装 Claude Code
如果你还没装，去官网下载并配置好。这是运行环境。

#### 2. 下载这个项目

```bash
git clone https://github.com/Seaual/meta_agent_for_me.git
cd meta_agent_for_me
```

#### 3. 在 Claude Code 中打开这个项目

```bash
claude
```

然后确保你当前在这个 `meta_agent_for_me` 文件夹里。

### 快速开始（只需两步）

#### 第一步：启动生成器

在 Claude Code 的对话框里输入：

```
/meta-agent
```

或者更直接地描述你的需求：

```
创建一个 agent team：帮我写小红书文案，要会写标题、正文、还能生成配图提示词
```

#### 第二步：跟着提示走

系统会问你 7-8 个简单的问题（比如团队规模、安全等级、是否需要自我学习等）。**大部分情况下你直接回车选默认就行。**

然后系统会自动运行：
- 分析你的需求
- 设计团队架构
- 搜索是否有现成的 agent/skill 可以复用
- 生成所有配置文件
- 自动检查质量

整个过程 **5-15 分钟**，你只需要在几个关键节点确认一下（比如"这个架构可以吗？"）。

### 生成完了怎么用？

生成完成后，你会在项目里看到一个新的文件夹，名字大概长这样：

```
xiaohongshu-writer_teams/
└── xiaohongshu-writer_teams_v1/
    ├── CLAUDE.md          ← 团队说明书
    ├── README.md          ← 这个团队的使用说明
    ├── CONVENTIONS.md     ← 规范文件
    └── .claude/
        ├── agents/        ← 各个 AI 助手的配置
        ├── skills/        ← 技能包
        ├── commands/      ← 快速启动命令
        └── scripts/       ← 辅助脚本
```

#### 使用生成的团队

**方法 A：复制到你的项目里**

把生成好的 `xiaohongshu-writer_teams_v1` 整个文件夹，复制到你实际要工作的项目目录下。

然后在 Claude Code 中输入：

```
/project:team
```

就会看到这个团队里所有的 agent，点击就能启动。

**方法 B：直接在生成器里继续用**

不复制也行，在 `meta_agent_for_me` 项目里也能直接调用。

### 想改团队怎么办？

对已生成的团队说：

```
在小红书团队基础上，增加一个专门做视频脚本的 agent
```

系统会自动创建 v2 版本，保留 v1，只改你要改的部分。

### 常见问题

**Q：生成失败了怎么办？**
A：系统有自动修复机制，最多重试 3 轮。如果还是失败，会告诉你具体问题，你描述一下怎么改就行。

**Q：生成的团队安全吗？**
A：默认是 `standard` 安全级别，所有操作都有检查。如果是重要项目，可以在生成时选 `strict` 级别。

**Q：需要会编程吗？**
A：完全不需要。你只需要会用 Claude Code 对话，用自然语言描述需求即可。

**Q：Windows 能用吗？**
A：能。建议在 Git Bash 或 WSL 中运行，避免脚本兼容问题。

---

<a id="中文技术版"></a>

## 中文技术版

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
