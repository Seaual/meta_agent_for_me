# Agent Scout 决策表 — question-generator

## 搜索结果摘要

| 目标 Agent | VoltAgent 搜索 | agency-agents 搜索 | 决策 |
|-----------|---------------|-------------------|------|
| **pdf-reader** | 无匹配 | 无匹配 | 原创 |
| **question-generator** | 无匹配 | 无匹配 | 原创 |
| **quality-reviewer** | code-reviewer 可参考 | engineering-code-reviewer 可参考 | 改编 |
| **word-exporter** | 无匹配 | 无匹配 | 原创 |

---

## 详细决策

### pdf-reader
- **决策**：原创
- **理由**：未找到专门的 PDF 解析 agent。Claude 内置 PDF 读取能力，需要设计一个针对"文档结构分析 + 章节索引 + 重点提取"的专业 agent。
- **候选文件**：无
- **评分**：N/A（原创）

### question-generator
- **决策**：原创
- **理由**：未找到专门的题目生成 agent。这是本 Team 的核心功能，需要从零设计，支持三种题型生成和 Subagent 委派逻辑。
- **候选文件**：无
- **评分**：N/A（原创）

### quality-reviewer
- **决策**：改编（参考 code-reviewer）
- **理由**：VoltAgent 的 code-reviewer 具有审查框架，可改编为题目质量审查。需调整：
  - 将"代码审查"改为"题目审查"
  - 将"安全漏洞"改为"答案准确性"
  - 将"性能分析"改为"解析合理性"
- **候选文件**：`awesome-claude-code-subagents/categories/04-quality-security/code-reviewer.md`
- **评分**：72/100（需较大改编）

### word-exporter
- **决策**：原创
- **理由**：未找到专门的文档导出 agent。需要设计一个简单的 pandoc 封装 agent，处理安装检测和错误降级。
- **候选文件**：无
- **评分**：N/A（原创）

---

## 最终统计

| 来源 | 数量 | Agent 列表 |
|------|------|-----------|
| **原创** | 3 | pdf-reader, question-generator, word-exporter |
| **改编** | 1 | quality-reviewer（参考 code-reviewer）|
| **复用** | 0 | — |

**总计**：4 个 agent