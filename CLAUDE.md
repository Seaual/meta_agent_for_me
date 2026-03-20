# Meta-Agents v8: 多 Visionary 架构

@USER.md
@CONVENTIONS.md
@.claude/rules/core.md
@.claude/rules/workspace.md
@.claude/rules/execution.md
@.claude/rules/task-board.md
@.claude/rules/hooks.md

---

## 使命

分析用户需求，通过多专家并行协作生成高质量的 Agent Team 配置文件。

---

## v8 新增

- **Task Board** — 集中式进度看板 + Event Log 审计日志，替代分散的文件存在性检查
- **Worktree 隔离** — Phase 4b 并行 Toolsmith 在独立 git worktree 中工作，4c 合并
- **Context Compaction** — 长任务 agent 自行压缩上下文，写入摘要继续工作
- **快速通道修正** — Phase 0（Q1-Q8）始终执行，简单需求跳过 Phase 1 Council 三方分析
- **Slash Commands** — 生成的 Team 自带 `.claude/commands/` 入口，用户用 `/project:team` 启动
- **Hook 系统** — 生成的 Team 包含 hooks（安全检查/会话摘要/文档提醒），配置在 settings.json
- **运行时 Profile** — minimal/standard/strict 三级约束，Phase 0 Q8 选择，运行时可切换
- **Instincts 持续学习** — .learnings/ 从扁平条目升级为两层结构（entries/ + instincts/），带置信度和衰减

---

## Team 成员

### Director Council（议事会）
| Agent | 专长 | 运行方式 |
|-------|------|---------|
| 🏛️ **director-council** | 流程控制 + 需求收集 + Council 协调 + 全部检查点 + Task Board 管理 | 串行，系统唯一入口 |
| 🎯 **director-strategic** | 价值交付 + 边界定义 + 扩展路线 | 并行（Council 内，context: fork） |
| 🔍 **director-critical** | 风险识别 + 假设挑战 + 简化建议 | 并行（Council 内，context: fork） |
| 📐 **director-technical** | 技术分解 + 工具设计 + 数据流 | 并行（Council 内，context: fork） |

### Visionary 团队
| Agent | 专长 | 运行方式 |
|-------|------|---------|
| 🏗️ **visionary-arch** | 架构设计 + 拓扑 + Agent矩阵 | 串行（Council 收敛后）→ 检查点2 |
| 🎨 **visionary-ux** | 五层Prompt精雕 + 交互设计（>5 agent 时自动分组并行）| 并行（Arch 确认后，context: fork） |
| 🔧 **visionary-tech** | Skill/MCP 选型 + 工具权限（支持 Context Compaction）| 并行（Arch 确认后，context: fork） |

### 实现与审查
| Agent | 专长 | 运行方式 |
|-------|------|---------|
| 🔭 **agent-scout** | VoltAgent(主) + agency-agents(备) 搜索 + 100分制评分 | 并行（Phase 3.5，context: fork） |
| 🔭 **skill-scout** | 本地 + skills.sh 在线搜索 + 100分制评分 | 并行（Phase 3.5，context: fork） |
| 🏗️ **toolsmith-infra** | 版本目录 + CONVENTIONS + CLAUDE.md骨架 + git init，委托 hooks/self-improving 给 skill | 串行（Phase 4a） |
| 📝 **toolsmith-agents** | 按决策表生成所有 agent .md 文件（支持 Context Compaction）| 并行（Phase 4b，Worktree: wt-agents） |
| 🔌 **toolsmith-skills** | 按决策表搜索/安装/创建所有 skill 文件，调用 create-skill-agent | 并行（Phase 4b，Worktree: wt-skills） |
| ✏️ **create-skill-agent** | 从零创建 skill / 改编 agency-agents / 参考原创 | 被 toolsmith-skills 调用 |
| 📦 **toolsmith-assembler** | Worktree 合并 + README.md + 更新CLAUDE.md + Slash Commands 生成 + 质量自检 | 串行（Phase 4c） |
| 🔍 **sentinel** | 10分制六维评分审查 | 串行（最多3轮，失败回 toolsmith） |

---

## 工作流程

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
    │ 自动收敛（加权规则裁决，无需用户介入分歧）
    ▼ 检查点 1：用户确认 Council 结论
    │
    ▼
🏗️ Visionary-Arch（串行）
    │
    ▼ 检查点 2：用户确认架构方案（Agent矩阵 + 拓扑）
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
    │ 输出：agent-scout-decisions.md + skill-scout-decisions.md
    ▼
🏗️ toolsmith-infra（串行 + git init）
    │ 输出：output-dir.txt + toolsmith-infra-done.txt
    ▼  [并行 × 2，Worktree 隔离]
┌──────────────────────────────┐
│ 📝 toolsmith-agents          │ ← wt-agents worktree
│ 🔌 toolsmith-skills          │ ← wt-skills worktree
└──────────────────────────────┘
    │ （Worktree 合并 → 主分支）
    ▼
📦 toolsmith-assembler（串行，合并 Worktree + 汇总 + Slash Commands）
    │
    ▼
🔍 Sentinel（最多3轮，失败→toolsmith修复）
    │
    ▼
检查点 4：最终交付（含 Task Board + 命令速查）
```

### 生成的 Team 包含 Slash Commands（v8 新增）

每个生成的 Agent Team 自带 `.claude/commands/` 目录，用户拿到 Team 后可直接在 Claude Code 中输入 `/project:team` 查看和启动所有 agent。详见 toolsmith-assembler 的 Step 3d。

---

## 初始化（v8 新增）

director-council 在首次被激活时，执行 Phase 0 之前：

1. 创建 `.claude/workspace/` 目录
2. 初始化 Task Board：

```markdown
# Task Board — Meta-Agents v8

| Phase | 任务 | 状态 | 负责 Agent | 备注 |
|-------|------|------|-----------|------|
| 0 | 需求收集 | ⏳ | director-council | |
| 1 | Council 分析+收敛 | ⏳ | 三 Director | 快速通道跳过 |
| 2 | 架构设计 | ⏳ | visionary-arch | |
| 3-ux | UX 规格 | ⏳ | visionary-ux | |
| 3-tech | Tech 规格 | ⏳ | visionary-tech | |
| 3.5a | Agent Scout | ⏳ | agent-scout | |
| 3.5b | Skill Scout | ⏳ | skill-scout | |
| 4a | 基础设施 | ⏳ | toolsmith-infra | git init |
| 4b-agents | Agent 生成 | ⏳ | toolsmith-agents | worktree |
| 4b-skills | Skill 生成 | ⏳ | toolsmith-skills | worktree |
| 4c | 汇总装配 | ⏳ | toolsmith-assembler | merge worktrees |
| 5 | Sentinel 审查 | ⏳ | sentinel | ≤3 轮 |
| 6 | 最终交付 | ⏳ | director-council | |
```

3. 初始化 Event Log：`echo '{"ts":"...","event":"init"}' > .claude/workspace/event-log.jsonl`

---

## 上下文传递协议

所有 agent 通过 `.claude/workspace/` 传递数据。**Fork 进程不继承父进程变量，必须从文件读取。**

| 文件 | 写入者 | 读取者 | 说明 |
|-----|-------|-------|------|
| `task-board.md` | 每个 agent（各更新自己的行）| director-council, sentinel | **v8 新增** |
| `event-log.jsonl` | 每个 agent（追加）| sentinel | **v8 新增** |
| `worktree-mode.txt` | agent-architect-build | toolsmith-agents, toolsmith-skills, toolsmith-assembler | **v8 新增**：`yes`/`no` |
| `profile.txt` | director-council | toolsmith-infra, toolsmith-assembler, sentinel | **v8.1 新增**：`minimal`/`standard`/`strict` |
| `instincts-enabled.txt` | director-council | toolsmith-infra, toolsmith-assembler | **v8.1 新增**：`yes`/`no` |
| `phase-0-requirements.md` | director-council | 所有 Visionary | 需求摘要 |
| `team-name.txt` | director-council | toolsmith-infra | team 名称 |
| `self-improving.txt` | director-council | toolsmith-infra | yes/no |
| `council-strategic.md` | director-strategic | director-council | 战略分析 |
| `council-critical.md` | director-critical | director-council | 批判分析 |
| `council-technical.md` | director-technical | director-council | 技术分析 |
| `council-convergence.md` | director-council | visionary-arch | 收敛结论 |
| `phase-1-architecture.md` | visionary-arch | visionary-ux, visionary-tech | 架构方案 |
| `checkpoint-2-status.txt` | visionary-arch / director-council | visionary-arch | `waiting`/`approved`/`revision:*` |
| `phase-2-ux-specs.md` | visionary-ux | toolsmith-agents | UX 规格 |
| `phase-2-ux-specs-group-N.md` | visionary-ux (分组) | director-council | 分组模式片段 |
| `ux-group-N.txt` | director-council | visionary-ux (分组) | 每组 agent 列表 |
| `ux-group-count.txt` | director-council | visionary-ux | 总组数 |
| `phase-2-tech-specs.md` | visionary-tech | agent-scout, skill-scout, toolsmith-agents, toolsmith-skills | Tech 规格 |
| `compact-<agent-name>.md` | 对应 agent | 该 agent 自身, sentinel | **v8 新增**：Context Compaction 摘要 |
| `agent-scout-decisions.md` | agent-scout | toolsmith-agents | Agent 复用决策表 |
| `agent-scout-done.txt` | agent-scout | toolsmith-agents | 完成标记 |
| `skill-scout-decisions.md` | skill-scout | toolsmith-skills | Skill 复用决策表 |
| `skill-scout-done.txt` | skill-scout | toolsmith-skills | 完成标记 |
| `output-dir.txt` | toolsmith-infra | toolsmith-agents, toolsmith-skills, toolsmith-assembler | **fork 进程读取路径的唯一来源** |
| `toolsmith-infra-done.txt` | toolsmith-infra | toolsmith-agents, toolsmith-skills | 解锁并行 |
| `toolsmith-agents-done.txt` | toolsmith-agents | toolsmith-assembler | 完成标记 |
| `toolsmith-agents-count.txt` | toolsmith-agents | toolsmith-assembler | agent 数量 |
| `toolsmith-skills-done.txt` | toolsmith-skills | toolsmith-assembler | 完成标记 |
| `toolsmith-skills-count.txt` | toolsmith-skills | toolsmith-assembler | skill 数量 |
| `toolsmith-skills-failed.txt` | toolsmith-skills | toolsmith-assembler | 安装失败的 skill |
| `sentinel-retry-count.txt` | sentinel | sentinel | 重试计数器（最大3） |
| `sentinel-last-issues.md` | sentinel | toolsmith-agents, toolsmith-skills | 修复指令 |
| `change-requests.md` | director-council | visionary-arch（升版时） | 变更需求 |

**受保护文件**（清理时不得删除）：
`team-name.txt` / `team-version.txt` / `change-requests.md`

---

## Agent/Skill 库集成

```bash
# Agent 库（agent-scout 自动搜索，手动 clone 可提高速度）
git clone --depth 1 https://github.com/VoltAgent/awesome-claude-code-subagents.git ./awesome-claude-code-subagents  # 主库
git clone https://github.com/msitarzewski/agency-agents ./agency-agents  # 备选库
export AGENCY_AGENTS_PATH=/path/to/agency-agents  # 可选自定义路径
export VOLTAGENT_PATH=/path/to/awesome-claude-code-subagents  # 可选自定义路径
```

### Bash 环境：npx 路径

skill-scout 使用 `npx skills find` 在线搜索 skill。如果 Claude Code 的 shell 找不到 npx，需要先加载 Node.js 路径：

```bash
# Windows（最常见）：
export PATH="$PATH:$APPDATA/npm"
export PATH="$PATH:C:/Program Files/nodejs"
# 如果使用 nvm-windows：
export PATH="$PATH:$NVM_SYMLINK"

# Linux/Mac：
export PATH="$PATH:/usr/local/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"
```

Agent Scout + Skill Scout 负责所有搜索和评分（并行执行），Toolsmith 直接按决策表执行，不重复搜索。

---

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `agent-architect-build` | 自动构建执行器（Phase 3.5-6，含 Worktree 管理） |
| `infra-hooks-gen` | Hooks 配置生成器（settings.json + hook 脚本，按 Profile 裁剪） |
| `infra-self-improving` | Self-Improving 配置器（skill 复制 + .learnings/ 初始化） |
| `find-skill` | 搜索 skills.sh 已安装 skill |
| `create-skill` | 从零创建/改编/优化 skill（含测试/评估/迭代/打包）。用户手动触发时用 skill 版本；toolsmith-skills 自动调用时用 `create-skill-agent` |
| `agency-agents-search` | 搜索 agency-agents 库（agent-scout 调用） |
| `tool-forge` | 生成 Bash/Python 辅助脚本 |
| `workspace-init` | 初始化工作区 + session ID |
| `output-validator` | 输出校验器（格式/权限/commands/hooks/instincts 全面自检）|
| `sentinel-score` | 评分引擎脚本（由 sentinel 调用） |
| `pipeline-check` | 流水线预检（dry-run 结构验证） |

---

## 降级规则

| 情况 | 处理 |
|-----|------|
| Council 某 Director 超时 | 跳过该 Director，Task Board 标注 ⏭️ |
| 并行 Visionary 存在差异 | 检查点3展示差异摘要，用户确认后继续 |
| agent 库不存在 | agent-scout 自动 clone VoltAgent 主库；全部失败则标注「原创」 |
| skills.sh skill 安装失败 | 写入 toolsmith-skills-failed.txt，assembler 汇报给用户 |
| output-dir.txt 为空 | toolsmith-agents/skills 报错退出，防止写入错误路径 |
| 目标目录无写权限 | 输出到 ./meta-agents-output/，告知用户 |
| 检查点2要求修改架构 | 写入 revision 状态，Visionary-Arch 重新设计 |
| Sentinel 3轮未过 | Director Council 报告具体问题，请求人工干预 |
| Worktree 创建失败 | 降级为直接并行（v7 模式），Task Board 备注「worktree 降级」|
| Context 溢出 | agent 写入 compact-*.md 摘要，Task Board 备注「compacted」|

---

## 安全红线

- 不硬编码凭证，统一用环境变量
- 不 `rm -rf $VARIABLE`（无验证）
- 不对用户输入直接 `eval`
- Bash 权限必须有明确理由
- Fork 进程必须从 workspace 文件读取路径，不依赖继承变量
