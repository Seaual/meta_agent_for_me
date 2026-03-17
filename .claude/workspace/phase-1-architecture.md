# Visionary-Arch 架构方案

## 系统边界

**触发条件**：用户请求「生成教程」「创建交互式教程」「为这个项目生成教程」等

**输入**：
- 项目目录路径（必需）
- 目标受众描述（可选，默认：中级开发者）
- 教程主题范围（可选，默认：全项目）

**输出**：
- 最终教程文档（Markdown 格式）
- 交付位置：`.claude/workspace/final-tutorial.md` 或用户指定路径

**外部依赖**：无（self-improving-agent skill 由 toolsmith-infra 自动配置）

---

## 分解策略

**选用**：按职能分解

**理由**：教程生成涉及独立的职能环节——分析、写作、设计练习、审查、组装。各职能专业度差异大，适合独立 agent 负责，同时便于反馈循环和职责隔离。

---

## Agent 职责矩阵

| Agent名称 | 核心职责（一句话） | 输入来自 | 输出文件 | 工具权限 | Fork? | 来源建议 |
|----------|------------------|---------|---------|---------|-------|---------|
| file-analyzer | 扫描项目目录，识别代码文件和文档结构 | 用户输入路径 | workspace/project-structure.md | Read, Bash | no | 原创 |
| content-writer | 基于分析结果编写教程正文（分步指南+代码示例） | project-structure.md | workspace/tutorial-content.md | Read, Write | no | 原创 |
| exercise-designer | 为每个章节设计动手练习题 | tutorial-content.md | workspace/exercises.md | Read, Write | no | 原创 |
| content-reviewer | 审查教程完整性和准确性，提供反馈 | tutorial-content.md, exercises.md | workspace/review-feedback.md | Read, Write | no | 原创 |
| assembler | 将所有内容组装为最终教程文档 | tutorial-content.md, exercises.md, review-feedback.md | workspace/final-tutorial.md | Read, Write | no | 原创 |

---

## 协作拓扑

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   ┌─────────────────┐                                                   │
│   │  file-analyzer  │                                                   │
│   │  (扫描项目结构)  │                                                   │
│   └────────┬────────┘                                                   │
│            │ project-structure.md                                        │
│            ▼                                                             │
│   ┌─────────────────┐                                                   │
│   │ content-writer  │◄──────────────────────────────────────┐          │
│   │  (编写教程正文) │                                       │          │
│   └────────┬────────┘                                       │          │
│            │ tutorial-content.md                            │          │
│            ▼                                                 │          │
│   ┌─────────────────┐                                       │          │
│   │exercise-designer │                                       │          │
│   │  (设计练习题)    │                                       │          │
│   └────────┬────────┘                                       │          │
│            │ exercises.md                                    │          │
│            ▼                                                 │          │
│   ┌─────────────────┐     review-feedback.md      ┌────────┴───────┐  │
│   │content-reviewer │ ──────────────────────────► │  (反馈循环)     │  │
│   │   (审查质量)    │     (通过则继续)            │  最多 2 轮      │  │
│   └────────┬────────┘                            └────────────────┘  │
│            │ (通过)                                              │
│            ▼                                                     │
│   ┌─────────────────┐                                           │
│   │   assembler     │                                           │
│   │  (组装最终文档) │                                           │
│   └─────────────────┘                                           │
│            │                                                     │
│            ▼                                                     │
│   final-tutorial.md                                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────────────┘
```

**拓扑类型**：串行 + 反馈循环

**并行组**：无（原并行设计经 Council 分析后改为串行，因 exercise-designer 依赖教程内容上下文）

**反馈循环说明**：
- content-reviewer 审查后，如发现问题，将反馈写入 review-feedback.md
- content-writer 根据反馈修改 tutorial-content.md
- 最多迭代 2 轮，由 review-round.txt 计数
- 第 3 轮自动通过，进入 assembler

---

## Skill 提取清单

| Skill名称 | 触发场景 | 使用它的Agent | 需要辅助脚本 |
|----------|---------|-------------|------------|
| self-improving-agent | 自动启用（self-improving=yes） | 所有 agent | no |

**说明**：本 team 为纯内容生成型，不需要外部 skill 集成。self-improving-agent 由 toolsmith-infra 自动配置到输出目录。

---

## MCP 需求

**无**

本 team 不需要外部 API 或数据库连接，完全依赖本地文件操作。

---

## 技术决策说明

1. **串行拓扑替代并行**：原用户设计建议 file-analyzer 与 exercise-designer 并行，但经 Council 分析，exercise-designer 需要教程内容上下文才能设计匹配的练习题，并行会导致练习题与内容脱节。因此改为串行。

2. **反馈循环限 2 轮**：content-reviewer 可能有主观判断差异，限制 2 轮避免无限迭代，同时保证质量。

3. **Bash 权限最小化**：仅 file-analyzer 需要 Bash（用于目录扫描），其他 agent 均为 Read/Write，降低风险。

4. **self-improving 自动配置**：用户要求 self-improving=yes，toolsmith-infra 将在生成目录中配置 .claude/skills/self-improving-agent/。

---

## 共享资源清单

| 共享文件 | 所有者 Agent（唯一写入者）| 读取者 | 初始化内容模板 |
|---------|-------------------------|-------|---------------|
| project-structure.md | file-analyzer | content-writer | `# 项目结构分析\n\n## 入口文件\n\n## 核心模块\n\n## 依赖关系\n` |
| tutorial-content.md | content-writer | exercise-designer, content-reviewer, assembler | `# 教程内容\n\n## 第一章：...\n` |
| exercises.md | exercise-designer | content-reviewer, assembler | `# 练习题\n\n## 第一章练习\n` |
| review-feedback.md | content-reviewer | content-writer | `# 审查反馈\n\n## 问题列表\n\n## 修改建议\n` |
| review-round.txt | content-reviewer | content-reviewer | `0` |
| final-tutorial.md | assembler | 无（最终输出） | `# [项目名] 交互式教程\n` |

---

## Fork 安全性校验

本架构无并行 Fork agent，所有 agent 串行执行，不存在 Fork 冲突风险。

- [x] 无 Fork agent 间的文件写入冲突
- [x] 每个 agent 的输出文件名包含自己的名字前缀（如 file-analyzer → project-structure.md 需重命名）
- [x] 不存在多个 agent 写入同一文件的情况

**修正**：建议输出文件名统一为 `[agent-name]-output.md` 格式：
- file-analyzer → file-analyzer-output.md
- content-writer → content-writer-output.md
- exercise-designer → exercise-designer-output.md
- content-reviewer → content-reviewer-output.md
- assembler → assembler-output.md（即 final-tutorial.md）

---

## 初始化步骤

CLAUDE.md 的工作流程开头必须包含的初始化操作：

1. 创建 `.claude/workspace/` 目录（如不存在）
2. 初始化 `review-round.txt`，内容为 `0`
3. 由 file-analyzer 在第一步执行项目扫描

---

## 待 Visionary-UX 深化

- [ ] file-analyzer：项目结构识别的详细提示词，如何处理 Python vs JavaScript 项目差异
- [ ] content-writer：教程章节划分逻辑，代码示例提取策略
- [ ] exercise-designer：练习题难度分级，答案验证机制
- [ ] content-reviewer：审查标准的具体定义（完整性、准确性、连贯性）
- [ ] assembler：最终文档的格式规范（Markdown 模板）

---

## 待 Visionary-Tech 确认

- [ ] self-improving-agent skill 的自动配置确认（已在 Skill 清单中）
- [ ] file-analyzer 的 Bash 命令限制（仅允许 `ls`、`find`、`cat` 等读取命令）
- [ ] 反馈循环的计数器实现（review-round.txt 的读写逻辑）