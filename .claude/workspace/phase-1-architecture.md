# Visionary-Arch 架构方案

## 系统边界

**触发条件**：用户需要针对「低空经济 + TSP + 路线规划」领域生成系统性学习路线，目标是发表 SCI 一区论文。

**输入**：
- 用户背景（博士生、原研究方向、时间约束）
- 目标领域（低空经济、路线规划、TSP 问题）
- 输出要求（Markdown 文档、中英文混合）

**输出**：
- `learning-roadmap.md` — 完整学习路线文档
- 包含：领域知识概览、学习路径、资源清单、时间规划、研究切入点

**外部依赖**：
- WebSearch / WebFetch — 用于搜索学术论文、课程资源
- GitHub（可选 MCP）— 用于搜索开源代码

---

## 分解策略

**选用**：按职能 + 按数据流混合

**理由**：
1. 两个 agent 职责边界清晰（领域研究 vs 学习规划），适合按职能划分
2. 数据流是单向的（领域知识 → 学习规划），适合串行汇聚
3. domain-researcher 可独立并行执行，不影响下游

---

## Agent 职责矩阵

| Agent 名称 | 核心职责（一句话） | 输入来自 | 输出文件 | 工具权限 | Fork? | 来源建议 |
|-----------|-------------------|---------|---------|---------|-------|---------|
| **domain-researcher** | 构建低空经济 + TSP + 路线规划领域知识图谱 | phase-0-requirements.md | workspace/domain-knowledge.md | Read, WebSearch, WebFetch | yes | 原创 |
| **learning-roadmap-planner** | 整合领域知识 + 资源搜集 + 设计学习路径 + 时间规划 | domain-knowledge.md, phase-0-requirements.md | workspace/learning-roadmap.md | Read, Write, WebSearch, WebFetch | no | 原创 |

### 详细职责说明

**domain-researcher**
- 搜索低空经济政策文件、行业报告、学术综述
- 梳理 TSP 问题变体、算法演进、研究热点
- 调研路线规划在低空场景的特殊约束（空域管理、避障、能耗）
- 输出结构化知识图谱（概念、关系、研究热点）

**learning-roadmap-planner**
- 读取领域知识图谱
- 搜索在线课程、经典教材、开源代码
- 设计三轨学习路径（课程/文献/实践）
- 制定里程碑时间表（考虑 3 月底前完成研究的紧迫性）
- 提供研究切入点建议（结合热点和可行性）
- 输出完整 Markdown 文档

---

## 协作拓扑

```
                     phase-0-requirements.md
                              │
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                           │
        ▼                                           ▼
┌───────────────────────┐              ┌─────────────────────────────┐
│   domain-researcher   │              │  learning-roadmap-planner   │
│    (context: fork)    │              │      (主 agent)             │
│                       │              │                             │
│  - 低空经济政策研究    │              │  1. 等待 domain-knowledge.md │
│  - TSP 问题调研       │              │  2. 搜索学习资源             │
│  - 路线规划场景分析   │              │  3. 设计学习路径             │
│                       │              │  4. 制定时间规划             │
└───────────┬───────────┘              │  5. 研究切入点建议           │
            │                          │                             │
            ▼                          └─────────────┬───────────────┘
   domain-knowledge.md                               │
            │                                        │
            │         ──────────────────────────────┘
            │
            ▼
   learning-roadmap.md ─────────────────────────────────────► 最终交付
```

**拓扑类型**：混合（并行扇出 + 串行汇聚）

**并行组**：domain-researcher 独立执行，learning-roadmap-planner 等待后启动

**数据流向**：
1. 两个 agent 共同读取 `phase-0-requirements.md`
2. domain-researcher 输出 `domain-knowledge.md`
3. learning-roadmap-planner 读取 `domain-knowledge.md`，输出最终交付

---

## Skill 提取清单

| Skill 名称 | 触发场景 | 使用它的 Agent | 需要辅助脚本 |
|-----------|---------|---------------|-------------|
| web-research | 系统性网络搜索、信息整合 | domain-researcher, learning-roadmap-planner | no |
| github-code-search | 搜索开源代码、算法实现 | learning-roadmap-planner | no |

**说明**：本需求主要是信息检索和整合，不需要复杂技能。`web-research` 可通过 WebSearch + WebFetch 工具组合实现，不抽取为独立 skill。

---

## MCP 需求

| 服务 | 用途 | 使用的 Agent | MCP 包 |
|-----|------|------------|-------|
| GitHub（可选） | 搜索开源 TSP 算法、路线规划代码 | learning-roadmap-planner | `@anthropic-ai/mcp-server-github` |
| Brave Search（内置） | 学术文献、课程资源搜索 | 两个 agent | 已内置 WebSearch |

**降级策略**：如果 GitHub MCP 未配置，learning-roadmap-planner 使用 WebSearch 直接搜索 `github.com` 上的相关仓库。

---

## Hook 需求

仅使用标准三 hook（安全检查 / 会话摘要 / 文档提醒），无业务特定 hook。

| Hook 名称 | 事件 | Matcher | 作用 | Profile 级别 |
|-----------|------|---------|------|-------------|
| 安全检查 | PreToolUse | Bash | 阻止危险命令 | minimal+ |
| 会话摘要 | Stop | — | 记录关键决策 | standard+ |
| 文档提醒 | PostToolUse | Write | 提醒更新相关文档 | strict |

**当前 Profile**：minimal（仅启用安全检查）

---

## 技术决策说明

### 为什么是 2 个 agent 而非 4-5 个？

1. **任务性质**：学习路线生成是一次性文档输出，不是持续运行的系统，过多 agent 增加协调成本
2. **数据流简单**：领域知识 → 学习规划，只需一个汇聚点
3. **负载均衡**：domain-researcher 专注深度研究，learning-roadmap-planner 负责综合整合

### 为什么 domain-researcher 使用 fork？

1. **独立性**：领域研究不依赖其他 agent 输出，可立即启动
2. **时间效率**：并行执行节省约 30-40% 时间
3. **无冲突**：domain-researcher 只写入自己的输出文件，不与其他 fork agent 竞争

### 为什么 learning-roadmap-planner 不使用 fork？

1. **依赖上游**：必须等待 domain-knowledge.md 完成后才能设计学习路径
2. **最终整合**：负责输出最终交付物，需要完整上下文

---

## 共享资源清单

| 共享文件 | 所有者 Agent（唯一写入者）| 读取者 | 初始化内容模板 |
|---------|---------------------|-------|-------------|
| `domain-knowledge.md` | domain-researcher | learning-roadmap-planner | `# 领域知识图谱\n\n## 低空经济\n\n## TSP 问题\n\n## 路线规划\n` |

**说明**：domain-researcher 独占写入，learning-roadmap-planner 只读。无竞争风险。

---

## Fork 安全性校验

对 `domain-researcher`（Fork=yes）检查：

- [x] 该 agent 不与其他 fork agent 写入同一文件（唯一 fork agent）
- [x] 该 agent 的输出文件名包含自己的名字前缀（`domain-knowledge.md`）
- [x] 无多 fork agent 协作需求

**结论**：Fork 配置安全。

---

## 初始化步骤

CLAUDE.md 的工作流程开头必须包含的初始化操作：

1. 创建 `.claude/workspace/` 目录（如不存在）
2. 初始化 `domain-knowledge.md` 空文件（由 domain-researcher 在执行时创建）
3. 由 **director-council** 在流程启动前完成

---

## 待 Visionary-UX 深化

- [ ] domain-researcher 的详细 prompt 设计（研究领域、信息整合方法）
- [ ] learning-roadmap-planner 的详细 prompt 设计（学习路径设计、时间规划逻辑）
- [ ] 两个 agent 的 frontmatter description 字段（触发条件 + example）

---

## 待 Visionary-Tech 确认

- [ ] GitHub MCP 是否需要配置（可选，降级方案已明确）
- [ ] 是否需要额外的辅助脚本（当前评估不需要）
- [ ] settings.json 的具体配置（minimal profile）

---

## 风险提示

| 风险 | 严重性 | 架构层面应对 |
|------|--------|-------------|
| 半年内从新手到 SCI 一区 | 极高 | learning-roadmap-planner 输出中明确标注风险和备选方案 |
| 时间窗口极窄 | 高 | 时间规划模块优先压缩学习阶段，快速进入研究 |
| TSP 创新空间有限 | 中 | domain-researcher 重点调研低空场景新约束、新应用 |