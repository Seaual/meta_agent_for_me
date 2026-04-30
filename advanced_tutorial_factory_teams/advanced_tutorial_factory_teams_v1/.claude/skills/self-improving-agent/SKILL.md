---
name: self-improving-agent
description: |
  Activate when user provides feedback on tutorial quality or when reviewing historical tutorials.
  Handles: feedback collection, pattern extraction, continuous improvement.
  Keywords: feedback, improvement, learning, pattern, 反馈, 改进, 学习, 模式.
  Do NOT use for: content generation (use writers), review (use reviewers).
allowed-tools: Read, Write, Edit
---

# Self-Improving Agent

自我改进能力，通过用户反馈持续优化教程生成质量。

---

## 触发场景

1. 用户提供反馈（格式：`反馈：[建议]`）
2. 用户表达不满意或改进建议
3. 定期回顾历史教程（可选）

---

## 执行步骤

### Step 1：接收反馈

当用户输入以「反馈：」开头的消息时，提取反馈内容。

### Step 2：记录反馈

将反馈追加到 `.learnings/feedback.md`：

```markdown
### [当前时间戳]

**反馈内容**：[用户建议]

**相关教程**：[当前教程主题，如未知则填「通用」]

**处理状态**：待分析
```

### Step 3：分析反馈

检查反馈类型：
- **内容问题**：概念不清、案例不足、练习不匹配
- **格式问题**：结构混乱、代码块错误、术语不一致
- **风格问题**：语言风格、难度定位、篇幅长度

### Step 4：提取模式

如果反馈包含可复用的改进建议，提取模式并追加到 `.learnings/patterns.md`：

```markdown
### [模式名称]

**触发条件**：[什么情况下应用]

**改进措施**：[具体方法]

**来源**：[反馈日期]

**应用次数**：0
```

### Step 5：确认记录

向用户确认反馈已记录，并说明可能的改进方向。

---

## 输出文件

| 文件 | 用途 |
|-----|------|
| `.learnings/feedback.md` | 用户反馈记录 |
| `.learnings/patterns.md` | 改进模式库 |

---

## 使用模式

在后续教程生成中，参考 `.learnings/patterns.md` 中的模式：

1. requirements-analyst 收集需求时，检查是否适用已知模式
2. outline-planner 设计目录时，应用相关改进模式
3. writer 组撰写内容时，遵循已验证的最佳实践

---

## 边界处理

| 情况 | 处理方式 |
|-----|---------|
| 反馈模糊 | 追问澄清，不自行假设 |
| 反馈与已有模式冲突 | 记录但不覆盖，标注「冲突」 |
| 反馈涉及技术错误 | 转交给 accuracy-reviewer 处理 |