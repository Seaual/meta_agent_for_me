## Agent 复用决策

**Team**: 题目工厂 (Question Factory)
**搜索时间**: 2026-05-18
**搜索范围**: VoltAgent (主库, 141 agents) + agency-agents (备选库, 184 agents)
**评估依据**: phase-2-tech-specs.md 中「Agent 搜索提示」表格

---

### 评估方法

| 维度 | 满分 | 说明 |
|-----|------|------|
| 职责匹配度 | 40 | 候选 description vs 目标职责 |
| Prompt 质量 | 20 | 五层结构完整度、边界处理、降级策略 |
| 工具权限兼容 | 20 | allowed-tools 差异，完全一致=20 |
| 定制改造成本 | 20 | 需修改比例：<10%=20, 10-30%=15, 30-60%=8, >60%=2 |

**决策阈值**：≥70 直接复用 | 50-69 改编复用 | 30-49 参考原创 | <30 纯原创

---

### 决策总览

| Agent名称 | 决策 | 候选文件 | 得分 | 改编要点 |
|---------|------|---------|------|---------|
| topic-planner | ✏️ 原创 | 无合适候选 | 29（最高） | — |
| question-generator | ✏️ 原创 | prompt-engineer（VoltAgent） | 42 | 可参考其五层 prompt 结构设计 |
| attachment-matcher | ✏️ 原创 | document-generator（agency-agents） | 35 | 可参考其多格式文件处理逻辑 |
| quality-validator | ✏️ 原创 | ai-data-remediation-engineer（agency-agents） | 47 | 可参考其语义聚类 + 异常评分机制 |
| data-coordinator | ✏️ 原创 | agents-orchestrator（agency-agents） | 42 | 可参考其重试循环 + QA gate 模式 |

---

### Agent 参考候选

| 目标 Agent | Top 候选 | 来源 | 得分 | 可参考的设计点 |
|-----------|---------|------|------|------------|
| topic-planner | podcast-strategist | agency-agents | 29 | 内容规划的分层结构（主题 → 子主题 → 内容点） |
| question-generator | prompt-engineer | VoltAgent | 42 | 五层 prompt 结构（Context / Instruction / Constraints / Examples / Output Format） |
| attachment-matcher | document-generator | agency-agents | 33 | 多格式文件处理（PDF/XLSX 识别与分类） |
| quality-validator | ai-data-remediation-engineer | agency-agents | 47 | 语义聚类 + 异常评分 + 检查清单模式 |
| data-coordinator | agents-orchestrator | agency-agents | 42 | 重试循环（retry loop）+ QA gate + 状态机 |

---

### 详细评分

#### 1. topic-planner（主题规划器）

**目标职责**：从种子池（seeds/*.yaml）采样主题组合，确保 L1 类目全覆盖，输出 topic-plan.json。
**目标权限**：Read, Write

| 候选 | 来源 | 职责匹配 | Prompt质量 | 工具兼容 | 改造成本 | 总分 |
|-----|------|---------|-----------|---------|---------|------|
| content-marketer | VoltAgent 08-business-product | 8/40 | 8/20 | 20/20 | 2/20 | 29 |
| podcast-strategist | agency-agents marketing | 10/40 | 8/20 | 20/20 | 2/20 | 29 |
| trend-analyst | VoltAgent 10-research-analysis | 8/40 | 10/20 | 20/20 | 2/20 | 28 |
| research-analyst | VoltAgent 10-research-analysis | 8/40 | 10/20 | 20/20 | 2/20 | 28 |

**分析**：题目工厂的 topic-planner 是高度垂直化的种子池采样器，需要理解 seeds/*.yaml 的结构、L1/L2 类目体系、附件格式配额（PDF 25%/Excel 25%）。现有库中无任何 agent 涉及「从结构化种子池采样并确保类目覆盖」的职责。

---

#### 2. question-generator（题目生成器）

**目标职责**：基于种子和 prompt 模板生成结构化题目，支持自然语言生成 + parser 兜底，输出 questions-batch-N.json。
**目标权限**：Read, Write, Bash

| 候选 | 来源 | 职责匹配 | Prompt质量 | 工具兼容 | 改造成本 | 总分 |
|-----|------|---------|-----------|---------|---------|------|
| prompt-engineer | VoltAgent 05-data-ai | 15/40 | 14/20 | 16/20 | 8/20 | 42 |
| llm-architect | VoltAgent 05-data-ai | 10/40 | 12/20 | 16/20 | 6/20 | 35 |
| technical-writer | VoltAgent 08-business-product | 10/40 | 10/20 | 16/20 | 6/20 | 33 |
| marketing-zhihu-strategist | agency-agents marketing | 12/40 | 10/20 | 14/20 | 6/20 | 35 |

**分析**：question-generator 需要深度理解题目工厂的业务规则（标题 300-1800 字、任务编号 ≥2、附件 5-8 个、时效锚点、无《》无 URL 等），并兼容现有 prompts/question_template.md 的五层结构。prompt-engineer 虽然涉及 prompt 设计，但完全不涉及题目内容生成和结构化输出。

**可参考设计点**：prompt-engineer 的五层 prompt 结构（Context / Instruction / Constraints / Examples / Output Format）可作为 question-generator 的 prompt 设计参考。

---

#### 3. attachment-matcher（附件匹配器）

**目标职责**：根据题目种子匹配 attachments_manifest.yaml 中的附件，维护 _index.json 复用索引（每附件最多复用 2 次），输出 questions-with-attachments.json。
**目标权限**：Read, Write, Bash

| 候选 | 来源 | 职责匹配 | Prompt质量 | 工具兼容 | 改造成本 | 总分 |
|-----|------|---------|-----------|---------|---------|------|
| identity-graph-operator | agency-agents specialized | 8/40 | 10/20 | 16/20 | 6/20 | 29 |
| document-generator | agency-agents specialized | 10/40 | 10/20 | 16/20 | 6/20 | 33 |
| data-engineer | VoltAgent 05-data-ai | 10/40 | 12/20 | 16/20 | 6/20 | 35 |
| report-distribution-agent | agency-agents specialized | 12/40 | 10/20 | 16/20 | 6/20 | 35 |

**分析**：attachment-matcher 的核心是「根据题目种子的主体+切入映射到 attachments_manifest.yaml 的 topic，维护 used_in <= 2 的复用约束」。现有库中无任何 agent 涉及文件复用索引管理。

**可参考设计点**：identity-graph-operator 的模糊匹配逻辑（fuzzy matching）可作为附件-题目相似度匹配的参考；document-generator 的多格式文件处理能力可作为附件格式检查（PDF/Excel 比例）的参考。

---

#### 4. quality-validator（质量验证器）

**目标职责**：执行逐行检查（字段、长度、格式、时效性）+ 批量同质化检查（pairwise similarity、结构 hash、范式分布），输出 validation-report.json。
**目标权限**：Read, Write, Bash

| 候选 | 来源 | 职责匹配 | Prompt质量 | 工具兼容 | 改造成本 | 总分 |
|-----|------|---------|-----------|---------|---------|------|
| code-reviewer | VoltAgent 04-quality-security | 10/40 | 14/20 | 16/20 | 6/20 | 37 |
| qa-expert | VoltAgent 04-quality-security | 12/40 | 12/20 | 16/20 | 6/20 | 37 |
| compliance-auditor | VoltAgent 04-quality-security | 10/40 | 12/20 | 16/20 | 6/20 | 35 |
| ai-data-remediation-engineer | agency-agents engineering | 18/40 | 12/20 | 16/20 | 8/20 | 47 |
| model-qa | agency-agents specialized | 10/40 | 10/20 | 16/20 | 6/20 | 33 |
| test-results-analyzer | agency-agents testing | 10/40 | 10/20 | 16/20 | 6/20 | 33 |

**分析**：quality-validator 的批量同质化检测（H1-H6 规则：pairwise similarity <30%、标题长度差异、相同开头、结构 hash、范式分布、附件复用）是题目工厂特有的质量模型，与通用的数据异常检测或软件 QA 完全不同。ai-data-remediation-engineer 虽然涉及语义聚类和相似度检查，但其目标是「修复数据异常」而非「验证内容同质化」。

**可参考设计点**：ai-data-remediation-engineer 的语义聚类逻辑（semantic clustering）和异常评分机制可作为 quality-validator 的同质化检测算法参考；qa-expert 的检查清单（checklist）模式可作为逐行验证的格式参考。

---

#### 5. data-coordinator（数据协调器）

**目标职责**：汇总所有通过验证的题目，生成标准化 CSV（UTF-8-SIG）、复制附件到 output/attachments/、管理重试循环（最多 3 轮）、标记需人工审核题目，输出 final-summary.md。
**目标权限**：Read, Write, Bash

| 候选 | 来源 | 职责匹配 | Prompt质量 | 工具兼容 | 改造成本 | 总分 |
|-----|------|---------|-----------|---------|---------|------|
| data-analyst | VoltAgent 05-data-ai | 12/40 | 12/20 | 16/20 | 6/20 | 37 |
| data-engineer | VoltAgent 05-data-ai | 15/40 | 12/20 | 16/20 | 8/20 | 42 |
| workflow-orchestrator | VoltAgent 09-meta-orchestration | 12/40 | 12/20 | 16/20 | 6/20 | 37 |
| multi-agent-coordinator | VoltAgent 09-meta-orchestration | 10/40 | 12/20 | 16/20 | 6/20 | 35 |
| task-distributor | VoltAgent 09-meta-orchestration | 10/40 | 10/20 | 16/20 | 6/20 | 33 |
| agents-orchestrator | agency-agents specialized | 15/40 | 12/20 | 16/20 | 8/20 | 42 |
| workflow-architect | agency-agents specialized | 12/40 | 12/20 | 16/20 | 8/20 | 39 |
| accounts-payable-agent | agency-agents specialized | 10/40 | 10/20 | 16/20 | 6/20 | 33 |
| report-distribution-agent | agency-agents specialized | 12/40 | 10/20 | 16/20 | 6/20 | 35 |

**分析**：data-coordinator 是题目工厂流水线的「收口」agent，需要理解全部中间文件格式（topic-plan.json → questions-batch-N.json → questions-with-attachments.json → validation-report.json → retry-batch.json），执行 CSV 格式化（含 BOM）、附件目录组织、重试状态机（retry_count >= 3 → needs_manual_review）。现有库中的 data-engineer 或 agents-orchestrator 虽然涉及数据管道或重试，但完全不涉及题目工厂的垂直业务逻辑。

**可参考设计点**：
- agents-orchestrator 的重试循环模式（retry loop + QA gate）可作为 data-coordinator 重试状态机的参考
- workflow-architect 的 timeout/cleanup 模式可作为 data-coordinator 异常处理的参考
- report-distribution-agent 的 territory routing 逻辑可作为「按 uid 组织附件子目录」的参考

---

### 验证结论

Visionary-Tech 的预判正确：**题目工厂是垂直领域专用流水线，5 个 agent 均为原创设计，无现成 agent 可直接复用。**

所有候选 agent 的得分均低于 50 分的改编复用阈值，最高分为 quality-validator 的 ai-data-remediation-engineer（47 分），属于「可参考设计模式」级别。

**建议**：在原创设计时，吸收上述 Top 候选的可用设计模式：
1. **五层 prompt 结构**（prompt-engineer）：Context / Instruction / Constraints / Examples / Output Format
2. **重试循环状态机**（agents-orchestrator）：retry loop + QA gate + 状态转换
3. **语义聚类评分**（ai-data-remediation-engineer）：异常检测 + 聚类 + 评分机制
4. **检查清单模式**（qa-expert）：结构化 checklist + 分级严重程度
5. **多格式文件处理**（document-generator）：PDF/XLSX 识别与分类表格
