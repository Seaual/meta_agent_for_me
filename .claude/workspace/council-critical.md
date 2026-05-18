# Critical 视角分析 — 题目工厂 Agent Team

## 最简替代方案

如果只用 1-2 个 agent，能完成多少核心功能？

| 方案 | Agent 数 | 覆盖度 | 说明 |
|------|---------|--------|------|
| **最简版** | 2 | ~90% | 题目生成器（含主题规划+题目生成+附件匹配）+ 质量协调器（含验证+CSV输出） |
| **当前设计** | 5 | 100% | topic-planner + question-generator + attachment-matcher + quality-validator + data-coordinator |

**最简版可行路径**：
- Agent 1 `question-producer`：读取 seeds → 规划主题 → 生成题目 → 匹配附件（内嵌附件复用计数和格式占比检查）
- Agent 2 `quality-coordinator`：执行同质化/时效性/附件合规验证 → 自动重试 → 输出 CSV

**为什么 2 个 agent 可能足够**：
1. 主题规划本质是随机采样+行业亲和性过滤（seed_pool.py 已自动化），agent 只需确认覆盖 7 个 L1，不需要独立 agent
2. 附件匹配在 `run_from_manifest.py` 中已改为「强制使用真实附件清单」，LLM 只需从给定列表中选择，不需要独立 agent 做复杂匹配
3. 验证和 CSV 输出是天然串行（先验证后输出），由同一个 agent 完成可减少文件传递开销
4. 自动重试逻辑在现有 Python 脚本中已实现（`_generate_with_retries`），agent 只需调用即可

**结论**：当前 5-agent 设计是「与原有流水线模块一一对应」的惯性映射，而非 Agent Team 的最优设计。原有流水线拆成 5 个 Python 模块是为了代码组织，不代表需要 5 个独立 agent。

---

## 假设挑战

| 假设 | 是否合理 | 风险 |
|-----|---------|------|
| Agent 生成题目质量 >= 现有 Python 调用 LLM 的质量 | **存疑** | 现有 `generate_question.py` 有精心设计的 robust parser（XML/JSON/regex 三级回退），agent 直接生成可能丢失字段或格式不符 |
| 5 个 agent 串行/并行执行比单脚本更快 | **有风险** | Agent 间文件传递、上下文切换、等待开销可能远超 Python ThreadPoolExecutor 的 4  worker 并行 |
| 附件复用计数（最多 2 次）可由 agent 可靠维护 | **高风险** | 多 agent 并行时，`attachments/_index.json` 的 `used_in` 字段存在竞态条件，除非加文件锁 |
| 同质化检查（相似度<=30%）在 agent 层面有效 | **存疑** | 现有 validate.py 的 batch check 需要全量题目才能计算 pairwise similarity，agent 逐题生成时无法实时获知全局分布 |
| 每题 5-8 个附件、PDF>=20%、Excel>=20% 可持续满足 | **未验证** | 当前 manifest 中大量 topic 的附件全是 PDF（如 T01 6 个 PDF、0 个 Excel），Excel 占比要求可能无法满足 |
| Agent 替代 Python 脚本能降低维护成本 | **存疑** | 现有代码已高度成熟（robust parser、retry、batch validation），转为 agent 提示词后反而更难版本控制和单元测试 |
| 用户需要「Agent Team」而非「更好的 Python 脚本」 | **未验证** | 如果用户核心诉求是提升题目质量/产量，优化 prompt 和增加 LLM 调用次数可能比拆 agent 更有效 |

---

## 脆弱点清单

### 🔴 高风险

1. **附件复用计数的多 agent 竞态条件**
   - 描述：attachment-matcher 和 data-coordinator 都可能读写 `_index.json` 的 `used_in` 字段
   - 影响：并发执行时附件可能被复用超过 2 次，违反硬性约束
   - 缓解：必须由单一 agent 独占附件索引的读写，或回退到 Python 脚本维护索引

2. **同质化检查的「全局视野」缺失**
   - 描述：validate.py 的 batch check 需要全量题目计算 pairwise similarity、length variance、structural hash
   - 影响：如果 quality-validator 只检查单题或分批检查，无法发现跨批次的结构同质化
   - 缓解：必须等全部题目生成后再做 batch validation，这意味着「并行生成 + 串行验证」的架构，而非每个题生成后立即验证

3. **附件格式占比（PDF>=20%, Excel>=20%）可能无法满足**
   - 描述：当前 attachments_manifest.yaml 中 8 个 topic 的附件几乎全是 PDF，Excel 附件极少
   - 影响：如果 agent 严格执行格式占比要求，可能频繁触发重试甚至死循环
   - 缓解：Phase 0 应确认此约束的优先级，或要求先补充 Excel 附件源

4. **Agent 生成题目的格式稳定性**
   - 描述：现有 `generate_question.py` 有三层 parser 回退（XML → JSON → regex），agent 直接生成可能输出不符合 CSV schema 的内容
   - 影响：CSV 字段缺失或格式错误导致下游无法使用
   - 缓解：保留 `generate_question.py` 作为 agent 调用的工具，而非让 agent 直接生成原始文本

### 🟡 中风险

5. **主题覆盖 7 个 L1 的随机性风险**
   - 描述：seed_pool.py 的随机采样可能无法均匀覆盖 7 个一级类目
   - 影响：某批次可能遗漏某个 L1，违反覆盖要求
   - 缓解：在采样逻辑中加入「强制覆盖」约束，而非依赖 agent 事后检查

6. **自动重试的无限循环风险**
   - 描述：验证不通过自动重试，如果 prompt 或种子本身有问题，可能无限重试
   - 影响：消耗大量 token 和时间，无有效产出
   - 缓解：设置重试上限（如每题最多 3 次），超限标记为失败并继续

7. **Context Compaction 可能过早触发**
   - 描述：visionary-tech 和 toolsmith-agents 被标记为支持 Context Compaction
   - 影响：对于只有 5 个 agent 的 team，context 不太可能溢出，过早 compaction 反而丢失细节
   - 缓解：仅在 agent 提示词中声明支持，不强制触发

---

## 过度设计预警

| 组件 | 是否必要 | 理由 |
|------|---------|------|
| 独立 topic-planner agent | **可简化** | 主题采样是确定性算法（seed_pool.py），agent 只需调用脚本并确认 L1 覆盖，不需要独立 agent |
| 独立 attachment-matcher agent | **可简化** | `run_from_manifest.py` 已改为「强制使用真实附件清单」，agent 只需从给定列表选择，匹配逻辑已内嵌 |
| 独立 quality-validator agent | **可简化** | 验证是确定性脚本（validate.py），agent 调用脚本即可，不需要独立 agent 做「智能判断」 |
| 独立 data-coordinator agent | **可简化** | CSV 写入和重试触发可由生成 agent 或验证 agent 兼任，线性流程无需专职协调者 |
| Context Compaction | **不必要** | 5 个 agent 的 team 规模小，单 agent 处理的文件和上下文有限，不太可能触发溢出 |
| Worktree 隔离（Phase 4b） | **收益低** | 5 个 agent 文件的生成工作量很小，worktree 的隔离收益远低于管理成本 |
| Self-Improving / Instincts | **不必要** | 题目生成是批处理任务，非长期运行服务，学习积累的价值有限 |

**最简可行架构建议**：
```
用户输入题目数量
    │
    ▼
question-producer（调用 seed_pool.py + generate_question.py + 附件选择）
    │
    ▼
quality-coordinator（调用 validate.py batch check + CSV 输出 + 失败重试调度）
    │
    ▼
输出 CSV + 附件包
```

---

## 对现有流水线代码的依赖分析

现有代码质量高，不应「为了 agent 化而 agent 化」：

| 脚本 | 质量评估 | Agent 化建议 |
|------|---------|-------------|
| `seed_pool.py` | 高（确定性算法，含行业亲和性、去重日志）| **保留为工具**，agent 调用即可 |
| `generate_question.py` | 高（三层 parser 回退、retry、API 封装）| **保留为工具**，agent 提供 seed 和参数 |
| `validate.py` | 高（per-row + batch 双层级、6 项同质化检查）| **保留为工具**，agent 调用并解析结果 |
| `fetch_attachments.py` | 高（下载、索引、MD5、SSL 处理）| **保留为工具**，agent 按需调用 |
| `run_daily.py` | 高（ThreadPoolExecutor 并行、retry、CSV 输出）| **参考其流程设计 agent 协作逻辑** |
| `run_from_manifest.py` | 高（真实附件强制约束、索引更新、文件复制）| **核心参考**，其「强制附件清单」模式应被 agent 继承 |

**关键洞察**：`run_from_manifest.py` 已经解决了「附件名称与内容对应」的核心痛点（通过强制使用真实附件清单）。这比拆成 5 个 agent 更有价值，agent 设计应继承此模式而非重新发明。

---

## 关键控制点

### 必须把关（🔴 不可妥协）

1. **附件索引的单一写入者**
   - 无论架构如何拆分，`_index.json` 的 `used_in` 字段必须由单一组件维护，禁止多 agent 并发写入
   - 建议：由 quality-coordinator 在最终 CSV 输出前统一更新索引

2. **Batch Validation 的全量执行**
   - 同质化检查必须在全部题目生成后执行，不能逐题或分批验证
   - 建议：生成阶段只保留 per-row 检查，batch check 作为最终 gate

3. **附件格式占比的预检**
   - 在生成前检查 manifest 中各 topic 的附件格式分布，如果无法满足 PDF>=20% + Excel>=20%，提前告警而非生成后失败

4. **生成输出的 Schema 约束**
   - 即使 agent 直接生成题目，也必须通过 `generate_question.py` 的 parser 或 `validate.py` 的 per-row check，确保字段完整

### 建议把关（🟡 重要但可降级）

5. **重试上限**：每题最多 3 次重试，超限跳过避免无限循环
6. **L1 覆盖预检**：采样后、生成前检查是否覆盖 7 个 L1，未覆盖则补充种子
7. **附件复用预检**：生成前计算理论最大复用次数，避免生成后才发现超用

---

## 对 Strategic 分析的预设反驳

（Strategic 文件内容似乎与当前需求不匹配，内容为 video-commerce-creator 的分析。以下为基于题目工厂需求的独立批判。）

1. **如果 Strategic 建议保留 5-agent 设计以「与原有流水线模块一一对应」**：
   - 反驳理由：Python 模块拆分是为了代码组织（单一职责），Agent 拆分应基于「独立决策需求」和「并行收益」。原有流水线在 Python 中已是串行执行（run_daily.py 顺序调用），没有并行模块，不需要对应拆成 5 个 agent。

2. **如果 Strategic 强调「每个 agent 负责一个认知环节」**：
   - 反驳理由：题目生成是高度结构化的批处理任务，不是开放域的多步推理。现有 Python 脚本已经封装了所有「认知环节」，agent 的价值在于「协调和决策」而非「替代脚本的计算逻辑」。

3. **如果 Strategic 建议增加 agent 做「附件内容理解」或「题目创意发散」**：
   - 反驳理由：`run_from_manifest.py` 的「强制附件清单」模式已经消除了附件理解的需求（附件内容和用途在 manifest 中已预定义）。题目创意受限于种子池的组合，不需要额外发散。

---

## 推荐的最简可行架构

与当前 5-agent 设计对比：

| 维度 | 当前设计（5 agent） | 推荐最简（2 agent） |
|------|-------------------|-------------------|
| 主题规划 | topic-planner | 内嵌到 question-producer（调用 seed_pool.py） |
| 题目生成 | question-generator | question-producer（调用 generate_question.py） |
| 附件匹配 | attachment-matcher | 内嵌到 question-producer（从 manifest 强制选择） |
| 质量验证 | quality-validator | quality-coordinator（调用 validate.py） |
| CSV 输出 | data-coordinator | quality-coordinator（调用 csv writer） |
| 重试调度 | data-coordinator | quality-coordinator（统一调度） |
| 附件索引更新 | attachment-matcher + data-coordinator | quality-coordinator（单一写入者） |

**优势**：
- 减少 3 个 agent 的上下文切换和文件传递开销
- 附件索引由单一 agent 维护，消除竞态条件
- Batch validation 天然在全部生成后执行
- 保留所有高质量 Python 脚本作为工具，不重复造轮子
- 更符合现有 `run_from_manifest.py` 的成功实践

---

## 总结

题目工厂的 Agent Team 设计面临的核心矛盾是：**现有 Python 流水线已经高度成熟和自动化，Agent 化的价值不在于「拆分更多步骤」，而在于「提供更高层的协调和决策接口」**。

建议采用 **2-agent 最简架构**，将 5 个模块的认知负载合并为「生成」和「验证输出」两个环节，底层全部复用现有脚本。如果后续需要扩展（如增加人工审核节点、多批次并行生成），再逐步拆分为 3-4 个 agent。
