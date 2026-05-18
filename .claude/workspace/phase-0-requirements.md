# Phase 0 — 需求收集

## Q1: 目标描述
将 D:\题目工厂 的垂域高难度题目数据生产流水线转化为 Agent Team，替代原有 Python 脚本的核心决策、生成、验证、协调环节。底层文件操作（CSV 写入、附件下载）保留为 agent 可调用的工具脚本。

## Q2: 输入
以题目数量为主要输入（如"生成 50 道题"），主题/类目由团队从种子池自动选取。

## Q3: 输出
- **主输出**：标准化 CSV（含 uid、题目、类目、任务概括、专家年限、完成时间、附件清单、产物格式等字段）
- **辅助输出**：附件文件（PDF/Excel/Word 等，5-8 个/题）
- **验证报告**：同质化检查 + 时效性检查 + 附件合规检查
- 输出到 `output/` 目录

## Q4: 核心流程
1. **topic-planner**：从 `seeds/topics.yaml` + `companies.yaml` 选取/组合主题，确保覆盖 7 个一级类目
2. **question-generator**：基于主题和 `prompts/question_template.md` 生成题目正文（含业务背景、核心任务、关键限制、参考依据）
3. **attachment-matcher**：根据题目内容，从 `attachments_manifest.yaml` 匹配或调用工具生成附件，确保每题 5-8 个、每附件最多复用 2 次
4. **quality-validator**：执行同质化检查（相似度≤30%、长度差异、句式多样化）+ 时效性检查 + 附件合规检查
5. **data-coordinator**：汇总为标准化 CSV，输出到 `output/` 目录；验证不通过时触发自动重试/重写

## Q5: 技术需求
- Python 脚本复用：原有 `generate_question.py`、`validate.py`、`fetch_attachments.py` 等保留为 agent 可调用的工具脚本
- 题目生成由 agent 直接完成（自然语言生成），无需硬编码 LLM API 调用
- 文件系统操作：附件存储、CSV 输出需要 Bash/Write 权限
- 种子/配置读取：`seeds/`、`prompts/`、`*.yaml` 等配置文件

## Q6: 质量要求
- 题目需经同质化检查（相似度、长度、句式、结构）
- 附件名称与内容对应，格式合规
- 时效性：出现"当前/最新"必须补充时间点
- 每题 5-8 个附件，每附件最多复用 2 次
- 验证不通过时自动重试/重写，无需人工审核

## Q7: 团队规模偏好
5 个 agent（标准型），与原有流水线模块一一对应：
topic-planner, question-generator, attachment-matcher, quality-validator, data-coordinator

## Q8: 运行时 Profile
minimal（仅基础安全检查，适合个人项目和快速原型）

## 关键约束
- 完全基于 D:\题目工厂 现有逻辑和文件进行设计
- Agent 负责思考/决策/生成/审查，Python 脚本降级为工具/胶水代码
