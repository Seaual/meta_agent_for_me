## 🔧 Visionary-Tech 规格

**基于**：phase-1-architecture.md + council-convergence.md + phase-0-requirements.md
**负责范围**：工具权限 + Skill/MCP + Workspace 协议 + Python 脚本工具化 + Hook 配置
**Profile**：minimal（仅安全检查 hook）
**Self-Improving**：不启用
**Fork/Worktree**：不引入

---

## 1. 工具权限分配

| Agent | allowed-tools | Bash 使用场景（必须明确） |
|-------|-------------|------------------------|
| topic-planner | Read, Write | — |
| question-generator | Read, Write, Bash | 调用 `seed_pool.py --n N --prefix auto` 生成种子组合；调用 `generate_question.py --seed '{...}'` 作为 parser/兜底（当 agent 自然语言生成的题目格式不标准时） |
| attachment-matcher | Read, Write, Bash | 调用 `fetch_attachments.py --topic <topic_id>` 下载/复用附件；维护 `_index.json` 复用计数 |
| quality-validator | Read, Write, Bash | 调用 `validate.py <questions-batch.json>` 执行全量 batch validation（pairwise similarity + 时效性 + 附件合规） |
| data-coordinator | Read, Write, Bash | 调用 Python 脚本将 JSON 汇总为标准化 CSV；创建 output/attachments/ 目录；复制附件到输出目录 |

### Bash 权限细化说明

- **question-generator**：Bash 仅用于调用 `seed_pool.py`（确定性采样）和 `generate_question.py`（parser 兜底）。不用于网络请求、不用于文件删除。
- **attachment-matcher**：Bash 仅用于调用 `fetch_attachments.py`（带 `--topic` 参数的单 topic 下载）。该脚本内部已做 SSL 降级、超时、重试、文件大小校验，agent 不直接执行 `curl`/`wget`。
- **quality-validator**：Bash 仅用于调用 `validate.py <json文件路径>`。validate.py 是纯本地计算（无网络），agent 不自行实现相似度算法。
- **data-coordinator**：Bash 用于调用 `generate_question.py`（如需重写时 parser 兜底）、文件复制（`cp`/`copy`）、目录创建。不执行 `rm -rf`。

---

## 2. Skill 需求 + 搜索提示（供 Library Scout 使用）

| 需求描述 | 搜索关键词（英文） | 使用的 Agent | 备注 |
|---------|------------------|------------|------|
| Batch validation 执行 | batch validate, data validation, quality check | quality-validator | **可能不需要独立 skill**，validate.py 已覆盖全部逻辑，agent 直接 Bash 调用即可 |
| Attachment 下载/索引 | attachment download, file fetch, index builder | attachment-matcher | **可能不需要独立 skill**，fetch_attachments.py 已覆盖全部逻辑 |
| CSV 导出格式化 | csv export, json to csv, data conversion | data-coordinator | **可能不需要独立 skill**，generate_question.py 内含 CSV 写入逻辑，data-coordinator 可直接调用或参考实现 |
| Topic 种子采样 | seed pool, topic sampling, combination generator | topic-planner | **不需要独立 skill**，seed_pool.py 已完整实现 |
| 题目生成 Parser | text parser, xml parser, json parser, regex extraction | question-generator | **不需要独立 skill**，generate_question.py 的 parse_row 已覆盖 XML/JSON/Regex 三种模式 |

**结论**：本题工厂团队的所有核心能力已由原有 Python 脚本覆盖，**无需引入外部 skill**。agent 通过 Bash 调用脚本即可。若未来需复用，可将脚本封装为 skill（路径 A：改编现有脚本为 SKILL.md + 脚本目录）。

---

## 3. Agent 搜索提示（供 Library Scout 使用）

| 目标 Agent | 搜索关键词（英文） | 期望的核心能力 |
|-----------|------------------|--------------|
| topic-planner | topic planner, content planner, seed selector, category coverage | 从种子池选取主题，确保类目全覆盖 |
| question-generator | question generator, exam item generator, prompt engineer, content generator | 基于模板生成结构化题目内容 |
| attachment-matcher | attachment matcher, file matcher, resource allocator, index manager | 匹配附件，维护复用索引 |
| quality-validator | quality validator, content validator, similarity checker, homogeneity detector | 同质化检查、合规检查、批量验证 |
| data-coordinator | data coordinator, pipeline coordinator, csv exporter, retry handler | 汇总输出、重试循环、人工审核标记 |

**结论**：5 个 agent 均为原创设计，无现成 agent 可直接复用（题目工厂是垂直领域专用流水线）。

---

## 4. MCP 集成配置

**决策：不引入额外 MCP**

理由：
1. 原有 Python 脚本（generate_question.py、validate.py、fetch_attachments.py、seed_pool.py）覆盖全部需求
2. 题目生成由 agent 直接完成自然语言生成，无需调用外部 LLM API（generate_question.py 的 API 调用仅作为 parser 兜底）
3. 附件下载通过 fetch_attachments.py 完成（urllib + SSL 降级），无需文件系统 MCP
4. 不引入 MCP 减少依赖和配置复杂度，符合 minimal Profile

`.claude/settings.json` 配置段：
```json
{
  "mcpServers": {}
}
```

| MCP | 使用的 Agent | 需要的 Token | 获取方式 |
|-----|------------|------------|---------|
| — | — | — | — |

---

## 5. Python 脚本工具化方案

原有脚本保留在 `D:/题目工厂/pipeline/` 目录下，agent 通过 Bash 调用。接口定义如下：

### 5.1 `seed_pool.py` — 种子采样工具

**调用接口**：
```bash
py -3 D:/题目工厂/pipeline/seed_pool.py --n <N> --prefix <batch_prefix> --rng <seed>
```

| 参数 | 说明 | 示例 |
|-----|------|------|
| `--n` | 采样数量 | `--n 50` |
| `--prefix` | UID 前缀 | `--prefix auto` |
| `--rng` | 随机种子（可选，用于 reproducible） | `--rng 42` |
| `--no-log` | 不写入 used_seeds.txt（调试用） | `--no-log` |

**输出**：stdout JSON 数组，每个元素为 `{"uid": "...", "主体": "...", "领域": "...", "切入": "...", "_hash": "..."}`

**调用方**：topic-planner（生成 topic-plan.json 时读取 seed_pool 输出）

**工具化封装**（供 agent 使用）：
```bash
# topic-planner 在规划阶段调用
SEEDS=$(py -3 D:/题目工厂/pipeline/seed_pool.py --n 50 --prefix auto)
# 将 SEEDS 写入 topic-plan.json 的 seeds 字段
```

### 5.2 `generate_question.py` — 题目生成 + Parser 兜底

**调用接口**：
```bash
py -3 D:/题目工厂/pipeline/generate_question.py --seed '<JSON_STRING>' --model claude-sonnet-4-6 --temperature 0.85
```

| 参数 | 说明 | 示例 |
|-----|------|------|
| `--seed` | JSON 格式的种子数据（必须单引号包裹） | `--seed '{"uid":"auto_001","主体":"比亚迪","领域":"...","切入":"..."}'` |
| `--model` | 模型名称（可选） | `--model claude-sonnet-4-6` |
| `--temperature` | 温度（可选） | `--temperature 0.85` |

**输出**：stdout JSON 单条题目记录

**调用方**：
- **question-generator**：当 agent 自然语言生成的题目格式不标准时，调用此脚本作为 parser 兜底；或当需要基于种子重新生成时调用
- **data-coordinator**：重试循环中，将 retry-batch.json 中的种子传给此脚本重新生成

**注意**：agent 优先直接自然语言生成题目内容，仅在格式解析失败或需要严格遵循模板时调用此脚本。

### 5.3 `validate.py` — 逐行 + 批量验证工具

**调用接口**：
```bash
py -3 D:/题目工厂/pipeline/validate.py <rows.json>
```

| 参数 | 说明 | 示例 |
|-----|------|------|
| `<rows.json>` | JSON 文件路径（数组或单对象） | `validate.py workspace/questions-batch-50.json` |

**输出**：stderr/stdout 人类可读报告 + exit code（0=通过，1=失败）

**调用方**：quality-validator（全量 batch validation）

**工具化封装**：
```bash
# quality-validator 执行批量验证
py -3 D:/题目工厂/pipeline/validate.py .claude/workspace/questions-with-attachments.json > .claude/workspace/validation-report.txt
# 然后将 validation-report.txt 解析为 validation-report.json
```

**validate.py 内部算法说明**（供 quality-validator agent 理解）：
- **逐行检查**：必填字段、L1 类目白名单、标题长度 300-1800、任务编号 >=2 条、附件编号格式、无《》无 URL、附件数量 5-8、产物描述无裸扩展名、时效锚点、人类时间 >=8h
- **批量检查（同质化）**：
  - H1: pairwise normalized similarity >=70% 的 pair 比例 <30%（使用 `difflib.SequenceMatcher`，归一化方式：数字→N，字母→X，去空格）
  - H2: 80% 标题长度差异 <10% → 警告
  - H3: >=50% 相同开头 40 字符 → 警告
  - H4: >=50% 相同结构 hash → 拒收（结构 hash = 归一化后前 200 字符的 MD5）
  - H5: >5% 落入同一范式 (L1+L2+开头20字符) → 警告
  - H6: 附件复用 >2 次 → 警告

### 5.4 `fetch_attachments.py` — 附件下载 + 索引维护工具

**调用接口**：
```bash
py -3 D:/题目工厂/pipeline/fetch_attachments.py [--topic <topic_id>] [--dry-run] [--force]
```

| 参数 | 说明 | 示例 |
|-----|------|------|
| `--topic` | 仅下载指定 topic（agent 调用时必须指定） | `--topic T01_byd_equity` |
| `--dry-run` | 仅显示会下载什么，不实际下载 | `--dry-run` |
| `--force` | 强制重新下载（即使文件已存在） | `--force` |

**输出**：stdout 下载日志 + 更新 `attachments/_index.json`

**调用方**：attachment-matcher

**工具化封装**：
```bash
# attachment-matcher 为每道题目调用
py -3 D:/题目工厂/pipeline/fetch_attachments.py --topic T01_byd_equity
# 然后读取 attachments/_index.json 获取可用文件列表
```

**索引文件格式**：`attachments/_index.json`
```json
{
  "files": [
    {
      "filename": "...",
      "path": "attachments/T01_byd_equity/...",
      "topic_id": "T01_byd_equity",
      "l1": "...",
      "fmt": "PDF",
      "size_mb": 8.2,
      "md5": "...",
      "url": "...",
      "content_summary": "...",
      "used_in": ["uid1", "uid2"],
      "fetched_at": "2026-05-16T19:30:00"
    }
  ]
}
```

**重要**：`used_in` 数组长度 <=2（每附件最多复用 2 次）。attachment-matcher 在匹配时需检查此约束。

---

## 6. Workspace 文件协议

### 6.1 中间文件完整 Schema

| 文件 | 写入者 | 读取者 | 格式说明 |
|-----|-------|-------|---------|
| `topic-plan.json` | topic-planner | question-generator | JSON: `{"n": 50, "seeds": [...], "l1_coverage": {...}, "attachment_format_check": {"pdf_pct": 0.25, "excel_pct": 0.25}}` |
| `questions-batch-N.json` | question-generator | attachment-matcher | JSON 数组，每元素为完整题目记录（含 uid、题目、类目、附件清单等） |
| `questions-with-attachments.json` | attachment-matcher | quality-validator, data-coordinator | JSON 数组，每元素增加 `attachment_entries` 字段（指向 _index.json 中的文件条目） |
| `_index.json` | attachment-matcher（独占写入） | quality-validator, data-coordinator | 附件索引，见 5.4 节格式 |
| `validation-report.json` | quality-validator | data-coordinator | JSON: `{"total": 50, "passed": 48, "failed_uids": [...], "retry_needed": [...], "details": [...]}` |
| `retry-batch.json` | data-coordinator | question-generator | JSON: `{"retry_count": {"uid1": 1, "uid2": 2}, "questions": [...]}` |
| `final-summary.md` | data-coordinator | director-council | Markdown: 生产摘要、通过率、重试统计、需人工审核列表 |
| `output/questions.csv` | data-coordinator | 用户 | 标准化 CSV（UTF-8-SIG，含 BOM，Excel 兼容） |
| `output/attachments/` | data-coordinator | 用户 | 附件文件目录，按 uid 子目录组织 |

### 6.2 文件读写权限矩阵

| 文件 | topic-planner | question-generator | attachment-matcher | quality-validator | data-coordinator |
|-----|:-----------:|:----------------:|:----------------:|:---------------:|:--------------:|
| `topic-plan.json` | **W** | R | — | — | — |
| `questions-batch-N.json` | — | **W** | R | — | R（重试时） |
| `questions-with-attachments.json` | — | — | **W** | R | R |
| `_index.json` | — | — | **W** | R | R |
| `validation-report.json` | — | — | — | **W** | R |
| `retry-batch.json` | — | R | — | — | **W** |
| `final-summary.md` | — | — | — | — | **W** |
| `output/questions.csv` | — | — | — | — | **W** |
| `output/attachments/` | — | — | — | — | **W** |
| `seeds/*.yaml` | R | R | R | — | — |
| `prompts/*.md` | R | R | — | — | — |
| `attachments_manifest.yaml` | R | — | R | — | — |

### 6.3 错误标记文件规范

| 文件 | 触发条件 | 内容格式 |
|-----|---------|---------|
| `[agent-name]-error.md` | agent 执行失败 | `# Error Report\n## Agent: [name]\n## Time: [ISO]\n## Phase: [phase]\n## Error: [描述]\n## Recovery: [建议]` |
| `validation-report.json` 中 `failed_uids` | 验证不通过 | 包含 `uid` + `errors` 数组 + `retry_count` |
| `retry-batch.json` 中超限题目 | 重试 3 次仍不通过 | `status: "needs_manual_review"`，data-coordinator 在 final-summary.md 中汇总 |

---

## 7. 传递顺序

```
用户输入 N
    │
    ▼
topic-planner ──Write──► topic-plan.json
    │
    ▼
question-generator ──Write──► questions-batch-N.json
    │
    ▼
attachment-matcher ──Write──► questions-with-attachments.json
         │                    _index.json（独占更新）
         ▼
quality-validator ──Write──► validation-report.json
    │
    ├── 全量通过 ──► data-coordinator ──Write──► output/questions.csv + output/attachments/ + final-summary.md
    │
    └── 部分不通过 ──► data-coordinator ──Write──► retry-batch.json
                              │
                              ▼
                    question-generator ──Read──► retry-batch.json
                              │
                              └── 重写后重新流经 attachment-matcher → quality-validator
                              （最多 3 轮，超限标记「需人工审核」）
```

---

## 8. Hook 配置（Profile = minimal）

**标准 hook 脚本**：仅启用 `pre-tool-safety.js`（安全检查）

**自定义 hook**：无（minimal Profile 不启用会话摘要和文档提醒）

`.claude/settings.json` hooks 配置段：
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "node scripts/hooks/pre-tool-safety.js",
        "timeout": 5
      }]
    }]
  }
}
```

| 脚本 | 事件 | Matcher | Profile | 实现要点 |
|------|------|---------|---------|---------|
| `pre-tool-safety.js` | PreToolUse | Bash | minimal+ | 阻止 `rm -rf /`、硬编码凭证、`eval` 注入、未验证的变量删除。exit 2 阻止执行，exit 0 放行。 |

**pre-tool-safety.js 实现要点**（供 toolsmith-infra 生成）：
1. 从 stdin 读取 JSON 输入（含 tool 名称、参数）
2. 若 tool 为 Bash：
   - 检查命令是否包含 `rm -rf /` 或 `rm -rf $VAR`（变量未加引号）
   - 检查是否包含 `eval(` 或 `eval "`
   - 检查是否包含硬编码密钥（`api_key=`、`password=`、`token=` 后跟非环境变量值）
   - 检查是否包含 `>` 重定向到系统目录
3. 命中任一规则 → stdout `{"allowed": false, "reason": "..."}`，exit 2
4. 未命中 → stdout `{"allowed": true}`，exit 0

---

## 9. 关键技术决策

### 9.1 相似度算法选型及理由

**选用**：`difflib.SequenceMatcher` + 归一化预处理（数字→N，字母→X，去空格）

**理由**：
1. **已有实现**：validate.py 已完整实现此算法，无需引入新依赖（如 scikit-learn、sentence-transformers）
2. **轻量高效**：纯标准库，无需下载模型，适合 batch  pairwise 比较（O(n²) 但 n<=50 可接受）
3. **归一化策略合理**：数字和字母替换为占位符后，比较的是「结构模板」而非具体内容，恰好匹配「同质化」检测目标（发现"2026年X月，某Y公司..."这类模板重复）
4. **阈值已校准**：ratio >= 0.7（70% 归一化相似度）≈ "仅关键词替换"，与 spec 要求的 <=30% pair 比例匹配

**不选用的方案**：
- 余弦相似度（需要分词 + 词向量，引入额外依赖，对中文短文本效果不一定更好）
- Jaccard（对语序不敏感，不适合检测"同一模板换词"的情况）
- Embedding 相似度（需要模型，不符合 minimal Profile 的轻量原则）

### 9.2 重试状态持久化方案

**方案**：`retry-batch.json` 文件持久化

**Schema**：
```json
{
  "retry_count": {
    "auto_001": 1,
    "auto_002": 3
  },
  "questions": [
    {
      "uid": "auto_001",
      "seed": {"主体": "...", "领域": "...", "切入": "..."},
      "last_errors": ["title too short", "missing time anchor"],
      "status": "retrying"
    }
  ],
  "manual_review": [
    {
      "uid": "auto_002",
      "retry_count": 3,
      "last_errors": ["..."],
      "status": "needs_manual_review"
    }
  ]
}
```

**持久化逻辑**：
1. data-coordinator 在检测到验证失败时，读取现有 `retry-batch.json`（若不存在则初始化）
2. 更新对应 uid 的 `retry_count`（+1）
3. 若 `retry_count[uid] >= 3`，移入 `manual_review` 数组，不再重试
4. 将需要重试的题目写入 `questions` 数组
5. question-generator 读取 `retry-batch.json`，仅处理 `status: retrying` 的题目
6. 重写完成后，删除已处理的条目（或标记为 `status: done`）

**状态机**：
```
generated → validated → passed → output
                │
                └─failed─► retrying (count+1) ──► regenerated ──► validated
                                    │
                                    └─count>=3─► needs_manual_review
```

### 9.3 批次处理策略（当 N 很大时）

**当前设计**：N 由用户输入（如 50 题），全部生成后再 batch validation

**若 N 很大（如 >100）的优化策略**（预留，当前不实现）：
1. **分片生成**：topic-planner 将 N 拆分为多个子批次（如每批 50 题），每批独立走完整流水线
2. **增量验证**：每生成一批立即验证，不堆积到最后
3. **跨批同质化检查**：最终合并所有批次做一次全局 pairwise check（防止 batch A 的题目和 batch B 的题目同质化）
4. **附件复用全局检查**：跨批次检查附件 used_in 不超过 2 次

**当前约束**：N <= 50 时无需分片，单批次全量处理即可。

---

## 10. 辅助脚本需求

| 脚本 | 用途 | 调用方 |
|-----|------|-------|
| `seed_pool.py` | 从 seeds/*.yaml 采样 (uid, 主体, 领域, 切入) 组合 | topic-planner / question-generator |
| `generate_question.py` | 基于种子生成单条题目（含 parser 兜底） | question-generator / data-coordinator（重试时） |
| `validate.py` | 逐行 + 批量验证（同质化、时效性、附件合规） | quality-validator |
| `fetch_attachments.py` | 按 topic 下载附件，维护 _index.json | attachment-matcher |
| `pre-tool-safety.js` | Bash 命令安全检查 hook | Claude Code harness |

---

## 11. 与 Visionary-UX 的注意点

1. **question-generator 的 prompt 模板**：UX 设计的五层 prompt（角色层、任务层、约束层、示例层、输出格式层）需要与 `prompts/question_template.md` 的现有结构兼容。现有模板已包含 SYSTEM、硬性要求、题目骨架、同质化雷区、OUTPUT FORMAT 五部分，UX 可在此基础上精雕。

2. **validate.py 的反馈格式**：UX 需要设计 quality-validator 的验证失败反馈格式，以便 question-generator 在重试时明确知道如何修改。建议格式：`{"uid": "...", "errors": ["字段级错误"], "batch_issues": ["同质化问题描述"], "suggestions": ["重写建议"]}`

3. **data-coordinator 的重试交互**：UX 需决定当题目被标记「需人工审核」时，是否在 final-summary.md 中高亮显示，并给出具体失败原因和原始题目内容，方便用户人工介入。

4. **attachment-matcher 的匹配逻辑**：UX 需明确 attachment-matcher 如何从题目内容匹配到 attachments_manifest.yaml 中的 topic。当前逻辑是：seed 中的 "主体" 和 "切入" 对应 manifest 中的 `subject` 和 `cut_in`，agent 需要理解此映射关系。

---

## 12. 初始化检查清单（供 toolsmith-infra 使用）

CLAUDE.md 工作流程开头必须包含：

1. 创建 `.claude/workspace/` 目录
2. 确认 `D:/题目工厂/` 目录存在且包含：
   - `seeds/topics.yaml`
   - `seeds/companies.yaml`
   - `seeds/attachments_manifest.yaml`
   - `prompts/question_template.md`
   - `pipeline/*.py`
3. `attachments/_index.json` 由 attachment-matcher 在首次运行时检查并初始化（若不存在则写入 `{"files": []}`）
4. `output/` 和 `output/attachments/` 目录由 data-coordinator 在输出前确保存在
5. `retry-batch.json` 由 data-coordinator 在首次重试时初始化（若不存在则写入 `{"retry_count": {}, "questions": [], "manual_review": []}`）

---

*Visionary-Tech 完成。等待 Visionary-UX 完成后，Director Council 汇总。*
