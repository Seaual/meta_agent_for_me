# Technical 视角分析

## 分解策略

**选用策略**：按职能分解
**选择理由**：教程生成涉及独立的职能环节（分析、写作、设计练习、审查、组装），各职能专业度差异大，适合独立 agent 负责。

---

## Agent 职责矩阵草案

| Agent | 核心职责 | 输入 | 输出 | 工具权限 | Fork? |
|-------|---------|------|------|---------|-------|
| file-analyzer | 扫描项目目录，识别代码结构 | 项目路径 | project-structure.md | Read, Bash | no |
| content-writer | 编写教程正文（分步指南+代码示例） | project-structure.md | tutorial-content.md | Read, Write | no |
| exercise-designer | 设计练习题 | tutorial-content.md | exercises.md | Read, Write | no |
| content-reviewer | 审查完整性和准确性 | tutorial-content.md, exercises.md | review-feedback.md | Read, Write | no |
| assembler | 组装最终教程文档 | tutorial-content.md, exercises.md | final-tutorial.md | Read, Write | no |

---

## 协作拓扑

```
                    ┌─────────────────┐
                    │ file-analyzer   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ content-writer  │◄─────────────────┐
                    └────────┬────────┘                  │
                             │                           │
                             ▼                           │
                 ┌─────────────────────┐                 │
                 │ exercise-designer   │                 │
                 └──────────┬──────────┘                 │
                            │                            │
                            ▼                            │
                 ┌─────────────────────┐                 │
                 │  content-reviewer   │─────────────────┤
                 └──────────┬──────────┘      (反馈循环)  │
                            │ (最多2轮通过)               │
                            ▼                            │
                 ┌─────────────────────┐                 │
                 │     assembler       │                 │
                 └─────────────────────┘                 │
```

**拓扑类型**：串行 + 反馈循环

**调整说明**：Critical 建议将 exercise-designer 放在 content-writer 之后，技术上更合理。原并行设计会导致 exercise-designer 缺乏上下文。

---

## Workspace 文件设计

| 文件名 | 写入者 | 读取者 | 格式 |
|-------|-------|-------|------|
| project-structure.md | file-analyzer | content-writer | Markdown（文件树+关键文件说明） |
| tutorial-content.md | content-writer | exercise-designer, content-reviewer, assembler | Markdown（章节+代码块） |
| exercises.md | exercise-designer | content-reviewer, assembler | Markdown（题目+答案） |
| review-feedback.md | content-reviewer | content-writer | Markdown（问题列表+修改建议） |
| final-tutorial.md | assembler | 无（最终输出） | Markdown（完整教程） |
| review-round.txt | content-reviewer | content-reviewer | 纯文本（当前轮次计数） |

---

## Skill 和 MCP 需求

### 需要的 Skill

| Skill | 用途 | 使用者 |
|-------|------|--------|
| 无需外部 skill | 本任务为内容生成型，无需外部工具集成 | - |

**说明**：self-improving-agent skill 由 toolsmith-infra 自动配置（因为 self-improving = yes）。

### 需要的 MCP

**无**：本 team 不需要外部 API 或数据库连接。

---

## 工具权限分析

| Agent | 权限 | 理由 |
|-------|------|------|
| file-analyzer | Read, Bash | Bash 用于 `find`/`ls` 扫描目录结构 |
| content-writer | Read, Write | Read 项目文件，Write 教程内容 |
| exercise-designer | Read, Write | Read 教程内容，Write 练习题 |
| content-reviewer | Read, Write | Read 内容，Write 审查反馈 |
| assembler | Read, Write | Read 所有内容，Write 最终文档 |

**最小权限原则**：除 file-analyzer 外，其他 agent 均不需要 Bash。

---

## 技术风险

| 风险 | 缓解措施 |
|-----|---------|
| 项目目录过大导致扫描超时 | file-analyzer 限制深度，优先扫描入口文件 |
| 反馈循环无限迭代 | review-round.txt 计数器，超过 2 轮强制通过 |
| Bash 权限滥用风险 | file-analyzer 的 Bash 仅限读取命令，禁止修改操作 |

---

## 与 Critical 的分歧点

**分歧**：原设计的并行关系（file-analyzer || exercise-designer）

**Technical 认同 Critical 建议**：
- exercise-designer 需要教程内容上下文才能设计匹配的练习题
- 并行会导致练习题与内容脱节
- 建议改为串行：content-writer → exercise-designer

**修正后的拓扑**：
```
file-analyzer → content-writer → exercise-designer → content-reviewer → assembler
                                       ↑                      │
                                       └──────────────────────┘ (反馈)
```