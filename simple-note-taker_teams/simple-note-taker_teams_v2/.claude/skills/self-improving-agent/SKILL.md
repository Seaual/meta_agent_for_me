---
name: self-improving-agent
description: |
  Activate when user provides feedback about note quality or when reviewing
  learning history. Handles: feedback recording, pattern learning, quality improvement.
  Keywords: feedback, improve, 学习, 反馈, 改进.
  Do NOT use for: creating new notes (use note-taker instead).
allowed-tools: Read, Write
---

# Self-Improving Agent — 自我改进机制

当用户提供反馈时，记录并学习，改进后续笔记质量。

## 触发场景

1. 用户说「反馈：...」或「改进建议：...」
2. 用户对笔记质量表达不满
3. 定期回顾学习记录

## 执行步骤

### Step 1：接收反馈
用户通过以下方式提供反馈：
```
反馈：[改进建议]
```

### Step 2：记录反馈
将反馈追加到 `.learnings/feedback.md`：

```markdown
## YYYY-MM-DD

**用户反馈**：[反馈内容]

**改进措施**：[具体改进方向]
```

### Step 3：提取模式
分析历史反馈，提取通用模式写入 `.learnings/patterns.md`：

```markdown
# 学习模式

## 要点简洁性
- 控制在15字以内
- 避免冗余修饰

## 总结长度
- 2-3句话
- 涵盖核心内容
```

## 输出规范

确认反馈已记录：
```
已记录您的反馈：[反馈摘要]
下次生成笔记时会应用改进。
```

## 边界处理

| 场景 | 处理 |
|-----|------|
| .learnings/ 目录不存在 | 自动创建 |
| feedback.md 不存在 | 创建并写入 |
| 反馈内容为空 | 提示用户补充具体建议 |
