# Phase 1 架构方案 — question-generator（最终版）

## 系统边界

| 项目 | 说明 |
|------|------|
| **触发条件** | 用户上传 PDF 到 `input/` 目录，并请求生成题目 |
| **输入** | `input/` 目录下的 PDF 文件（支持扫描识别）|
| **输出** | `output/questions.md`（Markdown 题目文件）、`output/questions.docx`（Word 导出，可选）|
| **外部依赖** | pandoc（Word 导出，需用户安装）|

---

## 分解策略

**选用**：按职能分解 + Subagent 按需并行

**理由**：
- 四个核心职能清晰：PDF 解析、题目生成、质量审查、导出
- 通过 Subagent 委派实现按需并行，架构简洁灵活
- 题目多时自动并行，题目少时串行处理

---

## Agent 职责矩阵

| Agent 名称 | 核心职责 | 输入来自 | 输出文件 | 工具权限 | Fork? | Subagent? |
|-----------|---------|---------|---------|---------|-------|----------|
| **pdf-reader** | 读取 PDF，分析结构，提取重点内容 | `input/*.pdf` | `workspace/pdf-content.md` | Read | no | no |
| **question-generator** | 生成三种题型（可委派 subagent 并行）| `pdf-content.md` + 用户指令 | `workspace/questions.md` | Read, Write | no | yes |
| **quality-reviewer** | 审查题目质量（可委派 subagent 并行）| `questions.md` + `pdf-content.md` | 修正后 `questions.md` | Read, Write | no | yes |
| **word-exporter** | 合并题目 + 导出 Word | `questions.md` | `questions.docx` | Read, Bash | no | no |

**Agent 总数**：4 个

---

## Subagent 委派机制

### question-generator 的 Subagent

| Subagent | 触发条件 | 职责 |
|----------|---------|------|
| **single-choice-agent** | 用户请求单选题 或 题目总数 > 10 | 生成单选题 |
| **multi-choice-agent** | 用户请求多选题 或 题目总数 > 10 | 生成多选题 |
| **judgment-agent** | 用户请求判断题 或 题目总数 > 10 | 生成判断题 |

**委派策略**：
- 题目总数 ≤ 10：主 agent 直接生成全部题目
- 题目总数 > 10：委派 3 个 subagent 并行生成，主 agent 汇总

### quality-reviewer 的 Subagent

| Subagent | 触发条件 | 职责 |
|----------|---------|------|
| **single-review-agent** | 单选题 > 10 道 | 审查单选题 |
| **multi-review-agent** | 多选题 > 10 道 | 审查多选题 |
| **judgment-review-agent** | 判断题 > 10 道 | 审查判断题 |

**委派策略**：
- 某类题目 ≤ 10：主 agent 直接审查
- 某类题目 > 10：委派对应 subagent 审查

---

## 协作拓扑

### 简单模式（题目少时）

```
input/*.pdf
    │
    ▼
┌─────────────────┐
│   pdf-reader    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│question-generator│ ← 直接生成全部题目
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ quality-reviewer│ ← 直接审查全部题目
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  word-exporter  │
└────────┬────────┘
         │
         ▼
output/questions.md
output/questions.docx
```

### 并行模式（题目多时）

```
input/*.pdf
    │
    ▼
┌─────────────────┐
│   pdf-reader    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│              question-generator                      │
│  ┌─────────────────────────────────────────────┐   │
│  │  Subagent 并行委派（题目总数 > 10）           │   │
│  │  ┌─────────┐ ┌─────────┐ ┌────────────┐    │   │
│  │  │single-  │ │multi-   │ │judgment-   │    │   │
│  │  │choice-  │ │choice-  │ │agent       │    │   │
│  │  │agent    │ │agent    │ │            │    │   │
│  │  └────┬────┘ └────┬────┘ └─────┬──────┘    │   │
│  └───────┼───────────┼────────────┼───────────┘   │
│          │           │            │               │
│          └───────────┼────────────┘               │
│                      ▼                            │
│              汇总 → workspace/questions.md        │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│              quality-reviewer                        │
│  ┌─────────────────────────────────────────────┐   │
│  │  Subagent 并行委派（某类题目 > 10）           │   │
│  │  ┌─────────┐ ┌─────────┐ ┌────────────┐    │   │
│  │  │single-  │ │multi-   │ │judgment-   │    │   │
│  │  │review-  │ │review-  │ │review-     │    │   │
│  │  │agent    │ │agent    │ │agent       │    │   │
│  │  └────┬────┘ └────┬────┘ └─────┬──────┘    │   │
│  └───────┼───────────┼────────────┼───────────┘   │
│          │           │            │               │
│          └───────────┼────────────┘               │
│                      ▼                            │
│              汇总 → 修正后 questions.md           │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  word-exporter  │
└────────┬────────┘
         │
         ▼
output/questions.md
output/questions.docx
```

**拓扑类型**：串行 + 按需 Subagent 并行

---

## 大文档处理策略（增强 pdf-reader）

### 处理流程

| 文档规模 | 处理策略 |
|---------|---------|
| **< 30 页** | 直接读取完整内容，输出摘要 |
| **30-80 页** | 分段读取 → 生成章节索引 → 重点摘要 |
| **> 80 页** | 生成目录索引 → 用户选择重点章节 → 按需读取 |

### pdf-content.md 输出格式

```markdown
# PDF 内容分析报告

## 文档概览
- 文件名：[filename].pdf
- 总页数：X 页
- 识别章节数：Y 个

## 章节索引
| 章节 | 页码 | 核心主题 | 出题价值 |
|------|------|---------|---------|
| 第一章 | 1-5 | ... | 高/中/低 |

## 重点内容摘要
### 第一章 标题
- 关键知识点 1
- 关键知识点 2
- 数字/时间/流程类考点：...

## 完整内容（分段）
### 第一章
[原文内容，标注页码]
```

---

## Skill 提取清单

| Skill 名称 | 触发场景 | 使用的 Agent | 需要辅助脚本 |
|-----------|---------|-------------|-------------|
| **pdf-analyzer** | 读取 PDF 内容 | pdf-reader | no |
| **question-creator** | 生成题目 | question-generator | no |
| **answer-validator** | 验证答案准确性 | quality-reviewer | no |
| **markdown-to-word** | Word 导出 | word-exporter | yes（pandoc）|
| **self-improving-agent** | 持续学习 | 所有 agent | no |
| **instinct-engine** | 提炼学习模式 | self-improving-agent | no |

---

## MCP 需求

| 服务 | 用途 | 使用的 Agent | MCP 包 |
|-----|------|------------|-------|
| 无 | — | — | — |

**说明**：本 Team 不依赖 MCP 工具，使用 Claude 内置能力 + pandoc 命令行工具。

---

## Hook 需求

仅使用标准 Hook（Profile: minimal）：

| Hook 名称 | 事件 | Matcher | 作用 |
|-----------|------|---------|------|
| 安全检查 | PreToolUse | Bash | 阻止危险命令 |

---

## 技术决策说明

1. **Subagent 按需并行**：主 agent 根据题目数量决定是否委派 subagent
2. **架构简洁**：4 个 agent，职责清晰
3. **弹性扩展**：题目少时串行高效，题目多时自动并行
4. **Claude 内置 PDF 读取**：无需额外依赖

---

## 共享资源清单

| 共享文件 | 所有者 Agent | 读取者 | 初始化内容 |
|---------|-------------|-------|-----------|
| `workspace/pdf-content.md` | pdf-reader | question-generator, quality-reviewer | 空文件 |
| `workspace/questions.md` | question-generator | quality-reviewer, word-exporter | 空文件 |

---

## Fork 安全性校验

- [x] 无 Fork agent，所有 agent 串行执行
- [x] Subagent 委派由 Claude Code 自动管理，不涉及文件冲突
- [x] 每个 agent 写入独立文件或明确的所有权

---

## 初始化步骤

CLAUDE.md 的工作流程开头必须包含：

1. 检查 `input/` 目录是否存在 PDF 文件
2. 创建 `output/` 目录
3. 初始化 `workspace/pdf-content.md`（空文件）
4. 初始化 `workspace/questions.md`（空文件）

---

## 待 Visionary-UX 深化

- [ ] pdf-reader 的 Prompt 设计（大文档分段逻辑）
- [ ] question-generator 的题型模板（单选/多选/判断）
- [ ] question-generator 的 Subagent 委派逻辑
- [ ] quality-reviewer 的审查标准（答案验证逻辑）
- [ ] quality-reviewer 的 Subagent 委派逻辑
- [ ] word-exporter 的错误处理（pandoc 未安装提示）

---

## 待 Visionary-Tech 确认

- [ ] self-improving-agent skill 配置
- [ ] instinct-engine skill 配置
- [ ] pandoc 安装检测脚本
- [ ] .learnings/ 目录结构（两层：entries/ + instincts/）