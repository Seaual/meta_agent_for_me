# Agent Scout 决策表

## 评分标准

| 维度 | 满分 | 说明 |
|-----|------|------|
| 职责匹配度 | 40 | 候选 description vs 目标职责 |
| Prompt 质量 | 20 | 五层结构完整度、边界处理、降级策略 |
| 工具权限兼容 | 20 | allowed-tools 差异，完全一致=20 |
| 定制改造成本 | 20 | 需修改比例：<10%=20, 10-30%=15, 30-60%=8, >60%=2 |

---

## domain-researcher

**目标职责**：领域知识调研、文献综述、知识图谱构建
**目标工具权限**：Read, WebSearch, WebFetch

| 候选 | 来源 | 评分 | 决策 | 理由 |
|-----|------|------|------|------|
| research-analyst | VoltAgent | 91/100 | 复用 | 职责高度匹配(38/40)，研究流程完整，工具权限完全一致，仅需 25% 改造加入知识图谱结构 |
| data-researcher | VoltAgent | 82/100 | 参考改造 | 数据研究能力强，但偏向数据收集而非领域知识图谱，需 40% 改造 |
| scientific-literature-researcher | VoltAgent | 78/100 | 参考设计 | 学术文献研究专业，但依赖 BGPT MCP，降级策略需调整 |
| market-researcher | VoltAgent | 75/100 | 参考设计 | 市场研究流程可参考，但职责偏离较大(商业分析 vs 学术研究) |

**最终决策：复用 research-analyst**

**改造要点**：
1. 增加「知识图谱构建」章节，定义结构化输出格式
2. 加入三轨并行研究模式（低空经济/TSP/路线规划）
3. 补充交叉验证和来源可信度评估
4. 调整 frontmatter：添加 `context: fork` 和 `color: cyan`

---

## learning-roadmap-planner

**目标职责**：学习路径设计、资源整合、时间规划、风险评估
**目标工具权限**：Read, Write, WebSearch, WebFetch

| 候选 | 来源 | 评分 | 决策 | 理由 |
|-----|------|------|------|------|
| product-manager | agency-agents | 89/100 | 改编复用 | 路线图设计能力出色(19/20)，工具权限完全一致，需 30% 改造：产品路线图 → 学习路线图 |
| documentation-engineer | VoltAgent | 78/100 | 参考设计 | 有学习路径设计章节，Prompt 结构完整可参考 |
| project-manager-senior | agency-agents | 69/100 | 参考设计 | 任务分解能力强，但职责偏离较大(项目管理 vs 学习规划) |

**最终决策：改编复用 product-manager**

**改编要点**：
1. 将「产品路线图」模板改编为「学习路线图」
2. 将「用户调研」改编为「领域知识读取」
3. 将「PRD」改编为「学习路径文档」
4. 增加「风险评估」和「备选方案」章节
5. 调整 frontmatter：移除 `context: fork`（需等待上游），设置 `color: green`

---

## 参考 Candidate 设计模式

### research-analyst (VoltAgent) 可参考的设计点

**五层结构**：
- Layer 1 — 职责定义：senior research analyst，跨领域综合研究
- Layer 2 — 研究方法：objective definition → source identification → data collection → quality assessment
- Layer 3 — 执行框架：Research Planning → Implementation Phase → Research Excellence
- Layer 4 — 输出规范：Executive summaries, Detailed findings, Data visualization, Methodology documentation
- Layer 5 — 质量保证：Fact checking, Peer review, Source validation, Logic verification

**边界处理**：
- Source evaluation: Credibility assessment, Bias detection, Fact verification
- Quality control: Fact verification, Source validation, Logic checking, Peer review

### product-manager (agency-agents) 可参考的设计点

**五层结构**：
- Layer 1 — Identity & Memory：10+ years PM experience, outcome-obsessed
- Layer 2 — Critical Rules：8 条核心规则（Lead with problem, Write press release before PRD...）
- Layer 3 — Technical Deliverables：PRD, Opportunity Assessment, Roadmap, GTM Brief
- Layer 4 — Workflow Process：Discovery → Framing & Prioritization → Definition → Delivery → Launch → Measurement
- Layer 5 — Success Metrics：Outcome delivery, Roadmap predictability, Stakeholder trust

**可复用模板**：
- Roadmap (Now / Next / Later) 结构
- Success Criteria 表格格式
- Rollback & Contingency 章节

**降级策略**：
- "Features are hypotheses. Shipped features are experiments."
- 明确标注 confidence level（如 "I'm at ~70% confidence on this"）

---

## 决策汇总

| 目标 Agent | 最终决策 | 候选来源 | 改造工作量 |
|-----------|---------|---------|-----------|
| domain-researcher | 复用 | VoltAgent/research-analyst | ~25% |
| learning-roadmap-planner | 改编复用 | agency-agents/product-manager | ~30% |