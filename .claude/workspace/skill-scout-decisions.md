# Skill Scout 决策表

> 基于 visionary-tech 规格结论：所有核心能力已由原有 Python 脚本覆盖，无需引入外部 skill。
> 本表为实际搜索验证后的最终决策。

---

## batch-validation

| 维度 | 得分 | 说明 |
|-----|------|------|
| 功能匹配度 | 5/40 | skills.sh 上无专门「batch validation」skill。最接近的 `camacho/ai-skills@validate`（529 installs）是通用 AI 输出校验，无 pairwise similarity、同质化检测、时效性锚点等题目工厂特有的验证逻辑 |
| 可适配度 | 5/30 | 通用 validate skill 与 validate.py 的 6 条同质化规则（H1-H6）+ 逐行 10+ 字段检查完全不匹配，适配成本接近重写 |
| 质量评分 | 10/20 | 通用 skill 质量尚可，但功能不相关 |
| 维护活跃度 | 5/10 | `validate` skill 有一定安装量，但非目标领域 |
| **总分** | **25/100** | |

**决策**：不创建（脚本已覆盖）
**来源**：skills.sh / 本地
**操作**：quality-validator agent 直接 Bash 调用 `validate.py <questions-batch.json>` 即可，validate.py 已完整实现 pairwise similarity（difflib.SequenceMatcher + 归一化）、时效性检查、附件合规检查、L1/L2 类目白名单等全部逻辑

---

## attachment-download-indexer

| 维度 | 得分 | 说明 |
|-----|------|------|
| 功能匹配度 | 5/40 | skills.sh 上无「attachment download + index builder」组合 skill。最接近的 `googleworkspace/cli@recipe-save-email-attachments`（14.2K installs）是 Gmail 附件保存，与题目工厂的 topic-based 附件下载（urllib + SSL 降级 + _index.json 维护 + used_in <=2 复用计数）完全不同 |
| 可适配度 | 3/30 | 领域完全不匹配，无法改编 |
| 质量评分 | 10/20 | Gmail skill 本身质量高，但无关 |
| 维护活跃度 | 8/10 | Google Workspace skill 活跃 |
| **总分** | **26/100** | |

**决策**：不创建（脚本已覆盖）
**来源**：skills.sh / 本地
**操作**：attachment-matcher agent 直接 Bash 调用 `fetch_attachments.py --topic <topic_id>`，该脚本已覆盖：单 topic 下载、SSL 降级、超时重试、文件大小校验、`_index.json` 索引维护、`used_in` 复用计数（<=2）

---

## csv-export-formatter

| 维度 | 得分 | 说明 |
|-----|------|------|
| 功能匹配度 | 15/40 | `curiouslearner/devkit@csv-processor`（291 installs）和 `besoeasy/open-skills@json-and-csv-data-transformation`（48 installs）提供通用 JSON/CSV 转换，但题目工厂需要 UTF-8-SIG + BOM（Excel 兼容）、特定字段顺序、附件路径映射、人工审核标记等定制化格式 |
| 可适配度 | 10/30 | 通用 CSV skill 无法满足题目工厂的字段 Schema 和编码要求，需大量改造 |
| 质量评分 | 12/20 | csv-processor 质量中等，但功能偏通用 |
| 维护活跃度 | 6/10 | 有一定安装量，维护一般 |
| **总分** | **43/100** | |

**决策**：不创建（脚本已覆盖）
**来源**：skills.sh / 本地
**操作**：data-coordinator agent 直接调用 `generate_question.py` 内含的 CSV 写入逻辑，或自行用 Python 标准库 `csv` 模块实现（字段顺序、UTF-8-SIG、BOM 已明确）。无需引入外部 skill 增加依赖。

---

## topic-seed-sampling

| 维度 | 得分 | 说明 |
|-----|------|------|
| 功能匹配度 | 0/40 | skills.sh 上无「topic seed sampling」「seed pool」「combination generator」相关 skill。`oaustegard/claude-skills@sampling-bluesky-zeitgeist` 是 Bluesky 社交数据采样，完全无关 |
| 可适配度 | 0/30 | 无候选可适配 |
| 质量评分 | 0/20 | 无候选 |
| 维护活跃度 | 0/10 | 无候选 |
| **总分** | **0/100** | |

**决策**：不创建（脚本已覆盖）
**来源**：skills.sh / 本地
**操作**：topic-planner agent 直接 Bash 调用 `seed_pool.py --n N --prefix auto`，该脚本已完整实现从 seeds/*.yaml 的 (uid, 主体, 领域, 切入) 组合采样，输出 JSON 数组供 topic-plan.json 使用

---

## question-parser

| 维度 | 得分 | 说明 |
|-----|------|------|
| 功能匹配度 | 5/40 | skills.sh 上 parser skill 均为通用文档解析（`doc-parser` 2.2K installs、`pdf-parser` 179 installs、`content-parser` 750 installs），无针对「题目生成」的 XML/JSON/Regex 三模式 parser |
| 可适配度 | 5/30 | 通用文档 parser 与题目工厂的 parse_row（XML/JSON/Regex 三种模式提取题目字段）完全不匹配 |
| 质量评分 | 10/20 | 通用 parser skill 质量尚可 |
| 维护活跃度 | 6/10 | 有一定维护 |
| **总分** | **26/100** | |

**决策**：不创建（脚本已覆盖）
**来源**：skills.sh / 本地
**操作**：question-generator agent 优先自然语言生成题目，格式不标准时 Bash 调用 `generate_question.py --seed '...'` 作为 parser 兜底。generate_question.py 的 parse_row 已覆盖 XML/JSON/Regex 三种模式，无需外部 skill。

---

## 综合结论

| Skill 需求 | 最高分候选 | 得分 | 决策 | 理由 |
|-----------|----------|------|------|------|
| Batch validation | camacho/ai-skills@validate | 25 | 不创建 | validate.py 已覆盖全部验证逻辑（H1-H6 + 逐行检查） |
| Attachment 下载/索引 | googleworkspace/cli@recipe-save-email-attachments | 26 | 不创建 | fetch_attachments.py 已覆盖 topic-based 下载 + 索引维护 |
| CSV 导出格式化 | curiouslearner/devkit@csv-processor | 43 | 不创建 | generate_question.py 内含 CSV 逻辑，或标准库 csv 即可 |
| Topic 种子采样 | 无候选 | 0 | 不创建 | seed_pool.py 已完整实现组合采样 |
| 题目生成 Parser | 无相关候选 | 26 | 不创建 | generate_question.py 的 parse_row 已覆盖三模式 |

**最终决策**：本题工厂团队（题目工厂）的所有核心能力已由原有 Python 脚本（`seed_pool.py`、`generate_question.py`、`validate.py`、`fetch_attachments.py`）完整覆盖，**无需引入任何外部 skill**，也无需创建新 skill。

**agent 调用方式**：各 agent 通过 `Bash` 权限直接调用对应 Python 脚本，脚本路径固定为 `D:/题目工厂/pipeline/*.py`。详见 `phase-2-tech-specs.md` 第 5 节「Python 脚本工具化方案」。
