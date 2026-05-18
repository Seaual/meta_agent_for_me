## 📐 Visionary-Arch 架构方案

### 系统边界
**触发条件**：用户输入题目数量 N（如"生成 50 道题"），主题/类目由 team 从种子池自动选取。
**输入**：
- `seeds/topics.yaml` — 主题种子池
- `seeds/companies.yaml` — 公司/业务场景种子
- `prompts/question_template.md` — 题目生成模板
- `attachments_manifest.yaml` — 附件清单与元数据
- 用户输入的题目数量 N
**输出**：
- `output/questions.csv` — 标准化 CSV（含 uid、题目、类目、任务概括、专家年限、完成时间、附件清单、产物格式等字段）
- `output/attachments/` — 附件文件（PDF/Excel/Word 等，5-8 个/题）
- `output/validation-report.json` — 验证报告（同质化检查 + 时效性检查 + 附件合规检查）
**外部依赖**：
- 原有 Python 工具脚本（`generate_question.py`、`validate.py`、`fetch_attachments.py`）作为本地可调用工具，不引入额外 MCP。

### 分解策略
**选用**：按数据流分解
**理由**：题目工厂的核心是数据从种子到成品的流水线式转换，每一步都有明确的输入格式和输出格式。按数据流分解使 agent 间的接口清晰（JSON 中间文件），天然契合 5 个模块的串行依赖关系，且便于在 quality-validator 处插入反馈循环。

### Agent 职责矩阵
| Agent名称 | 核心职责（一句话） | 输入来自 | 输出文件 | 工具权限 | Fork? | 来源建议 |
|----------|----------------|---------|---------|---------|-------|---------|
| topic-planner | 从种子池选取/组合主题，确保 7 个 L1 类目全覆盖，并做附件格式预检（PDF>=20%、Excel>=20%） | 用户输入 N + seeds/topics.yaml + seeds/companies.yaml + attachments_manifest.yaml | workspace/topic-plan.json | Read, Write | no | 原创 |
| question-generator | 基于 topic-plan 和 question_template.md，逐题生成业务背景、核心任务、关键限制、参考依据 | workspace/topic-plan.json + prompts/question_template.md | workspace/questions-batch-N.json | Read, Write, Bash | no | 原创 |
| attachment-matcher | 根据题目内容从 attachments_manifest.yaml 匹配附件，调用 fetch_attachments.py 生成/下载，维护 _index.json 复用索引 | workspace/questions-batch-N.json + attachments_manifest.yaml | workspace/questions-with-attachments.json + workspace/_index.json | Read, Write, Bash | no | 原创 |
| quality-validator | 全量 batch validation：pairwise 同质化检查（相似度、长度、句式、结构）+ 时效性检查 + 附件合规检查 | workspace/questions-with-attachments.json + workspace/_index.json | workspace/validation-report.json | Read, Write, Bash | no | 原创 |
| data-coordinator | 汇总验证通过的题目为标准化 CSV，输出到 output/；对不通过题目触发重试/重写（最多 3 轮），超限标记「需人工审核」 | workspace/validation-report.json + workspace/questions-with-attachments.json | output/questions.csv + output/attachments/ + workspace/final-summary.md | Read, Write, Bash | no | 原创 |

### 协作拓扑
```
用户输入 N
    │
    ▼
┌─────────────────┐
│  topic-planner  │── Read: seeds/*.yaml, attachments_manifest.yaml
│  (主题规划)      │── Write: topic-plan.json
└────────┬────────┘
         │ topic-plan.json
         ▼
┌─────────────────────┐
│  question-generator │── Read: prompts/question_template.md
│  (题目生成)          │── Write: questions-batch-N.json
│                     │── Bash: generate_question.py (parser/兜底)
└────────┬────────────┘
         │ questions-batch-N.json
         ▼
┌─────────────────────┐
│  attachment-matcher │── Read: attachments_manifest.yaml
│  (附件匹配)          │── Write: questions-with-attachments.json
│                     │── Write: _index.json (独占)
│                     │── Bash: fetch_attachments.py
└────────┬────────────┘
         │ questions-with-attachments.json + _index.json
         ▼
┌─────────────────────┐
│  quality-validator  │── Read: questions-with-attachments.json, _index.json
│  (质量验证)          │── Write: validation-report.json
│                     │── Bash: validate.py (batch check)
└────────┬────────────┘
         │ validation-report.json
         ▼
    ┌────────────┐
    │ 全量通过？  │
    └─────┬──────┘
   是 /   \ 否（存在不通过题目）
    ▼       ▼
┌──────────┐   ┌─────────────────────────────────────────────┐
│ data-    │   │  data-coordinator 触发重试循环（最多 3 轮）    │
│ coordinator│   │  ──→ 将不通过题目信息写回 workspace/retry-batch.json │
│ (汇总输出)│   │  ──→ question-generator 读取 retry-batch.json 重写   │
│          │   │  ──→ 重新流经 attachment-matcher → quality-validator │
│ Write:   │   │  ──→ 3 轮后仍不通过 → 标记「需人工审核」并继续       │
│ questions.csv│ └─────────────────────────────────────────────┘
│ attachments/ │
│ final-summary.md│
└──────────┘
```
**拓扑类型**：串行 + 反馈循环（quality-validator → data-coordinator → question-generator 重试）
**并行组**：无（Council 结论明确不引入 Fork/Worktree，流程天然串行）

### Skill 提取清单
| Skill名称 | 触发场景 | 使用它的Agent | 需要辅助脚本 |
|----------|---------|-------------|------------|
| batch-validate | quality-validator 执行全量 pairwise similarity、时效性、附件合规检查 | quality-validator | yes（复用原有 validate.py，封装为 Bash skill 脚本） |
| attachment-fetch | attachment-matcher 调用 fetch_attachments.py 下载/生成附件 | attachment-matcher | yes（复用原有 fetch_attachments.py） |
| csv-export | data-coordinator 将 JSON 汇总为标准化 CSV | data-coordinator | yes（复用原有 generate_question.py 中的 CSV 写入逻辑） |
| topic-pre-check | topic-planner 阶段检查附件格式占比（PDF>=20%、Excel>=20%） | topic-planner | no（纯逻辑判断，无需额外脚本） |

### MCP 需求
| 服务 | 用途 | 使用的 Agent | MCP 包 |
|-----|------|------------|-------|
| 无 | 原有 Python 脚本覆盖全部需求，不引入额外 MCP | — | — |

### Hook 需求（v8.1 新增）
仅使用标准三 hook（安全检查 / 会话摘要 / 文档提醒）。
由于 Profile 为 minimal，仅启用「安全检查」hook；standard/strict 模式下的会话摘要和文档提醒在 minimal 模式下不启用。

### 技术决策说明
1. **串行流水线无 Fork**：Council 结论明确不引入 Fork/Worktree。5 个 agent 的文件操作路径互不重叠（除 data-coordinator 读取上游输出外），天然无写冲突，串行执行足够且逻辑清晰。
2. **_index.json 独占写入**：attachment-matcher 是唯一写入者，data-coordinator 和 quality-validator 只读。这避免了并发写索引的竞态问题，同时让复用计数逻辑集中在单一 agent。
3. **Batch validation 全量执行**：全部题目生成后执行 pairwise similarity，而非逐题验证。这样可以在全局层面发现同质化问题（如 A 像 B、B 像 C），避免局部最优。
4. **重试循环由 data-coordinator 驱动**：不通过题目由 data-coordinator 写回 retry-batch.json，question-generator 读取后重写。重试次数由 data-coordinator 维护（每题独立计数，最多 3 次），超限标记「需人工审核」后继续处理其他题目，不阻塞整体流程。
5. **Python 脚本降级为工具**：原有 `generate_question.py`、`validate.py`、`fetch_attachments.py` 保留为 Bash 可调用的辅助脚本，agent 负责决策和生成，脚本负责确定性操作（如 CSV 格式写入、相似度计算）。

### 共享资源清单（v7 新增）
| 共享文件 | 所有者 Agent（唯一写入者）| 读取者 | 初始化内容模板 |
|---------|---------------------|-------|-------------|
| workspace/_index.json | attachment-matcher | quality-validator, data-coordinator | `{"attachments": [], "reuse_count": {}}` |
| workspace/retry-batch.json | data-coordinator | question-generator | `{"retry_count": {}, "questions": []}` |

### Fork 安全性校验（v7 新增）
所有 agent 的 Fork 标记均为 no，无需 Fork 安全性校验。

### 初始化步骤（v7 新增）
CLAUDE.md 的工作流程开头必须包含的初始化操作：
1. 创建 `.claude/workspace/` 目录
2. 初始化共享资源文件：
   - `workspace/_index.json`：由 attachment-matcher 在首次运行时检查并初始化（若不存在则写入 `{"attachments": [], "reuse_count": {}}`）
   - `workspace/retry-batch.json`：由 data-coordinator 在首次重试时初始化（若不存在则写入 `{"retry_count": {}, "questions": []}`）
3. 创建 `output/` 和 `output/attachments/` 目录（由 data-coordinator 在输出前确保存在）

### 待 Visionary-UX 深化
- [ ] question-generator 的 prompt 模板设计（五层 prompt 精雕：角色层、任务层、约束层、示例层、输出格式层）
- [ ] quality-validator 的验证失败反馈格式（如何清晰告知 question-generator 具体失败原因以便重写）
- [ ] data-coordinator 的重试交互策略（用户是否需要在某题被标记「需人工审核」时收到通知）

### 待 Visionary-Tech 确认
- [ ] batch-validate skill 的具体实现：validate.py 的输入输出接口定义（JSON schema）
- [ ] attachment-fetch skill 的接口：fetch_attachments.py 的参数和返回值格式
- [ ] csv-export skill 的接口：generate_question.py 中 CSV 写入逻辑的封装方式
- [ ] 重试循环的 workspace 文件格式：retry-batch.json 的完整 schema 定义
- [ ] 同质化检查的相似度算法选型（余弦相似度 / Jaccard / 其他）及阈值（<=30%）的实现方式
