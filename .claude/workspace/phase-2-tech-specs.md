## Visionary-Tech 规格

**基于**：phase-1-architecture.md
**负责范围**：工具权限 + Skill/MCP + Workspace 协议

---

### 工具权限分配

| Agent | allowed-tools | Bash 使用场景（如有）|
|-------|-------------|-------------------|
| file-analyzer | Read, Glob, Bash | 仅限只读命令：`ls`、`find`、`cat`、`head`、`tail`、`wc`、`tree`、`file`。禁止任何写入/网络/执行命令 |
| content-writer | Read, Edit, Write | — |
| exercise-designer | Read, Edit, Write | — |
| content-reviewer | Read, Edit, Write | — |
| assembler | Read, Edit, Write | — |

**Bash 权限说明**：
- `file-analyzer` 需要 Bash 来执行目录扫描命令（`find`, `tree`, `ls` 等）
- 这些命令必须在提示词中明确限制为只读操作
- 提示词中必须包含命令白名单，禁止 `rm`, `mv`, `cp`, `chmod`, `curl`, `wget`, `npm`, `pip` 等危险命令

---

### Skill 需求 + 搜索提示（供 Library Scout 使用）

| 需求描述 | 搜索关键词（英文） | 使用的 Agent | 备注 |
|---------|------------------|------------|------|
| 项目结构分析 | project structure, file analyzer, code scanner | file-analyzer | 可能不需要独立 skill，Bash 命令即可 |
| 教程内容编写 | tutorial writer, documentation generator, content creator | content-writer | 可能不需要独立 skill，LLM 内置能力 |
| 练习题设计 | exercise designer, quiz generator, practice questions | exercise-designer | 可能不需要独立 skill，LLM 内置能力 |
| 内容审查 | document review, content reviewer, quality checker | content-reviewer | document-review skill 已存在，可参考其审查逻辑 |
| 自我改进 | self improving, memory management, learning | 所有 agent | self-improving-agent skill 已存在，直接复用 |

### Agent 搜索提示（供 Library Scout 使用）

| 目标 Agent | 搜索关键词（英文） | 期望的核心能力 |
|-----------|------------------|--------------|
| file-analyzer | codebase scanner, project analyzer | 识别项目结构、入口文件、依赖关系 |
| content-writer | technical writer, documentation agent | 编写技术教程、代码示例 |
| exercise-designer | quiz generator, exercise creator | 设计编程练习题 |
| content-reviewer | document reviewer, quality auditor | 审查文档完整性、准确性 |

### Skill 复用决策

| Skill | 来源 | 处理方式 |
|-------|-----|---------|
| self-improving-agent | `~/.claude/skills/self-improving-agent/` | **直接复用** — 已安装，复制到输出目录 `.claude/skills/` |
| document-review | `~/.claude/skills/document-review/` | **参考逻辑** — 不直接安装，content-reviewer 可参考其审查流程 |

### 需原创的 Skill

**无** — 本 team 不需要原创 skill。所有功能可由 agent 内置能力 + self-improving-agent 实现。

---

### MCP 集成配置

**无 MCP 需求**

本 team 为纯本地文件操作，不需要外部 API 或数据库连接。

---

### Workspace 文件协议

| 文件 | 写入者 | 读取者 | 格式说明 |
|-----|-------|-------|---------|
| `project-structure.md` | file-analyzer | content-writer | Markdown 格式，包含项目入口、模块结构、依赖关系 |
| `tutorial-content.md` | content-writer | exercise-designer, content-reviewer, assembler | Markdown 格式，章节式教程正文 |
| `exercises.md` | exercise-designer | content-reviewer, assembler | Markdown 格式，按章节划分的练习题 |
| `review-feedback.md` | content-reviewer | content-writer, assembler | Markdown 格式，问题列表 + 修改建议 |
| `review-round.txt` | content-reviewer | content-reviewer | 单行数字，初始 `0`，每次反馈循环 +1 |
| `final-tutorial.md` | assembler | 无（最终输出） | Markdown 格式，组装后的完整教程 |

**传递顺序**：
```
file-analyzer → project-structure.md → content-writer → tutorial-content.md
    → exercise-designer → exercises.md → content-reviewer
    → [review-feedback.md → content-writer（修改）→ ...]（最多2轮）
    → assembler → final-tutorial.md
```

---

### 初始化步骤

在 CLAUDE.md 工作流程开头必须包含：

```markdown
## 初始化

1. 检查 `.claude/workspace/` 目录是否存在，不存在则创建
2. 检查 `.claude/workspace/review-round.txt` 是否存在，不存在则写入 `0`
```

---

### 反馈循环技术实现

#### review-round.txt 管理

**位置**：`.claude/workspace/review-round.txt`

**初始化**：由用户或 file-analyzer 在首次运行前创建，内容为 `0`

**读写逻辑**：

```markdown
## content-reviewer 反馈循环逻辑

1. 读取 `.claude/workspace/review-round.txt`，获取当前轮次（整数）
2. 执行审查，将结果写入 `review-feedback.md`
3. 如果发现问题且当前轮次 < 2：
   - 在 `review-feedback.md` 顶部添加 `STATUS: NEEDS_REVISION`
   - 将 `review-round.txt` 内容 +1
   - 通知用户：需要修改，进入第 N+1 轮
4. 如果通过 或 当前轮次 >= 2：
   - 在 `review-feedback.md` 顶部添加 `STATUS: APPROVED`
   - 进入 assembler 阶段
```

**content-writer 修改流程**：

```markdown
## content-writer 处理反馈

1. 检查 `review-feedback.md` 是否存在且 STATUS 为 `NEEDS_REVISION`
2. 读取反馈内容，修改 `tutorial-content.md`
3. 修改完成后，在 `tutorial-content.md` 底部添加修改时间戳
```

---

### Bash 命令白名单（file-analyzer）

允许的命令：
- `ls [-la] [path]` — 列出目录内容
- `find [path] [-name] [-type]` — 查找文件
- `cat [file]` — 查看文件内容
- `head [-n] [file]` — 查看文件开头
- `tail [-n] [file]` — 查看文件结尾
- `wc [-l] [file]` — 统计行数
- `tree [-L] [path]` — 显示目录树
- `file [file]` — 检测文件类型
- `pwd` — 显示当前目录

禁止的命令：
- 任何写入命令：`rm`, `mv`, `cp`, `mkdir`, `touch`, `chmod`, `chown`
- 任何网络命令：`curl`, `wget`, `nc`, `ssh`, `scp`
- 任何执行命令：`npm`, `pip`, `python`, `node`, `bash`（脚本执行）
- 任何环境操作：`export`, `source`, `eval`

---

### 辅助脚本需求

| 脚本 | 用途 | 调用方 |
|-----|------|-------|
| 无 | 本 team 不需要独立辅助脚本 | — |

**说明**：file-analyzer 的 Bash 命令直接在提示词中定义白名单，不需要独立脚本。

---

### 与 Visionary-UX 的注意点

1. **file-analyzer 的 Bash 限制**：UX 设计提示词时必须在「工具使用说明」部分明确列出允许的命令白名单，并在「禁止事项」中强调不可执行的命令类型。

2. **content-reviewer 的审查标准**：需要 UX 定义具体的审查维度：
   - 完整性：是否覆盖项目核心功能
   - 准确性：代码示例是否可运行
   - 连贯性：章节之间是否有逻辑衔接
   - 可操作性：练习题是否与教程内容匹配

3. **feedback 文件格式**：建议 UX 定义 `review-feedback.md` 的标准模板：
   ```markdown
   # 审查反馈

   STATUS: [NEEDS_REVISION | APPROVED]
   ROUND: [当前轮次]

   ## 问题列表
   1. [问题描述] — 所在章节：[章节名]
   2. ...

   ## 修改建议
   1. [具体建议]
   2. ...

   ## 通过项
   - [做得好的部分]
   ```

4. **assembler 的组装顺序**：需要 UX 定义最终文档的结构模板，确保内容顺序合理。

---

### 安全考虑

| 风险点 | 缓解措施 |
|-------|---------|
| file-analyzer Bash 权限滥用 | 提示词中明确定义命令白名单，禁止危险命令 |
| 路径遍历攻击 | file-analyzer 只能扫描用户提供的项目目录，不得读取系统敏感路径 |
| 无限反馈循环 | review-round.txt 限制最多 2 轮，第 3 轮自动通过 |
| 文件写入覆盖 | 使用 Edit 替代 Write，减少全量覆盖风险 |

---

### 版本兼容性

| 依赖项 | 版本要求 | 说明 |
|-------|---------|------|
| self-improving-agent | 已安装版本 | 无特定版本要求 |
| Claude Code | v2.1.32+ | 支持 auto-memory 功能 |
| Bash 环境 | 任意 | 仅使用基础命令 |