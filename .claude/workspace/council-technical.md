# Technical Analysis — question-generator

## 1. 技术架构

### 数据流

```
input/*.pdf
    │
    ▼
┌─────────────────┐
│   pdf-reader    │ → 提取文本内容
└─────────────────┘
    │
    ▼
┌─────────────────┐
│question-generator│ → 生成题目(单选/多选/判断)
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ quality-reviewer│ → 审查质量
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  word-exporter  │ → 导出 Word
└─────────────────┘
    │
    ▼
output/questions.md
output/questions.docx
```

## 2. Agent 职责矩阵

| Agent | 核心职责 | 输入 | 输出 | 工具权限 |
|-------|---------|------|------|---------|
| **pdf-reader** | 读取并解析 PDF | input/*.pdf | 结构化内容 | Read |
| **question-generator** | 生成三种题型 | 结构化内容 + 用户指令 | questions.md | Read, Write |
| **quality-reviewer** | 审查题目质量 | questions.md + PDF 内容 | 审查报告 / 修正后文件 | Read, Write |
| **word-exporter** | 导出 Word | questions.md | questions.docx | Read, Bash(pandoc) |

## 3. 技术选型

### PDF 解析

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| **Claude 内置 PDF 读取** | 无需额外工具，直接支持 | 大文件可能受限 | ✅ 首选 |
| pdfplumber (Python) | 精确控制，支持表格 | 需要安装依赖 | 备选 |
| PyMuPDF | 速度快 | 依赖复杂 | 备选 |

### Word 导出

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| **pandoc** | 跨平台、成熟、格式保留好 | 需要用户安装 | ✅ 首选 |
| python-docx | 纯 Python | 格式转换复杂 | 备选 |
| mammoth.js | Node.js 生态 | 单向转换 | 不推荐 |

**pandoc 安装检测**：word-exporter 启动时检查 pandoc 是否可用，不可用则提示用户安装或跳过导出。

## 4. 输出格式规范

### Markdown 模板

```markdown
# 题目练习

## 一、单选题

### 1. [题目内容]
A. [选项A]
B. [选项B]
C. [选项C]
D. [选项D]

**答案**：X

**解析**：[答案理由]

---

## 二、多选题

### 1. [题目内容]
A. [选项A]
B. [选项B]
C. [选项C]
D. [选项D]

**答案**：X, Y

**解析**：[答案理由]

---

## 三、判断题

### 1. [题目内容]

**答案**：正确 / 错误

**解析**：[答案理由]

---
```

## 5. Self-Improving 实现

### .learnings/ 结构（两层）

```
.learnings/
├── README.md
├── entries/
│   ├── LRN-001.json  # 成功经验
│   └── ERR-001.json  # 错误记录
└── instincts/
    └── INSTINCT-001.json  # 提炼的出题模式
```

### 记录内容

| 类型 | 示例 |
|------|------|
| 成功经验 | "调度员考试重点在'应急处置'章节" |
| 错误记录 | "多选题答案不能全选，违反出题规范" |
| Instinct | "招聘资料优先考查数字、时间、流程类知识点" |

## 6. 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| pandoc 未安装 | 无法导出 Word | 检测并提示安装，提供降级方案 |
| PDF 过大导致 context 溢出 | 解析不完整 | 分页处理 + 摘要 |
| 题目格式不一致 | Word 导出格式混乱 | 严格 Markdown 模板 |

## 7. 关键决策

1. **使用 Claude 内置 PDF 读取**：无需额外依赖，简化架构
2. **pandoc 作为 Word 导出方案**：成熟稳定，跨平台
3. **quality-reviewer 必须引用 PDF 原文验证**：确保答案准确性

## 8. Agent 数量建议

**推荐**：4 个 agent

不需要第 5 个 agent。需求明确、边界清晰，4 个 agent 已足够。