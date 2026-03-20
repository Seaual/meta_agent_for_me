# Council Technical Analysis

## 分解策略

**选用策略**：按职能分解

**选择理由**：
1. 学习路线规划任务天然按职能分工：研究 → 设计 → 搜集 → 规划 → 汇总
2. 各职能相对独立，输入输出边界清晰，便于并行执行
3. 用户时间紧迫，职能分解可最大化并行效率

---

## Agent 职责矩阵

| Agent | 核心职责 | 输入 | 输出 | 工具权限 | Fork? |
|-------|---------|------|------|---------|-------|
| `domain-researcher` | 低空经济领域概览 + TSP/路线规划核心概念研究 | `phase-0-requirements.md` | `domain-knowledge.md` | Read, Grep, Glob, WebSearch | yes |
| `resource-scout` | GitHub 开源代码 + 学术文献搜索 | `phase-0-requirements.md` | `resources-collected.md` | Read, WebSearch, WebFetch | yes |
| `learning-planner` | 学习路径设计（课程/文献/实践三轨） | `domain-knowledge.md`, `resources-collected.md` | `learning-path.md` | Read, Write, Grep | no |
| `timeline-architect` | 时间规划（里程碑 + 截止日期 + 每日任务） | `learning-path.md` | `timeline.md` | Read, Write | no |
| `route-coordinator` | 综合汇总 + Markdown 最终文档 | 所有上游输出 | `learning-roadmap.md` (最终) | Read, Write, Grep | no |

---

## 协作拓扑

```
                    phase-0-requirements.md
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
    ┌──────────────────┐       ┌──────────────────┐
    │ domain-researcher│       │  resource-scout  │
    │   (并行 fork)    │       │   (并行 fork)    │
    └────────┬─────────┘       └────────┬─────────┘
             │                          │
             ▼                          ▼
      domain-knowledge.md      resources-collected.md
             │                          │
             └──────────┬───────────────┘
                        ▼
              ┌──────────────────┐
              │ learning-planner │ (串行)
              └────────┬─────────┘
                       │
                       ▼
               learning-path.md
                       │
                       ▼
              ┌──────────────────┐
              │timeline-architect│ (串行)
              └────────┬─────────┘
                       │
                       ▼
                  timeline.md
                       │
                       ▼
              ┌──────────────────┐
              │route-coordinator │ (串行)
              └────────┬─────────┘
                       │
                       ▼
            learning-roadmap.md (最终交付)
```

**拓扑类型**：混合型（初始并行 + 后续串行）

---

## Workspace 文件设计

| 文件名 | 写入者 | 读取者 | 格式 |
|-------|-------|-------|------|
| `domain-knowledge.md` | domain-researcher | learning-planner, route-coordinator | Markdown（结构化领域知识） |
| `resources-collected.md` | resource-scout | learning-planner, route-coordinator | Markdown（资源清单 + 链接） |
| `learning-path.md` | learning-planner | timeline-architect, route-coordinator | Markdown（三轨学习路径） |
| `timeline.md` | timeline-architect | route-coordinator | Markdown（里程碑 + 甘特图） |
| `learning-roadmap.md` | route-coordinator | 用户 | Markdown（最终交付文档） |

---

## Skill 和 MCP 需求

### 需要的 Skill
| Skill | 用途 | 调用者 |
|-------|------|-------|
| `find-skill` | 搜索现有 skill 复用 | toolsmith-skills |
| `create-skill` | 从零创建 skill | toolsmith-skills |

### 需要的 MCP
| MCP | 用途 | 依赖 Agent |
|-----|------|-----------|
| `@anthropic-ai/mcp-server-github` | 搜索 GitHub 仓库、查看 README | resource-scout |
| 无需额外 MCP | WebSearch 可直接搜索学术文献 | resource-scout, domain-researcher |

**MCP 集成方案**：
- **GitHub**：resource-scout 通过 MCP 搜索低空经济/TSP/路线规划相关的开源项目，获取代码复现资源
- **学术文献**：使用内置 WebSearch 搜索 Google Scholar/arXiv/知网，无需额外 MCP

---

## 数据流详细设计

### Phase 1：并行研究（domain-researcher || resource-scout）

**domain-researcher 输出结构**：
```markdown
# 低空经济领域知识

## 领域概述
[定义、发展历程、核心概念]

## TSP 问题
[数学模型、经典算法、研究前沿]

## 路线规划
[问题分类、主流方法、应用场景]

## 研究热点
[近期高引论文方向、未解决问题]

## 推荐切入点
[3-5 个潜在研究方向]
```

**resource-scout 输出结构**：
```markdown
# 学习资源汇总

## GitHub 项目
| 项目名 | Stars | 描述 | 链接 | 推荐指数 |
|-------|-------|------|------|---------|

## 学术文献
| 标题 | 作者 | 年份 | 来源 | 链接 |
|-----|------|------|------|------|

## 在线课程
| 名称 | 平台 | 时长 | 链接 |
|-----|------|------|------|
```

### Phase 2：学习路径设计（learning-planner）

输入：`domain-knowledge.md` + `resources-collected.md`

输出结构：
```markdown
# 学习路径设计

## 第一阶段：快速入门（2周）
### 课程学习
### 文献精读
### 实践任务

## 第二阶段：深入专题（4周）
...

## 第三阶段：研究切入（6周）
...
```

### Phase 3：时间规划（timeline-architect）

输入：`learning-path.md`

输出结构：
```markdown
# 时间规划

## 总体里程碑
| 里程碑 | 截止日期 | 交付物 |
|-------|---------|-------|

## 每周计划
### Week 1 (Mar 24 - Mar 30)
- [ ] 任务1
- [ ] 任务2

## 每日建议
- 学习时间：6h/天
- 分配原则：40% 文献 + 30% 代码 + 30% 写作
```

### Phase 4：最终汇总（route-coordinator）

合并所有输出，生成完整的学习路线图文档。

---

## 技术风险

| 风险 | 影响 | 缓解措施 |
|-----|------|---------|
| WebSearch 结果不稳定 | 资源搜集质量波动 | 提供备选关键词，多次搜索取并集 |
| GitHub MCP 未配置 | 无法获取仓库详情 | 降级为 WebFetch 抓取 README |
| 领域知识更新快 | 推荐内容过时 | 标注「截至 2026-03」，建议用户自行验证 |

---

## 与 Critical 的潜在分歧点

如果 Critical 建议减少 agent 数量（如合并 domain-researcher 和 resource-scout），技术上可行但会损失并行效率。考虑到用户时间紧迫，建议保留并行设计。

如果 Critical 建议简化 MCP 集成，技术上可以完全依赖 WebSearch，但 GitHub MCP 能提供更精准的代码资源搜索。

---

## 下一步

1. 等待 Strategic 和 Critical 分析完成
2. director-council 进行收敛裁决
3. 输出 `council-convergence.md`