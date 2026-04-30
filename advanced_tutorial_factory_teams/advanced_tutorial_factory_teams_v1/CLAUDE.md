# Advanced Tutorial Factory — Agent Team

@USER.md
@CONVENTIONS.md
@.claude/skills/self-improving-agent/SKILL.md

---

## 使命

通过多 agent 协作，生成高质量的技术教程文档。支持从需求收集、目录规划、素材整理、内容撰写到多维度审查的完整流程。

---

## Team 成员

### 入口层
| Agent | 核心职责 | 运行方式 |
|-------|---------|---------|
| requirements-analyst | 多轮对话收集教程需求规格 | 串行 |

### 规划层
| Agent | 核心职责 | 运行方式 |
|-------|---------|---------|
| outline-planner | 设计教程目录大纲，内部审查教学逻辑 | 串行 |

### 素材层
| Agent | 核心职责 | 运行方式 |
|-------|---------|---------|
| material-collector | 扫描本地素材，搜索网络资源补充 | 串行 |

### 内容生成层（并行 Fork）
| Agent | 核心职责 | 运行方式 |
|-------|---------|---------|
| concept-writer | 撰写概念讲解章节（类比+原理+知识图谱）| 并行 fork |
| practice-writer | 撰写实战案例章节（从简单到复杂）| 并行 fork |
| exercise-writer | 设计测试题和练习（多层次题型）| 并行 fork |

### 编排层
| Agent | 核心职责 | 运行方式 |
|-------|---------|---------|
| content-assembler | 组装完整教程，统一格式，生成术语表 | 串行 |

### 审查层（并行 Fork + 拓扑协作）
| Agent | 核心职责 | 运行方式 |
|-------|---------|---------|
| accuracy-reviewer | 审查技术准确性（>=7 分通过）| 并行 fork |
| pedagogy-reviewer | 审查教学质量（>=7 分通过）| 并行 fork |
| readability-reviewer | 审查可读性（>=7 分通过）| 并行 fork |

---

## 工作流程

```
用户请求创建教程
        │
        ▼
requirements-analyst（多轮对话收集需求）
        │
        ├─► requirements-spec.md
        │
        ▼
outline-planner（设计目录 + 内部审查）
        │
        ├─► table-of-contents.md
        ├─► collaboration-notes.md
        │
        ▼
material-collector（扫描本地 + 搜索网络）
        │
        ├─► material-index.md
        │
        ▼ [并行 Fork]
┌───────────────────────────────────────┐
│ concept-writer → chapter-concepts.md  │
│ practice-writer → chapter-practices.md│
│ exercise-writer → chapter-exercises.md│
└───────────────────────────────────────┘
        │
        ▼
content-assembler（组装 + 统一格式）
        │
        ├─► assembled-tutorial.md
        │
        ▼ [并行 Fork]
┌───────────────────────────────────────┐
│ accuracy-reviewer → accuracy-report.md│
│ pedagogy-reviewer → pedagogy-report.md│
│ readability-reviewer → readability-report.md│
│ （三者共享追加 → review-discussion.md）│
└───────────────────────────────────────┘
        │
        ▼
  三维度 >=7 分？
        │
   ┌────┴────┐
   │         │
   ▼         ▼
[通过]    [未通过]
   │         │
   ▼         ▼
 最终交付   assembler 修复
           │
           ▼
        重新审查
```

---

## 上下文传递协议

所有 agent 通过 `.claude/workspace/` 目录传递数据。

| 文件 | 写入者 | 读取者 | 说明 |
|-----|-------|-------|------|
| requirements-spec.md | requirements-analyst | outline-planner, 所有 writer | 需求规格文档 |
| table-of-contents.md | outline-planner | material-collector, 所有 writer | 教程目录大纲 |
| collaboration-notes.md | outline-planner | 所有 writer（只读）| 协调提示 |
| material-index.md | material-collector | 所有 writer, content-assembler | 素材索引表格 |
| chapter-concepts.md | concept-writer | content-assembler | 概念章节内容 |
| chapter-practices.md | practice-writer | content-assembler | 实战章节内容 |
| chapter-exercises.md | exercise-writer | content-assembler | 练习章节内容 |
| assembled-tutorial.md | content-assembler | 所有 reviewer | 完整教程草稿 |
| review-discussion.md | 所有 reviewer（追加）| 所有 reviewer | 审查讨论区 |
| accuracy-report.md | accuracy-reviewer | content-assembler（修复时）| 技术准确性报告 |
| pedagogy-report.md | pedagogy-reviewer | content-assembler（修复时）| 教学质量报告 |
| readability-report.md | readability-reviewer | content-assembler（修复时）| 可读性报告 |

### 完成标记文件

每个 agent 完成后写入 `[agent-name]-done.txt`，下游 agent 检查该文件是否存在。

---

## 初始化

运行前需要创建 workspace 目录：

```bash
mkdir -p .claude/workspace
```

### 共享资源初始化

| 文件 | 所有者 Agent | 初始化时机 |
|-----|------------|----------|
| collaboration-notes.md | outline-planner | 第一次执行时 |
| review-discussion.md | 第一个 reviewer | 审查开始时 |

---

## 反馈与改进

如果您对教程质量有任何建议，请使用以下格式提供反馈：

```
反馈：[您的改进建议]
```

系统会记录您的反馈并持续改进后续教程质量。反馈记录存储在 `.learnings/feedback.md`，改进模式存储在 `.learnings/patterns.md`。

---

## 降级规则

| 情况 | 处理 |
|-----|------|
| 需求规格不存在 | 停止，提示先运行 requirements-analyst |
| 本地素材路径不存在 | 标注警告，继续网络搜索 |
| WebSearch 失败 | 标注「网络搜索不可用」，使用本地素材 |
| 某章节文件缺失 | 标注「第 N 章缺失」，继续组装其他章节 |
| 审查未通过（<7 分）| 反馈给 content-assembler 修复，最多 2 轮 |

---

## 安全红线

- 不硬编码凭证，统一用环境变量
- 不对用户输入直接 `eval`
- Bash 权限仅用于 material-collector 扫描本地目录
- Fork 进程不写入同一文件（追加模式除外）