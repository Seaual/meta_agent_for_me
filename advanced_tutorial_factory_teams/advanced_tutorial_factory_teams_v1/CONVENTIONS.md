# CONVENTIONS.md — Advanced Tutorial Factory 全局规范

> 此文件定义 Advanced Tutorial Factory team 所有 agent 必须遵守的规范。

---

## 文件命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| Agent 文件 | kebab-case，与 `name` 字段一致 | `requirements-analyst.md` |
| Skill 目录 | kebab-case | `self-improving-agent/` |
| Skill 文件 | 固定名称 | `SKILL.md` |
| workspace 输出 | `[agent-name]-output.md` | `requirements-spec.md` |
| workspace 完成标记 | `[agent-name]-done.txt` | `requirements-analyst-done.txt` |

---

## YAML Frontmatter 规范

每个 agent 的 frontmatter 必须包含以下字段：

```yaml
---
name: kebab-case-name
description: |
  Activate when [动词短语].
  Handles: [场景A], [场景B].
  Keywords: [英文词], [中文词].
  Do NOT use for: [排除场景].
allowed-tools: Read, Write
context: fork                   # 并行执行时添加
---
```

---

## 工具权限规范

| 工具 | 说明 | 风险 |
|-----|------|------|
| `Read` | 只读文件 | 最低 |
| `Write` | 创建/覆盖文件 | 中 |
| `Edit` | 精确修改片段 | 低 |
| `Bash` | 执行命令 | 高，必须说明使用场景 |
| `WebSearch` | 网络搜索 | 中 |
| `WebFetch` | 获取网页内容 | 中 |

---

## Workspace 文件协议

### 基本规则

```
写入：每个 agent 完成后写入输出文件和 [name]-done.txt
读取：每个 agent 启动时读取上一阶段的输出文件
错误：失败时写入 [name]-error.txt，说明原因
```

### 受保护文件

```
requirements-spec.md
table-of-contents.md
assembled-tutorial.md
```

---

## 并行协作规范

### 内容生成组（并行 Fork）

三个 writer 各自独立工作，读取相同输入，写入不同文件：

| Agent | 输出文件 | Fork 安全性 |
|-------|---------|------------|
| concept-writer | chapter-concepts.md | 独立输出 |
| practice-writer | chapter-practices.md | 独立输出 |
| exercise-writer | chapter-exercises.md | 独立输出 |

### 审查组（并行 Fork + 追加协作）

三个 reviewer 并行工作，独立报告 + 追加讨论：

| Agent | 独立输出 | 共享追加 |
|-------|---------|---------|
| accuracy-reviewer | accuracy-report.md | review-discussion.md |
| pedagogy-reviewer | pedagogy-report.md | review-discussion.md |
| readability-reviewer | readability-report.md | review-discussion.md |

**追加规则**：使用 Edit 工具追加，不覆盖其他 reviewer 内容。

---

## 评分标准

### 技术准确性（accuracy-reviewer）

| 分数 | 标准 |
|-----|------|
| 7 分 | 技术内容准确无误，有个别小瑕疵 |
| 8 分 | 准确且表述严谨 |
| 9 分 | 准确、严谨、有深度洞察 |
| 10 分 | 专家级水准 |

扣分项：事实错误 -3 分/处，表述模糊 -1 分/处

### 教学质量（pedagogy-reviewer）

| 分数 | 标准 |
|-----|------|
| 7 分 | 教学逻辑清晰，目标读者能学懂 |
| 8 分 | 有良好递进性和案例支撑 |
| 9 分 | 教学设计精巧，学习曲线平滑 |
| 10 分 | 教学范例级水准 |

扣分项：跨度跳跃 -2 分/处，案例缺失 -1 分/处

### 可读性（readability-reviewer）

| 分数 | 标准 |
|-----|------|
| 7 分 | 语句通顺，无明显阅读障碍 |
| 8 分 | 结构清晰，段落分明 |
| 9 分 | 语言精炼，重点突出 |
| 10 分 | 阅读体验极佳 |

扣分项：长句过多 -1 分/段，术语堆砌 -1 分/处

---

## 错误处理规范

### 输入缺失处理

检查依赖文件是否存在。如果不存在：
- 将错误信息写入 `[agent-name]-error.txt`
- 告知用户需要先运行上游 agent
- 停止执行，不写入完成标记

### 部分失败处理

如果处理过程中某个步骤失败：
- 记录失败原因到输出文件顶部
- 继续处理其他可用数据
- 写入完成标记（不阻塞下游）

### 网络降级（仅 material-collector）

如果网络请求失败：
- 标注「网络资源不可用」
- 使用本地素材继续
- 仍然写入完成标记

---

## 安全红线

1. 不硬编码任何凭证
2. 不使用 `rm -rf $VARIABLE`（变量未验证时）
3. 不对用户输入直接 `eval`
4. `Bash` 权限必须有明确使用场景说明
5. Fork 进程不写入同一文件（追加除外）