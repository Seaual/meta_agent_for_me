# Technical 视角分析 — 题目工厂 Agent Team

## 分解策略

**选用策略**：按数据流 + 职能边界分解
**选择理由**：
- 题目工厂是结构化批处理流水线，数据流清晰（种子 → 主题 → 题目 → 附件 → 验证 → CSV）
- 质量验证必须独立于生成，避免「自我通过」
- 附件复用计数和索引需要单一写入者，决定了 attachment-matcher / data-coordinator 的合并或串行关系
- 原有 Python 脚本已高度成熟，Agent 负责「决策和协调」而非「替代计算逻辑」

---

## Agent 职责矩阵草案

| Agent 名称 | 核心职责 | 输入 | 输出 | 工具权限 | Fork? |
|-----------|---------|------|------|---------|-------|
| topic-planner | 从 seeds/topics.yaml + companies.yaml 采样主题组合，确保 7 个 L1 类目覆盖，输出主题批次计划 | `seeds/topics.yaml`, `seeds/companies.yaml`, `seeds/attachments_manifest.yaml` | `topic-plan.json`（含 uid, L1/L2/L3, 切入, 公司, topic_id, 附件预分配） | Read, Write | no |
| question-generator | 基于 topic-plan.json 和 prompts/question_template.md，逐题生成题目正文（业务背景 + 核心任务 + 关键限制 + 参考依据），调用 generate_question.py 或自行生成 | `topic-plan.json`, `prompts/question_template.md` | `questions-batch-N.json`（每题含完整字段） | Read, Write, Bash | no |
| attachment-matcher | 根据题目内容从 attachments_manifest.yaml 匹配附件，管理复用计数（每附件最多 2 次），确保每题 5-8 个附件、PDF>=20%、Excel>=20%，调用 fetch_attachments.py 下载缺失附件 | `questions-batch-N.json`, `seeds/attachments_manifest.yaml`, `attachments/_index.json` | `questions-with-attachments.json` + 更新 `attachments/_index.json` | Read, Write, Bash | no |
| quality-validator | 执行同质化检查（相似度<=30%、长度差异、句式多样化、结构同质化<50%、范式固化<=5%）+ 时效性检查 + 附件合规检查，调用 validate.py | `questions-with-attachments.json` | `validation-report.json`（每题通过/失败/警告） | Read, Write, Bash | no |
| data-coordinator | 汇总通过验证的题目为标准化 CSV，输出到 output/ 目录；对验证失败题目触发自动重试（最多 3 次），超限标记为「需人工审核」；更新附件索引最终状态 | `validation-report.json`, `questions-with-attachments.json` | `output/questions_YYYYMMDD.csv` + `output/validation_summary.md` + 更新 `attachments/_index.json` | Read, Write, Bash | no |

**说明**：
- 5 个 agent 与原有流水线模块一一对应，但职责聚焦于「决策/生成/验证/协调」而非「替代脚本计算」
- 无 Fork agent：流程本质串行（主题 → 生成 → 附件 → 验证 → 输出），并行收益低且引入竞态风险
- attachment-matcher 独占 `_index.json` 写入，data-coordinator 只做最终汇总更新，避免竞态

---

## 协作拓扑

```
用户输入题目数量 N
    │
    ▼
┌─────────────────┐
│  topic-planner  │ ← 采样主题，确保 7 L1 覆盖，预分配附件 topic_id
│   (调用 seed_pool.py)
└────────┬────────┘
         │ topic-plan.json
         ▼
┌─────────────────┐
│ question-generator │ ← 逐题生成题目正文
│ (调用 generate_question.py 或自行生成)
└────────┬────────┘
         │ questions-batch-N.json
         ▼
┌─────────────────┐
│ attachment-matcher │ ← 匹配附件，管理复用计数，下载缺失附件
│ (调用 fetch_attachments.py)
└────────┬────────┘
         │ questions-with-attachments.json
         ▼
┌─────────────────┐
│ quality-validator  │ ← 同质化 + 时效性 + 附件合规检查
│ (调用 validate.py batch check)
└────────┬────────┘
         │ validation-report.json
         ├── 通过 ──→ data-coordinator → CSV 输出
         └── 不通过 ──→ 返回 question-generator 重写（最多 3 轮）
```

**拓扑类型**：串行为主，验证环节支持反馈循环（不通过时返回重写，最多 3 轮）

**关键决策**：batch validation 必须在全部题目生成后执行，不能逐题验证（因为 pairwise similarity 需要全量数据）。因此生成阶段只做 per-row 检查，batch check 作为最终 gate。

---

## Workspace 文件设计

| 文件名 | 写入者 | 读取者 | 格式 |
|-------|-------|-------|------|
| `topic-plan.json` | topic-planner | question-generator | JSON（主题批次计划） |
| `questions-batch-N.json` | question-generator | attachment-matcher, quality-validator | JSON（N 道题目，无附件） |
| `questions-with-attachments.json` | attachment-matcher | quality-validator, data-coordinator | JSON（含附件清单和路径） |
| `validation-report.json` | quality-validator | data-coordinator | JSON（每题状态 + 错误列表） |
| `coordinator-output.csv` | data-coordinator | 用户 / sentinel | CSV（标准化输出） |
| `coordinator-summary.md` | data-coordinator | 用户 / sentinel | Markdown（验证摘要 + 重试统计） |
| `attachments/_index.json` | attachment-matcher（主写入）, data-coordinator（最终更新） | attachment-matcher, data-coordinator | JSON（附件索引 + used_in） |

**受保护文件**：`team-name.txt`（已存在）

---

## Skill 和 MCP 需求

### 需要的 Skill

| Skill | 理由 |
|-------|------|
| `tool-forge` | 生成调用 Python 脚本的 Bash 模板（如 `python pipeline/generate_question.py --seed ...`） |
| `find-skill` | 检查是否已有现成的 YAML 处理或 CSV 生成 skill 可用 |

### 需要的 MCP / 外部工具

| 工具 | 用途 |
|-----|------|
| Python 3.10+ 运行时 | 执行原有流水线脚本（generate_question.py, validate.py, fetch_attachments.py, seed_pool.py） |
| PyYAML | 读取 seeds/*.yaml 文件 |
| `openai` Python 包 | generate_question.py 依赖（若保留其 LLM 调用能力） |
| 环境变量 `CLAUDE_FACTORY_KEY` | API 密钥，从 .env.local 读取 |

**技术决策**：
- 保留原有 Python 脚本作为 Agent 可调用的工具，不重新实现其逻辑
- Agent 直接生成题目时，输出必须兼容 validate.py 的 schema（通过 per-row check 保证）
- 不引入额外 MCP，现有脚本已覆盖全部需求

---

## 数据流详细设计

### Stage 1: 主题规划（topic-planner）

```
输入: seeds/topics.yaml + seeds/companies.yaml + seeds/attachments_manifest.yaml
处理:
  1. 调用 seed_pool.py 生成 (uid, 主体, 领域, 切入) 组合
  2. 检查 7 个 L1 类目是否全部覆盖，未覆盖则补充采样
  3. 为每题预分配 topic_id（关联到 attachments_manifest.yaml 中的 topic）
  4. 预检附件格式分布：如果某 topic 的附件无法满足 PDF>=20% + Excel>=20%，提前告警
输出: topic-plan.json
```

### Stage 2: 题目生成（question-generator）

```
输入: topic-plan.json + prompts/question_template.md
处理:
  1. 逐题读取主题参数（L1/L2/L3, 切入, 公司, topic_id）
  2. 基于 question_template.md 生成题目正文（含业务背景、核心任务、关键限制、参考依据）
  3. 确保每题含 4-5 条编号任务、时间锚点、>=8h 完成时间
  4. 输出严格 JSON schema（兼容 validate.py 的 REQUIRED_FIELDS）
  5. 若自行生成质量不稳定，可回退到调用 generate_question.py
输出: questions-batch-N.json
```

### Stage 3: 附件匹配（attachment-matcher）

```
输入: questions-batch-N.json + attachments_manifest.yaml + attachments/_index.json
处理:
  1. 根据 topic_id 从 manifest 获取候选附件列表
  2. 为每题选择 5-8 个附件，确保格式占比合规
  3. 检查 _index.json 的 used_in 字段，确保每附件复用 <= 2 次
  4. 若附件未下载，调用 fetch_attachments.py 下载
  5. 更新 _index.json（写入 used_in 和 fetched_at）
输出: questions-with-attachments.json + 更新后的 _index.json
```

### Stage 4: 质量验证（quality-validator）

```
输入: questions-with-attachments.json
处理:
  1. 调用 validate.py 执行 per-row check（字段完整性、L1 白名单、时间锚点、任务编号等）
  2. 调用 validate.py 执行 batch check（pairwise similarity <= 30%、length variance、句式模板占比、结构同质化、范式固化）
  3. 输出每题的通过/失败/警告状态
输出: validation-report.json
```

### Stage 5: 数据协调（data-coordinator）

```
输入: validation-report.json + questions-with-attachments.json
处理:
  1. 将通过验证的题目汇总为 CSV（字段顺序严格遵循 spec.md）
  2. 对失败题目：返回 question-generator 重写（最多 3 次）
  3. 超限题目标记为「需人工审核」，写入 summary
  4. 最终更新 _index.json（确认 used_in 状态）
  5. 输出 CSV 到 output/questions_YYYYMMDD.csv
输出: CSV + validation_summary.md + 最终 _index.json
```

---

## 关键技术决策

### 决策 1：保留原有 Python 脚本作为工具，而非完全 Agent 化

**理由**：
- `generate_question.py` 有三层 parser 回退（XML → JSON → regex），`validate.py` 有 per-row + batch 双层级检查，代码质量高且经过验证
- Agent 直接生成题目可能丢失字段或格式不符，通过脚本 parser 兜底更可靠
- `seed_pool.py` 的随机采样和行业亲和性逻辑是确定性算法，无需 Agent 干预

**实现**：每个 agent 的提示词中明确「优先调用现有脚本，仅在脚本无法处理时自行生成」

### 决策 2：attachment-matcher 独占 `_index.json` 写入

**理由**：
- Critical 指出的「附件复用计数竞态条件」是核心风险
- 串行流程中，attachment-matcher 在 data-coordinator 之前执行，天然避免并发写入
- data-coordinator 只做最终确认更新（如标记超限题目的附件状态），不修改 used_in 计数

### 决策 3：batch validation 必须在全量生成后执行

**理由**：
- `validate.py` 的 batch check 需要全量题目计算 pairwise similarity、length variance、structural hash
- 逐题验证无法发现跨题目的结构同质化（如 50 道题都用同一开头模板）
- 因此流程必须是「全量生成 → 全量验证 → 批量输出」，不能边生成边验证

### 决策 4：不引入 Fork 并行

**理由**：
- 5 个 agent 的串行流程无天然并行分支（附件匹配依赖题目生成结果，验证依赖附件匹配结果）
- 若未来需要加速，可在 question-generator 内部并行生成多题（由 Python ThreadPoolExecutor 处理，非 Agent 层面）
- Worktree 隔离对本团队收益低（5 个 agent 文件少，无写冲突风险）

### 决策 5：重试上限与失败降级

**理由**：
- Critical 指出的「无限循环风险」必须规避
- 每题最多 3 次重试（生成 → 验证失败 → 重写 → 验证 → 重写 → 验证）
- 第 3 次仍失败则标记为「需人工审核」，不阻塞整体流程，继续处理下一题

---

## 错误处理和降级方案

| 场景 | 处理策略 |
|-----|---------|
| generate_question.py parser 失败 | 回退到 agent 直接生成，但需通过 validate.py per-row check |
| 附件下载失败（fetch_attachments.py 返回 HTTP 错误） | 记录失败附件，尝试备选 URL，仍失败则标记该题「附件缺失」并告警 |
| 附件库无法满足格式占比（PDF>=20%, Excel>=20%） | 在 topic-planner 阶段预检并告警，避免生成后才发现 |
| batch validation 相似度 > 30% | 返回 question-generator 重写该题，最多 3 次 |
| 某 L1 类目未覆盖 | topic-planner 强制补充采样，不依赖随机性 |
| _index.json 损坏或丢失 | attachment-matcher 从 manifest 重建索引，复用计数归零（需人工确认） |
| 重试 3 次仍失败 | data-coordinator 标记为「需人工审核」，继续下一题 |

---

## 技术风险

- **⚠️ 附件复用计数的隐性冲突**：即使串行流程，如果用户中断后恢复，_index.json 可能处于不一致状态。缓解：data-coordinator 在 CSV 输出前做最终一致性检查。
- **⚠️ Agent 生成题目的格式稳定性**：agent 直接生成可能不兼容 validate.py 的 schema。缓解：强制通过 generate_question.py 的 parser 或 validate.py 的 per-row check 作为 gate。
- **⚠️ 种子数据质量依赖**：topic-planner 的输出质量完全依赖 seeds/ 文件的覆盖度。缓解：在 topic-planner 中加入「种子覆盖度审计」步骤，缺失时告警。
- **⚠️ 批处理规模与 context 溢出**：若 N=500 题，questions-batch-N.json 可能过大。缓解：按批次处理（每批 50 题），分多轮执行，或启用 Context Compaction（虽然 5-agent 团队规模小，但长 JSON 文件可能触发）。
- **⚠️ Bash 权限风险**：attachment-matcher 和 data-coordinator 需要 Bash 调用 Python 脚本。缓解：minimal profile 下仍需在 agent 提示词中明确说明 Bash 的使用场景（调用 pipeline/ 下的 Python 脚本），禁止执行其他命令。

---

## 与 Critical 的分歧点

Critical 建议采用 **2-agent 最简架构**（question-producer + quality-coordinator），将 5 个模块合并为「生成」和「验证输出」两个环节。

**技术上保留 5-agent 设计的理由**：

1. **附件索引的单一写入者需要独立 agent**
   - attachment-matcher 独占 `_index.json` 写入是避免竞态的关键
   - 如果合并到 question-producer，生成和附件管理耦合，增加认知负载

2. **质量验证必须独立于生成**
   - 这是不可压缩的底线：生成者无法客观评估自己的输出同质化
   - validate.py 的 batch check 需要全量数据，由独立 agent 执行更清晰

3. **数据协调（重试调度）需要全局视角**
   - data-coordinator 管理「哪些题需要重写、哪些已超限、最终 CSV 汇总」
   - 如果由 quality-coordinator 兼任，验证和调度的职责冲突

4. **与原有流水线的映射降低迁移风险**
   - 5 个 agent 与 5 个 Python 模块一一对应，便于调试和问题定位
   - 若合并为 2 个 agent，一个 agent 需要理解全部 5 个模块的逻辑，context 反而更复杂

5. **扩展性预留**
   - v2 可能增加「答案生成 agent」「难度分级 agent」，5-agent 架构更容易插入新节点
   - 2-agent 架构扩展时需要重新拆分

**妥协方案**：如果 Critical 坚持简化，可压缩为 **3-agent 架构**：
- `topic-generator`（topic-planner + question-generator 合并）
- `attachment-validator`（attachment-matcher + quality-validator 合并，但验证仍调用独立脚本）
- `data-coordinator`（保留，负责汇总和重试）

但 5-agent 设计在当前需求下是合理且可维护的，建议保留。
