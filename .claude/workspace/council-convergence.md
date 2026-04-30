# Council Convergence — question-generator

## 收敛规则应用

**规则 1 — 三方共识 → 直接采纳**

所有关键议题均达成三方共识，无需启用规则 2-4。

---

## 最终决策

### 1. Team 规格

| 项目 | 决策 |
|------|------|
| **Team 名称** | question-generator |
| **Agent 数量** | 4 个 |
| **协作模式** | 串行 |
| **Self-improving** | 启用 |
| **Instincts** | 启用 |
| **Profile** | minimal |

### 2. Agent 职责矩阵

| Agent | 核心职责 | 输入 | 输出 | 工具权限 |
|-------|---------|------|------|---------|
| **pdf-reader** | 读取并解析 PDF，提取结构化内容 | `input/*.pdf` | PDF 内容摘要 | Read |
| **question-generator** | 根据内容生成三种题型 | PDF 内容 + 用户指令 | `questions.md` | Read, Write |
| **quality-reviewer** | 审查题目质量，验证答案准确性 | `questions.md` + PDF 内容 | 审查报告 / 修正后文件 | Read, Write |
| **word-exporter** | 将 Markdown 导出为 Word | `questions.md` | `questions.docx` | Read, Bash |

### 3. 技术选型

| 功能 | 方案 | 理由 |
|------|------|------|
| **PDF 解析** | Claude 内置 PDF 读取 | 无需额外依赖，直接支持 |
| **Word 导出** | pandoc | 跨平台、成熟稳定、格式保留好 |

### 4. 协作拓扑

```
input/*.pdf
    │
    ▼
┌─────────────────┐
│   pdf-reader    │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│question-generator│ ← 用户指令（题目类型、数量）
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ quality-reviewer│
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  word-exporter  │ ← 可选（用户确认后执行）
└─────────────────┘
    │
    ▼
output/questions.md
output/questions.docx
```

### 5. 输出格式

Markdown 文件结构：
- 一、单选题（N 道）
- 二、多选题（M 道）
- 三、判断题（K 道）
- 每道题含：题目、选项、答案、解析

### 6. 边界条件处理

| 场景 | 处理方式 |
|------|---------|
| PDF 不存在 | 提示用户放入 input 目录 |
| PDF 内容为空 | 提示检查文件有效性 |
| 未指定题目数量 | 默认每种类型 3 道 |
| pandoc 未安装 | 提示安装或跳过 Word 导出 |

### 7. 质量保障措施

1. **quality-reviewer** 必须对比 PDF 原文验证答案
2. **self-improving** 记录错误类型，持续优化
3. 用户最终确认机制

---

## 风险摘要

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| AI 生成题目可能有事实错误 | 高 | quality-reviewer 验证 + 用户确认 |
| pandoc 未安装导致无法导出 | 中 | 检测并提示安装，提供降级方案 |
| PDF 过大导致解析不完整 | 低 | 分页处理 |

---

## 后续步骤

用户确认后，进入 Phase 2 架构设计（visionary-arch）。