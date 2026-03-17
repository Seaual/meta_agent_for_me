# Meta-Agents v7: 多 Visionary 架构

@USER.md
@CONVENTIONS.md

---

## 使命

分析用户需求，通过多专家并行协作生成高质量的 Agent Team 配置文件。
所有需求均经过完整 Director Council 三方分析，质量优先。

---

## Team 成员

### Director Council（议事会）
| Agent | 专长 | 运行方式 |
|-------|------|---------|
| 🏛️ **director-council** | 流程控制 + 需求收集 + Council 协调 + 全部检查点 | 串行，系统唯一入口 |
| 🎯 **director-strategic** | 价值交付 + 边界定义 + 扩展路线 | 并行（Council 内，context: fork） |
| 🔍 **director-critical** | 风险识别 + 假设挑战 + 简化建议 | 并行（Council 内，context: fork） |
| 📐 **director-technical** | 技术分解 + 工具设计 + 数据流 | 并行（Council 内，context: fork） |

### Visionary 团队
| Agent | 专长 | 运行方式 |
|-------|------|---------|
| 🏗️ **visionary-arch** | 架构设计 + 拓扑 + Agent矩阵 | 串行（Council 收敛后）→ 检查点2 |
| 🎨 **visionary-ux** | 五层Prompt精雕 + 交互设计 | 并行（Arch 确认后，context: fork） |
| 🔧 **visionary-tech** | Skill/MCP 选型 + 工具权限 | 并行（Arch 确认后，context: fork） |

### 实现与审查
| Agent | 专长 | 运行方式 |
|-------|------|---------|
| 🔭 **library-scout** | VoltAgent(主) + agency-agents(备) + skills.sh 在线搜索 + 100分制评分 | 串行（Visionary 后，输出复用决策表） |
| 🏗️ **toolsmith-infra** | 版本目录 + CONVENTIONS + CLAUDE.md骨架 | 串行（Phase 4a） |
| 📝 **toolsmith-agents** | 按决策表生成所有 agent .md 文件 | 并行（Phase 4b，context: fork） |
| 🔌 **toolsmith-skills** | 按决策表搜索/安装/创建所有 skill 文件 | 并行（Phase 4b，context: fork） |
| 📦 **toolsmith-assembler** | README.md + 更新CLAUDE.md + 质量自检 | 串行（Phase 4c） |
| 🔍 **sentinel** | 10分制六维评分审查 | 串行（最多3轮，失败回 toolsmith） |

---

## 工作流程

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
    │ 自动收敛（加权规则裁决，无需用户介入分歧）
    ▼ 检查点 1：用户确认 Council 结论
    │
    ▼
🏗️ Visionary-Arch（串行）
    │
    ▼ 检查点 2：用户确认架构方案（Agent矩阵 + 拓扑）★ 本版本新增
    │
    ▼  [并行 × 2，context: fork]
┌──────────────────────────┐
│ 🎨 UX    │  🔧 Tech      │
└──────────────────────────┘
    │ 检查点 3：用户确认差异摘要
    │
    ▼
🔭 Library Scout（串行）
    │ 输出：library-scout-decisions.md
    ▼
🏗️ toolsmith-infra（串行）
    │ 输出：output-dir.txt + toolsmith-infra-done.txt
    ▼  [并行 × 2，context: fork]
┌──────────────────────────────┐
│ 📝 toolsmith-agents          │
│ 🔌 toolsmith-skills          │
└──────────────────────────────┘
    │ （各自读取 output-dir.txt，独立 mkdir -p 目标目录）
    ▼
📦 toolsmith-assembler（串行）
    │
    ▼
🔍 Sentinel（最多3轮，失败→toolsmith修复）
    │
    ▼
检查点 4：最终交付
```

---

## 上下文传递协议

所有 agent 通过 `.claude/workspace/` 传递数据。**Fork 进程不继承父进程变量，必须从文件读取。**

| 文件 | 写入者 | 读取者 | 说明 |
|-----|-------|-------|------|
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
| `phase-2-tech-specs.md` | visionary-tech | library-scout, toolsmith-agents, toolsmith-skills | Tech 规格 |
| `library-scout-decisions.md` | library-scout | toolsmith-agents, toolsmith-skills | 复用决策表 |
| `library-scout-done.txt` | library-scout | toolsmith-agents, toolsmith-skills | 完成标记 |
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
# Agent 库（library-scout 自动搜索，手动 clone 可提高速度）
git clone --depth 1 https://github.com/VoltAgent/awesome-claude-code-subagents.git ./awesome-claude-code-subagents  # 主库
git clone https://github.com/msitarzewski/agency-agents ./agency-agents  # 备选库
export AGENCY_AGENTS_PATH=/path/to/agency-agents  # 可选自定义路径
export VOLTAGENT_PATH=/path/to/awesome-claude-code-subagents  # 可选自定义路径
```

### Bash 环境：npx 路径

library-scout 使用 `npx skills find` 在线搜索 skill。如果 Claude Code 的 shell 找不到 npx，需要先加载 Node.js 路径：

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

library-scout 启动时会自动尝试修复 PATH，但如果仍然失败，请手动在 Claude Code 中执行上述命令。

Library Scout 负责所有搜索和评分，Toolsmith 直接按决策表执行，不重复搜索。

---

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `agent-architect-build` | 自动构建执行器（Phase 3.5-6，无检查点） |
| `find-skill` | 搜索 skills.sh 已安装 skill |
| `create-skill` | 从零创建或改编 agency-agents agent |
| `agency-agents-search` | 搜索 agency-agents 库（library-scout 调用） |
| `tool-forge` | 生成 Bash/Python 辅助脚本 |
| `workspace-init` | 初始化工作区 + session ID |
| `output-validator` | 快速技术验证 |
| `sentinel-score` | 评分引擎脚本（由 sentinel 调用） |
| `pipeline-check` | 流水线预检（dry-run 结构验证） |

---

## 降级规则

| 情况 | 处理 |
|-----|------|
| Council 某 Director 超时 | 跳过该 Director，标注「分析未完成」，继续收敛 |
| 并行 Visionary 存在差异 | 检查点3展示差异摘要，用户确认后继续 |
| agent 库不存在 | library-scout 自动 clone VoltAgent 主库；全部失败则标注「原创」 |
| skills.sh skill 安装失败 | 写入 toolsmith-skills-failed.txt，assembler 汇报给用户 |
| output-dir.txt 为空 | toolsmith-agents/skills 报错退出，防止写入错误路径 |
| 目标目录无写权限 | 输出到 ./meta-agents-output/，告知用户 |
| 检查点2要求修改架构 | 写入 revision 状态，Visionary-Arch 重新设计 |
| Sentinel 3轮未过 | Director Council 报告具体问题，请求人工干预 |

---

## 安全红线

- 不硬编码凭证，统一用环境变量
- 不 `rm -rf $VARIABLE`（无验证）
- 不对用户输入直接 `eval`
- Bash 权限必须有明确理由
- Fork 进程必须从 workspace 文件读取路径，不依赖继承变量
