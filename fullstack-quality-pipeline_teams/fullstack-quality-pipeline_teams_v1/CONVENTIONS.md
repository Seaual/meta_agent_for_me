# CONVENTIONS.md — fullstack-quality-pipeline 规范

> 此文件定义 fullstack-quality-pipeline team 的所有 agent 必须遵守的规范。

---

## 文件命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| Agent 文件 | kebab-case，与 `name` 字段一致 | `code-reviewer.md` |
| Skill 目录 | kebab-case | `find-skill/` |
| Skill 文件 | 固定名称 | `SKILL.md` |
| workspace 输出 | `[agent-name]-output.md` | `code-reviewer-output.md` |
| workspace 完成标记 | `[agent-name]-done.txt` | `code-reviewer-done.txt` |

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
| `Grep` | 全文搜索 | 最低 |
| `Glob` | 文件模式匹配 | 最低 |
| `Edit` | 精确修改片段 | 低 |
| `Write` | 创建/覆盖文件 | 中 |
| `Bash` | 执行命令 | 高 |

---

## Workspace 文件协议

### 基本规则

```
写入：每个 agent 完成后写入 [name]-output.md 和 [name]-done.txt
读取：每个 agent 启动时读取上一阶段的输出文件
错误：失败时写入 [name]-error.md，说明原因
```

### 原子写入规范

为避免并行 agent 读到写了一半的文件，所有 workspace 文件写入必须使用临时文件 + 重命名：

```bash
# 正确做法
cat > output.md.tmp << 'EOF'
[完整内容]
EOF
mv output.md.tmp output.md

# 完成标记
echo "done" > agent-name-done.txt
```

---

## 输出语言规范

| 内容类型 | 规范 |
|---------|------|
| Agent 提示词正文 | 中文 |
| `description` 字段 | 中英双语 |
| 代码注释 | 中文，变量名英文 |
| 错误信息输出 | 中文 |

---

## 安全红线

1. 不硬编码任何凭证
2. 不使用 `rm -rf $VARIABLE`（变量未验证时）
3. 不对用户输入直接 `eval`
4. `Bash` 权限必须在提示词中有明确使用场景说明