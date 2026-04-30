# Strategic Analysis — question-generator

## 1. 价值主张

**核心价值**：降低招聘/培训场景下的出题成本，提升知识检验效率。

| 利益相关者 | 价值 |
|-----------|------|
| **HR/培训人员** | 快速生成考核题目，节省 80% 出题时间 |
| **考生** | 题目紧扣资料内容，复习更有针对性 |
| **组织** | 标准化考核流程，确保公平性 |

## 2. 成功边界

### In Scope（必做）
- 读取本地 PDF 文件
- 生成单选题/多选题/判断题
- 输出 Markdown 格式（含答案+解析）
- Word 导出功能
- 用户动态指定题目数量

### Out of Scope（不做）
- 在线题库系统
- 自动评分/阅卷
- 多用户管理
- 网络下载 PDF

### Future Extensions（扩展路线）
- 支持更多题型（填空、简答）
- 题目难度分级
- 题库管理（去重、分类）
- Excel 导出

## 3. Agent 角色建议

| Agent | 职责 | 理由 |
|-------|------|------|
| **pdf-reader** | 解析 PDF，提取结构化内容 | 单一职责，可复用 |
| **question-generator** | 综合生成三种题型 | 核心价值交付点 |
| **word-exporter** | Markdown → Word 转换 | 独立功能，可选依赖 |
| **quality-reviewer** | 审查题目质量（答案准确性、选项合理性）| 保障输出质量 |

**建议规模**：4 个 agent

## 4. 协作模式

**推荐**：串行 + 可选并行

```
pdf-reader → question-generator → quality-reviewer → word-exporter
                   ↓
            (用户确认后)
                   ↓
            word-exporter
```

Word 导出作为可选步骤，用户确认题目后再执行。

## 5. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| PDF 解析失败 | 无法出题 | 支持常见格式，提供错误提示 |
| 题目质量不稳定 | 用户不满意 | quality-reviewer 审查 + self-improving 持续优化 |
| Word 导出格式问题 | 输出不可用 | 使用成熟转换工具（pandoc）|

## 6. 关键决策

1. **PDF 解析方式**：使用 AI 直接读取 PDF 内容（Claude 支持读取 PDF）
2. **Word 导出方案**：pandoc 命令行工具（跨平台、成熟稳定）
3. **Self-improving 落地**：记录每次生成的题目类型、用户反馈，提炼出题模式