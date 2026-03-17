# Meta-Agents v7 — Multi-Visionary Agent Team Generator

[English](#english) | [中文](#中文)

---

<a id="中文"></a>

## 中文

> **通过多专家并行协作，自动生成生产级 Claude Code Agent Team 配置。**

Meta-Agents 是一个运行在 Claude Code 中的系统，通过 6 阶段流水线分析用户需求，自动生成完整的 Agent Team 配置——包括 agent、skill、脚本、workspace 协议和文档——每个阶段都有质量把关。

### v7 新增（相比 v6）

- **执行模型修正** — 彻底移除 bash 轮询和 `exit 1` 流程控制，所有依赖检查改为自然语言指令
- **共享资源管理** — 架构阶段强制声明共享文件所有权，CLAUDE.md 包含初始化 section
- **权限一致性校验** — toolsmith 生成 agent 后自动检查 allowed-tools 是否覆盖所有操作
- **Fork 安全规则** — 禁止 fork agent 写入同一文件，架构阶段强制校验
- **Sentinel 扩充** — 新增执行模型合规检查、共享资源初始化检查、错误处理完整性检查、权限一致性检查、团队入口 SKILL.md 检查
- **强制 SKILL.md 生成** — 每个 team 自动生成入口 SKILL.md，可作为可复用 skill 被调用
- **错误处理模板** — 每个生成的 agent 必须包含输入缺失处理、部分失败处理、降级行为
- **并行 Sentinel** — 评分引擎从 1204 行单文件拆分为 8 个文件并行执行，3-4x 加速

### 核心特性

- **Director Council 议事会** — 三个并行 Director（战略/批判/技术）分析每个需求，加权规则自动收敛
- **多 Visionary 架构** — 架构审查后，UX + Tech 并行规格设计
- **4 个用户检查点** — Council 结论、架构方案、规格确认、最终交付
- **Library Scout 复用管道** — 搜索 VoltAgent（100+ agent）和 skills.sh（7000+ skill），100 分制评分，四层决策
- **Sentinel 六维评分** — 格式合规、协作冲突、逻辑可行性、代码安全、内容质量、可执行性
- **自我改进** — 可选的 `.learnings/` 集成，记录运行时经验
- **版本升级** — 在现有 team 基础上增量迭代

### 架构

```
用户需求
    │
    ▼
🏛️ Director Council（需求收集 Q1-Q7）
    │
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
    ▼  [并行 × 2，context: fork]
┌──────────────────────────┐
│ 🎨 UX    │  🔧 Tech      │
└──────────────────────────┘
    │ 检查点 3：用户确认差异摘要
    │
    ▼
🔭 Library Scout — 搜索 VoltAgent + skills.sh
    │
    ▼
🏗️ Infra → [📝 Agents ‖ 🔌 Skills] → 📦 Assembler
    │
    ▼
🔍 Sentinel（6 维度并行评分，最多 3 轮）
    │
    ▼
检查点 4：最终交付
```

### 团队成员（13 个 Agent）

| 组 | Agent | 职责 |
|---|-------|------|
| Council | `director-council` | 流程控制 + 需求收集 + 全部检查点 |
| | `director-strategic` | 价值交付 + 边界定义 |
| | `director-critical` | 风险识别 + 简化建议 |
| | `director-technical` | 技术分解 + 数据流 |
| Visionary | `visionary-arch` | 架构设计 + Agent 矩阵 + 共享资源清单 + Fork 安全校验 |
| | `visionary-ux` | 五层 Prompt 精雕 |
| | `visionary-tech` | Skill 需求 + 搜索关键词（不预判来源）|
| 实现 | `library-scout` | VoltAgent + agency-agents + skills.sh 多源搜索 + 100 分制评分 |
| | `toolsmith-infra` | 基础设施 + 共享资源初始化 |
| | `toolsmith-agents` | Agent 文件生成 + 权限校验 + 执行模型合规 |
| | `toolsmith-skills` | Skill 搜索/安装/创建 |
| | `toolsmith-assembler` | README + CLAUDE.md + 权限校验 + 强制 SKILL.md 生成 |
| 审查 | `sentinel` | 六维并行评分引擎 |

### 复用管道

#### 四层决策
| 分数 | 决策 | 操作 |
|-----|------|------|
| ≥70 | ✅ 直接复用 | 复制并调整 frontmatter |
| 50-69 | 🔧 下载改编 | 保留核心结构，改编业务逻辑 |
| <50 | ✏️ 参考原创 | 输出 Top 2-3 候选的可参考设计模式 |
| 无候选 | ✏️ 纯原创 | 从零创建 |

**即使低分候选，也必须输出参考信息**——确保每个原创 agent 都有五层结构、边界处理、降级策略。

### Sentinel 六维评分（v7 扩充）

| 维度 | 检查内容 | v7 新增 |
|------|---------|--------|
| 格式合规 | frontmatter、命名、文件结构 | **执行模型合规**（禁止 bash 轮询）|
| 协作冲突 | 触发词重叠、workspace 写入冲突 | **共享资源初始化检查** + **Fork 安全检查** |
| 逻辑可行性 | 上下文传递协议、workspace 覆盖 | — |
| 代码安全 | 凭证、eval 注入、bash 白名单 | — |
| 内容质量 | 执行框架、降级行为 | **错误处理完整性** + **权限一致性检查** |
| 可执行性 | workspace 路径、工具权限 | **团队入口 SKILL.md 检查** |

### 快速启动

```bash
# 克隆本仓库
git clone https://github.com/YOUR_USERNAME/meta-agents-v7.git
cd meta-agents-v7

# （可选）预先 clone agent 库
git clone --depth 1 https://github.com/VoltAgent/awesome-claude-code-subagents.git
git clone https://github.com/msitarzewski/agency-agents

# （可选）全局安装 self-improving skill
npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y
```

在 Claude Code 中打开项目目录，输入：

```
创建一个 agent team：[你的 team 描述]
```

### 示例提示词

```
创建一个 agent team：Multi-Repo Dependency Auditor
需求：同时审计多个本地项目仓库的依赖安全性，交叉分析共享依赖的版本冲突...

创建一个 agent team：Meeting Minutes AI
需求：将会议转录文本转化为结构化的会议纪要...
```

### 生成的 Team 结构

```
[team_name]_teams/[team_name]_teams_v1/
├── CLAUDE.md              # Team 配置入口（含初始化 section + 共享资源表）
├── CONVENTIONS.md         # 规范文件
├── README.md              # 使用说明
└── .claude/
    ├── agents/            # Agent 文件（五层 Prompt + 错误处理 + 降级行为）
    ├── skills/            # Skill 文件 + 团队入口 SKILL.md
    │   ├── [team-name]/SKILL.md  # 团队入口（v7 强制生成）
    │   └── self-improving-agent/ # 自我改进（如启用）
    └── workspace/         # 运行时数据
```

### 实验验证

| # | Team | 拓扑 | Sentinel | 关键验证 |
|---|------|------|----------|---------|
| 1 | GitHub Trend Scout | 串行+并行, MCP | 59/60 R2 | 完整流水线 |
| 2 | Code Review Enforcer | 单 agent | 56/60 R1 | 极致简化 |
| 3 | Dependency Auditor | 扇出+汇聚, MCP | 58/60 R1 | 并行压测 |
| 4 | Code Review v2 | 版本升级 | — | 升版路径 |
| 5 | Meeting Minutes AI | 反馈循环 | 58/60 R2 | 检查点暂停，skill 复用 |
| 6 | Quality Pipeline | 并行扫描 | — | VoltAgent 搜索（85 分复用）|
| **7** | **Tutorial Generator** | **串行+反馈循环** | **54/60 R1** | **v7 全部 8 项改进验证通过** |

### Windows 注意事项

```bash
# 如果 npx 不可用
export PATH="$PATH:$APPDATA/npm"
export PATH="$PATH:C:/Program Files/nodejs"
```

---

<a id="english"></a>

## English

> **Automatically generate production-ready Claude Code Agent Teams through multi-expert parallel collaboration.**

Meta-Agents runs inside Claude Code to analyze user requirements and generate complete Agent Team configurations — agents, skills, scripts, workspace protocols, and documentation — through a 6-phase pipeline with quality gates.

### What's New in v7

- **Execution Model Fix** — Removed all bash polling and `exit 1` flow control; dependency checks use natural language
- **Shared Resource Management** — Architecture phase mandates shared file ownership; CLAUDE.md includes init section
- **Permission Consistency Check** — Auto-checks allowed-tools covers all operations after agent generation
- **Fork Safety Rules** — Fork agents prohibited from writing to same file; architecture phase validates
- **Sentinel Expansion** — Execution model compliance, shared resource init, error handling, permission consistency, team SKILL.md checks
- **Mandatory SKILL.md** — Every team auto-generates entry SKILL.md for reuse
- **Error Handling Template** — Every agent must include input-missing, partial failure, and degradation handling
- **Parallel Sentinel** — Scoring engine split from 1204-line monolith to 8 parallel files, 3-4x speedup

### Key Features

- **Director Council** — Three parallel directors with weighted auto-convergence
- **Multi-Visionary Architecture** — Parallel UX + Tech spec design after architecture review
- **4 User Checkpoints** — Council, architecture, specs, delivery
- **Library Scout Reuse Pipeline** — VoltAgent (100+ agents) + skills.sh (7000+ skills), 100-point scoring
- **Sentinel 6-Dimension Scoring** — Parallel execution, up to 3 auto-fix rounds
- **Self-Improving** — Optional `.learnings/` integration
- **Version Upgrade** — Increment existing teams

### Architecture

```
User Request
    │
    ▼
🏛️ Director Council (Q1-Q7)
    │
    ▼  [parallel × 3, context: fork]
┌─────────────────────────────────────┐
│ 🎯 Strategic │ 🔍 Critical │ 📐 Tech │
└─────────────────────────────────────┘
    │ Auto-converge
    ▼ Checkpoint 1
    │
    ▼
🏗️ Visionary-Arch → Checkpoint 2
    │
    ▼  [parallel × 2, context: fork]
┌──────────────────────────┐
│ 🎨 UX    │  🔧 Tech      │
└──────────────────────────┘
    │ Checkpoint 3
    │
    ▼
🔭 Library Scout → 🏗️ Infra → [📝 Agents ‖ 🔌 Skills] → 📦 Assembler
    │
    ▼
🔍 Sentinel (parallel, up to 3 rounds) → Checkpoint 4
```

### Team Members (13 Agents)

| Group | Agent | Role |
|-------|-------|------|
| Council | `director-council` | Flow control + requirements + checkpoints |
| | `director-strategic` | Value delivery + boundaries |
| | `director-critical` | Risk identification + simplification |
| | `director-technical` | Technical decomposition |
| Visionary | `visionary-arch` | Architecture + shared resources + fork safety |
| | `visionary-ux` | 5-layer prompt design |
| | `visionary-tech` | Skill requirements + search keywords |
| Build | `library-scout` | Multi-source search + 100-point scoring |
| | `toolsmith-infra` | Infrastructure + shared resource init |
| | `toolsmith-agents` | Agent generation + permission + execution model checks |
| | `toolsmith-skills` | Skill search/install/create |
| | `toolsmith-assembler` | README + CLAUDE.md + permission + mandatory SKILL.md |
| Review | `sentinel` | 6-dimension parallel scoring |

### Reuse Pipeline

| Score | Decision | Action |
|-------|----------|--------|
| ≥70 | ✅ Direct reuse | Copy and adjust frontmatter |
| 50-69 | 🔧 Download & adapt | Keep core, modify business logic |
| <50 | ✏️ Reference & create | Output Top 2-3 with referenceable patterns |
| None | ✏️ Pure original | Create from scratch |

### Sentinel (v7 Expanded)

| Dimension | Checks | New in v7 |
|-----------|--------|-----------|
| Format | Frontmatter, naming, structure | **Execution model compliance** |
| Conflicts | Trigger overlap, write conflicts | **Shared resource init** + **Fork safety** |
| Logic | Context passing, workspace coverage | — |
| Security | Credentials, eval, bash whitelist | — |
| Quality | Execution framework, degradation | **Error handling** + **Permission consistency** |
| Executability | Paths, permissions | **Team SKILL.md check** |

### Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/meta-agents-v7.git
cd meta-agents-v7

# Optional
git clone --depth 1 https://github.com/VoltAgent/awesome-claude-code-subagents.git
git clone https://github.com/msitarzewski/agency-agents
npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y
```

```
Create an agent team: [your team description]
```

### Validation

| # | Team | Sentinel | Key |
|---|------|----------|-----|
| 1 | Trend Scout | 59/60 R2 | Full pipeline |
| 2 | Code Review | 56/60 R1 | Single agent |
| 3 | Dep Auditor | 58/60 R1 | Parallel pressure |
| 4 | Review v2 | — | Upgrade path |
| 5 | Minutes AI | 58/60 R2 | Feedback loop, skill reuse |
| 6 | Quality Pipeline | — | VoltAgent 85-point reuse |
| **7** | **Tutorial Gen** | **54/60 R1** | **All 8 v7 improvements verified** |

---

## File Structure | 文件结构

```
meta-agents-v7/
├── CLAUDE.md                              # System config | 系统配置
├── CONVENTIONS.md                         # Conventions (v7: +4 sections) | 规范
├── README.md
├── .claude/
│   ├── agents/                            # 13 agents
│   │   ├── director-council.md
│   │   ├── director-strategic.md
│   │   ├── director-critical.md
│   │   ├── director-technical.md
│   │   ├── visionary-arch.md              # +Shared resources +Fork safety
│   │   ├── visionary-ux.md
│   │   ├── visionary-tech.md              # Search keywords only
│   │   ├── library-scout.md
│   │   ├── toolsmith-infra.md             # +Shared resource init
│   │   ├── toolsmith-agents.md            # +Permission +Execution model
│   │   ├── toolsmith-skills.md
│   │   ├── toolsmith-assembler.md         # +SKILL.md +Permission
│   │   └── sentinel.md
│   ├── skills/                            # 9 skills
│   │   ├── agent-architect-build/
│   │   ├── agency-agents-search/
│   │   ├── find-skill/
│   │   ├── create-skill/
│   │   ├── tool-forge/
│   │   ├── workspace-init/
│   │   ├── output-validator/
│   │   ├── sentinel-score/                # Parallel (8 files)
│   │   │   ├── run.sh                     # Coordinator
│   │   │   ├── common.sh
│   │   │   ├── dim-1-format.sh            # +Execution model
│   │   │   ├── dim-2-conflicts.sh         # +Shared resource +Fork
│   │   │   ├── dim-3-logic.sh
│   │   │   ├── dim-4-security.sh
│   │   │   ├── dim-5-quality.sh           # +Error handling +Permission
│   │   │   └── dim-6-exec.sh             # +Team SKILL.md
│   │   └── pipeline-check/
│   ├── scripts/
│   └── templates/
└── [team]_teams/                          # Output
```

## Score History | 评分历程

```
v6 Start:    8.7/10
v6 r1-r6:    9.5/10  (checkpoint fix: 4 iterations)
v6 r7-r11:   9.7/10  (search pipeline + sentinel fix)
v7:          9.8/10  (8 improvements, all verified)
```

## License

MIT

## Acknowledgments | 致谢

- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
- [skills.sh](https://skills.sh) / [vercel-labs/skills](https://github.com/vercel-labs/skills)
- [openclaw/skills](https://github.com/openclaw/skills)
- [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)
