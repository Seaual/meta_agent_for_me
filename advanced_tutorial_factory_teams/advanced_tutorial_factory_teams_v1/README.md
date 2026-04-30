# Advanced Tutorial Factory Agent Team

> 通过多 agent 协作，生成高质量的技术教程文档。支持从需求收集、目录规划、素材整理、内容撰写到多维度审查的完整流程。

---

## 架构概览

```
用户请求创建教程
        |
        v
requirements-analyst（多轮对话收集需求）
        |
        |-> requirements-spec.md
        |
        v
outline-planner（设计目录 + 内部审查）
        |
        |-> table-of-contents.md
        |-> collaboration-notes.md
        |
        v
material-collector（扫描本地 + 搜索网络）
        |
        |-> material-index.md
        |
        v [并行 Fork]
+---------------------------------------+
| concept-writer -> chapter-concepts.md |
| practice-writer -> chapter-practices.md|
| exercise-writer -> chapter-exercises.md|
+---------------------------------------+
        |
        v
content-assembler（组装 + 统一格式）
        |
        |-> assembled-tutorial.md
        |
        v [并行 Fork]
+---------------------------------------+
| accuracy-reviewer -> accuracy-report.md|
| pedagogy-reviewer -> pedagogy-report.md|
| readability-reviewer -> readability-report.md|
| （三者共享追加 -> review-discussion.md）|
+---------------------------------------+
        |
        v
  三维度 >=7 分？
        |
   +----+----+
   |         |
   v         v
[通过]    [未通过]
   |         |
   v         v
 最终交付   assembler 修复
```

**拓扑类型**：混合型（串行主干 + 两处并行）

**设计决策**：
1. 内容生成组采用并行设计，三个 writer 同时工作，效率提升 3 倍
2. 审查组采用拓扑协作，三个 reviewer 并行审查但通过共享讨论区形成共识

---

## Team 成员

| Agent | 职责 | 工具权限 | 来源 |
|-------|------|---------|------|
| `requirements-analyst` | 多轮对话收集教程需求规格 | Read, Write | 原创 |
| `outline-planner` | 设计教程目录大纲并初始化协作看板 | Read, Write, Edit | 原创 |
| `material-collector` | 扫描本地素材并搜索网络补充 | Read, Write, Bash, WebSearch, WebFetch | 原创 |
| `concept-writer` | 撰写概念讲解章节（类比+深入+哲学思考）| Read, Write | 原创 |
| `practice-writer` | 撰写实战案例章节（从简单到复杂）| Read, Write | 原创 |
| `exercise-writer` | 设计测试题和练习（题型多样）| Read, Write | 原创 |
| `content-assembler` | 组装完整教程并统一格式 | Read, Write | 原创 |
| `accuracy-reviewer` | 审查技术准确性（>=7 分通过）| Read, Write, Edit | 原创 |
| `pedagogy-reviewer` | 审查教学质量（>=7 分通过）| Read, Write, Edit | 原创 |
| `readability-reviewer` | 审查可读性（>=7 分通过）| Read, Write, Edit | 原创 |

### 各 Agent 详细说明

#### requirements-analyst
- **使命**：通过自然的多轮对话，完整收集教程创建所需的全部规格信息
- **输入**：用户对话
- **输出**：`.claude/workspace/requirements-spec.md`
- **触发关键词**：tutorial, requirements, 教程, 需求

#### outline-planner
- **使命**：根据需求规格设计结构清晰、教学逻辑合理的教程大纲
- **输入**：requirements-spec.md
- **输出**：table-of-contents.md, collaboration-notes.md
- **触发关键词**：outline, structure, 目录, 大纲

#### material-collector
- **使命**：整合本地素材和网络资源，为内容生成提供完整的素材索引
- **输入**：table-of-contents.md, 用户指定路径
- **输出**：material-index.md
- **触发关键词**：material, collect, 素材, 收集

#### concept-writer
- **使命**：将教程中的概念、原理、知识框架以清晰易懂的方式讲解
- **输入**：requirements-spec.md, table-of-contents.md, material-index.md
- **输出**：chapter-concepts.md
- **触发关键词**：concept, principle, 概念, 原理

#### practice-writer
- **使命**：撰写清晰可执行的代码案例和最佳实践
- **输入**：requirements-spec.md, table-of-contents.md, material-index.md
- **输出**：chapter-practices.md
- **触发关键词**：practice, example, 实战, 案例

#### exercise-writer
- **使命**：设计多样化的练习题帮助读者巩固知识
- **输入**：requirements-spec.md, table-of-contents.md, material-index.md
- **输出**：chapter-exercises.md
- **触发关键词**：exercise, quiz, 练习, 测试

#### content-assembler
- **使命**：将概念、案例、练习三个部分组装成完整的教程文档
- **输入**：chapter-*.md, table-of-contents.md
- **输出**：assembled-tutorial.md
- **触发关键词**：assemble, combine, 组装, 合并

#### accuracy-reviewer
- **使命**：确保教程的技术内容准确无误，代码可运行，概念正确
- **输入**：assembled-tutorial.md
- **输出**：accuracy-report.md, review-discussion.md（追加）
- **触发关键词**：accuracy, review, 准确性, 审查

#### pedagogy-reviewer
- **使命**：确保教程的教学设计合理，学习曲线平滑
- **输入**：assembled-tutorial.md
- **输出**：pedagogy-report.md, review-discussion.md（追加）
- **触发关键词**：pedagogy, teaching, 教学质量, 学习曲线

#### readability-reviewer
- **使命**：确保教程的语言清晰、格式规范、阅读体验流畅
- **输入**：assembled-tutorial.md
- **输出**：readability-report.md, review-discussion.md（追加）
- **触发关键词**：readability, clarity, 可读性, 清晰度

---

## 文件树

```
advanced_tutorial_factory_teams_v1/
├── README.md
├── CLAUDE.md
├── CONVENTIONS.md
└── .claude/
    ├── agents/
    │   ├── requirements-analyst.md
    │   ├── outline-planner.md
    │   ├── material-collector.md
    │   ├── concept-writer.md
    │   ├── practice-writer.md
    │   ├── exercise-writer.md
    │   ├── content-assembler.md
    │   ├── accuracy-reviewer.md
    │   ├── pedagogy-reviewer.md
    │   └── readability-reviewer.md
    ├── skills/
    │   └── self-improving-agent/
    │       └── SKILL.md
    └── workspace/
        └── README.md
```

---

## 协作流程

```
Step 1: "帮我创建一个教程"
        |
        v
requirements-analyst — 多轮对话收集需求 —> requirements-spec.md
        |
        v
outline-planner — 设计目录 + 内部审查 —> table-of-contents.md
        |
        v
material-collector — 扫描本地 + 网络搜索 —> material-index.md
        |
        v [三个 writer 并行]
+-------------------+
| concept-writer    | —> chapter-concepts.md
| practice-writer   | —> chapter-practices.md
| exercise-writer   | —> chapter-exercises.md
+-------------------+
        |
        v
content-assembler — 组装完整教程 —> assembled-tutorial.md
        |
        v [三个 reviewer 并行]
+-------------------+
| accuracy-reviewer | —> accuracy-report.md
| pedagogy-reviewer | —> pedagogy-report.md
|readability-reviewer| —> readability-report.md
+-------------------+
        |
        v
   三维度 >=7 分？
        |
   +----+----+
   |         |
   v         v
[交付]    [修复重审]
```

### 上下文传递

| 文件 | 写入者 | 读取者 | 内容 |
|-----|-------|-------|------|
| `requirements-spec.md` | requirements-analyst | 所有 agent | 需求规格文档 |
| `table-of-contents.md` | outline-planner | 所有 writer, assembler | 教程目录大纲 |
| `collaboration-notes.md` | outline-planner | 所有 writer | 协作提示 |
| `material-index.md` | material-collector | 所有 writer, assembler | 素材索引表格 |
| `chapter-concepts.md` | concept-writer | content-assembler | 概念章节内容 |
| `chapter-practices.md` | practice-writer | content-assembler | 实战章节内容 |
| `chapter-exercises.md` | exercise-writer | content-assembler | 练习章节内容 |
| `assembled-tutorial.md` | content-assembler | 所有 reviewer | 完整教程草稿 |
| `review-discussion.md` | 所有 reviewer | 所有 reviewer | 审查讨论区 |
| `*-report.md` | 各 reviewer | content-assembler | 审查报告 |

### 检查点

- **需求收集完成**：requirements-analyst 完成需求规格
- **目录确认**：outline-planner 完成目录设计（可用户调整）
- **内容组装完成**：content-assembler 完成教程组装
- **审查通过**：三维度审查均 >=7 分

---

## 可用 Skills

| Skill | 触发场景 | 来源 |
|-------|---------|------|
| `self-improving-agent` | 用户提供反馈时，记录并持续改进 | 原创 |

---

## MCP 配置

此团队只使用 Claude Code 内置工具（WebSearch, WebFetch），无需额外 MCP 配置。

---

## 快速启动

```bash
cd advanced_tutorial_factory_teams/advanced_tutorial_factory_teams_v1
mkdir -p .claude/workspace
claude
```

触发语句：
- "帮我创建一个 Python 入门教程"
- "生成一份 React 高级教程，目标读者是有 Vue 经验的前端开发者"
- "我想写一个关于 Docker 的教程"

---

## 注意事项

- `.claude/workspace/` 建议加入 `.gitignore`
- 新构建前清理 workspace 临时文件
- 审查未通过时，content-assembler 会自动修复并重新提交审查
- material-collector 使用 Bash 扫描本地目录，请确保路径正确

---

## 清理与卸载

### 清理运行时数据（每次新构建前）

```bash
# 清理 workspace 临时文件
rm -f .claude/workspace/requirements-spec.md
rm -f .claude/workspace/table-of-contents.md
rm -f .claude/workspace/material-index.md
rm -f .claude/workspace/chapter-*.md
rm -f .claude/workspace/assembled-tutorial.md
rm -f .claude/workspace/*-report.md
rm -f .claude/workspace/review-discussion.md
rm -f .claude/workspace/*-done.txt
echo "workspace 已清理"
```

### 卸载 Skill

```bash
rm -rf .claude/skills/self-improving-agent
```

### 完全清除此 Team

```bash
rm -rf advanced_tutorial_factory_teams/advanced_tutorial_factory_teams_v1/
```

---

*由 Meta-Agents 自动生成 - 2026-03-17*