# Meta-Agents v8 技术架构

> 本文档面向开发者和技术用户。如需快速上手，见 [README.md](../README.md)。

---

## v8 新增（相比 v7）

| 特性 | 说明 |
|------|------|
| **Task Board** | 集中式进度看板 + Event Log 审计日志，替代分散的文件存在性检查 |
| **Worktree 隔离** | Phase 4b 并行 Toolsmith 在独立 git worktree 中工作，4c 合并 |
| **Context Compaction** | 长任务 agent 自行压缩上下文，写入摘要继续工作 |
| **快速通道修正** | Phase 0（Q1-Q8）始终执行，简单需求跳过 Phase 1 Council 三方分析 |
| **Slash Commands** | 生成的 Team 自带 `.claude/commands/` 入口，用户用 `/project:team` 启动 |
| **Hook 系统** | 生成的 Team 包含 hooks（安全检查/会话摘要/文档提醒），配置在 settings.json |
| **运行时 Profile** | minimal/standard/strict 三级约束，Phase 0 Q8 选择，运行时可切换 |
| **Instincts 持续学习** | `.learnings/` 从扁平条目升级为两层结构（entries/ + instincts/），带置信度和衰减 |
| **Agent/Skill Scout 分离** | 原 library-scout 拆分为 agent-scout 和 skill-scout，并保留 legacy 兼容入口 |

---

## 核心特性

- **Director Council 议事会** — 三个并行 Director（战略/批判/技术）分析每个需求，加权规则自动收敛
- **多 Visionary 架构** — 架构审查后，UX + Tech 并行规格设计
- **4 个用户检查点** — Council 结论、架构方案、规格确认、最终交付
- **Agent/Skill Scout** — 搜索 VoltAgent（100+ agent）和 skills.sh（7000+ skill），100 分制评分，四层决策
- **Sentinel 六维评分** — 格式合规、协作冲突、逻辑可行性、代码安全、内容质量、可执行性
- **自我改进** — 可选的 `.learnings/` 集成，记录运行时经验
- **版本升级** — 在现有 team 基础上增量迭代

---

## 架构图

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

---

## 团队成员（15 个 Agent + 1 遗留兼容）

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
| | `toolsmith-assembler` | Worktree 合并 + Slash Commands |
| 审查 | `sentinel` | 六维并行评分引擎 |
| 遗留 | `library-scout` | v8 之前 scout 入口的向后兼容别名 |

---

## 复用管道

| 分数 | 决策 | 操作 |
|-----|------|------|
| ≥70 | 直接复用 | 复制并调整 frontmatter |
| 50-69 | 下载改编 | 保留核心结构，改编业务逻辑 |
| <50 | 参考原创 | 输出 Top 2-3 候选的可参考设计模式 |
| 无候选 | 纯原创 | 从零创建 |

---

## Sentinel 六维评分

| 维度 | 检查内容 |
|------|---------|
| 格式合规 | frontmatter、命名、文件结构、执行模型合规 |
| 协作冲突 | 触发词重叠、workspace 写入冲突、共享资源初始化 |
| 逻辑可行性 | 上下文传递协议、workspace 覆盖 |
| 代码安全 | 凭证、eval 注入、bash 白名单 |
| 内容质量 | 执行框架、降级行为、错误处理完整性 |
| 可执行性 | workspace 路径、工具权限、团队入口 SKILL.md |

---

## 运行时 Profile

| Profile | Hook 行为 | Agent 权限策略 | 适用场景 |
|---------|----------|--------------|---------|
| `minimal` | 仅安全检查（1 hook） | Bash 宽松，Write 无限制 | 个人项目、快速原型 |
| `standard` | 安全 + 会话摘要（2 hooks）| Bash 需说明理由 | 团队日常开发（默认）|
| `strict` | 全部 hook + 审批 | Bash 最小化，Write 需路径白名单 | 生产环境、安全敏感 |

---

## 生成的 Team 结构

```
[team_name]_teams/[team_name]_teams_v1/
├── CLAUDE.md              # Team 配置入口
├── CONVENTIONS.md         # 规范文件
├── README.md              # 使用说明
└── .claude/
    ├── agents/            # Agent 文件
    ├── skills/            # Skill 文件
    ├── commands/          # Slash Commands（v8 新增）
    │   └── team.md        # /project:team 入口
    ├── scripts/           # Hook 脚本（v8 新增）
    │   └── hooks/
    └── workspace/         # 运行时数据
```

---

## Windows 注意事项

Sentinel 和部分生成器辅助步骤目前依赖 Bash 脚本。Windows 用户建议：

- 使用 Git Bash 或 WSL 运行
- 如果 `npx` 不可用，先加载 Node.js 路径：

```bash
export PATH="$PATH:$APPDATA/npm"
export PATH="$PATH:C:/Program Files/nodejs"
```
