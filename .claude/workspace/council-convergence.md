# Council 收敛结论 — 题目工厂 Agent Team

## 收敛规则应用

| 议题 | Strategic | Critical | Technical | 采用规则 | 结论 |
|------|-----------|----------|-----------|---------|------|
| Agent 数量 | 5-agent | 2-agent | 5-agent | 规则2：两方共识 → 采纳多数方 | **5-agent** |
| Python 脚本复用 | 保留为工具 | 保留为工具 | 保留为工具 | 规则1：三方共识 → 直接采纳 | **全部保留** |
| 附件索引单一写入者 | 未明确 | 必须单一写入者 | attachment-matcher 独占 | 规则1：两方共识 | **attachment-matcher 独占** |
| Batch validation | 未明确 | 全量执行 | 全量执行 | 规则1：两方共识 | **全量生成后 batch check** |
| 重试上限 | 3次 | 3次 | 3次 | 规则1：三方共识 | **每题最多3次** |
| Fork/Worktree | 未明确 | 不必要 | 不引入 | 规则1：两方共识 | **不引入 Fork** |
| Self-Improving | 未提及 | 不必要 | 未提及 | 规则4：Critical 简化满足核心价值 | **不启用** |

---

## 最终决策

### 1. Agent 架构：5-Agent 串行流水线

```
用户输入题目数量 N
    │
    ▼
topic-planner（主题规划）→ topic-plan.json
    │
    ▼
question-generator（题目生成）→ questions-batch-N.json
    │
    ▼
attachment-matcher（附件匹配）→ questions-with-attachments.json + 更新 _index.json
    │
    ▼
quality-validator（质量验证）→ validation-report.json
    │
    ├── 通过 ──→ data-coordinator → CSV 输出
    └── 不通过 ──→ 返回 question-generator 重写（最多 3 轮）
```

### 2. 关键约束吸收（来自 Critical）

| 约束 | 实现方式 |
|------|---------|
| 附件索引单一写入者 | attachment-matcher 独占 `_index.json` 写入，data-coordinator 只做最终确认 |
| Batch validation | 全部题目生成后执行 pairwise similarity，不逐题验证 |
| 重试上限 | 每题最多 3 次，超限标记「需人工审核」并继续 |
| 附件格式预检 | topic-planner 阶段检查 manifest 中 PDF>=20% + Excel>=20%，不满足提前告警 |
| Schema 兜底 | agent 生成题目必须通过 `generate_question.py` parser 或 `validate.py` per-row check |

### 3. 成功指标（来自 Strategic）

| 指标 | 目标值 |
|------|--------|
| 单题生产时间 | < 2 分钟 |
| 同质化通过率 | >= 95% |
| 附件合规率 | 100% |
| 类目覆盖率 | 100%（7个L1） |
| 自动重试成功率 | >= 90% |

### 4. 边界定义（来自 Strategic）

- **Team 内**：主题规划、题目生成、附件匹配、质量验证、数据协调、工具脚本调用
- **Team 外**：种子内容维护、题目分发/发布、答案/解析生成、用户权限管理

### 5. 工具权限策略（来自 Technical）

| Agent | 权限 |
|-------|------|
| topic-planner | Read, Write |
| question-generator | Read, Write, Bash |
| attachment-matcher | Read, Write, Bash |
| quality-validator | Read, Write, Bash |
| data-coordinator | Read, Write, Bash |

### 6. 不引入的组件（Critical + Technical 共识）

- 不引入 `context: fork`（流程天然串行）
- 不引入 Worktree 隔离（5 个 agent 文件少，无写冲突）
- 不启用 Self-Improving / Instincts（批处理任务，学习价值有限）
- 不额外引入 MCP（现有 Python 脚本覆盖全部需求）
