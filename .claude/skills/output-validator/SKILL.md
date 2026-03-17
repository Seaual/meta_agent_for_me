---
name: output-validator
description: |
  Activate when generated Agent Team files need to be validated, checked for consistency, 
  or verified before deployment. Also use for post-generation quality checks.
  Triggers on: "validate config", "check agent files", "验证配置", "检查生成结果",
  "is the config correct", "配置有问题吗", "before I use this", "review output".
  Do NOT use for creating new agents or writing new skills (use agent-architect instead).
allowed-tools: Read, Bash, Grep, Glob
---

# Skill: Output Validator — 输出验证器

## 概述
对 Meta-Agents 生成的 Agent Team 配置文件进行全面验证，确保可以在 Claude Code 中正常使用。

---

## 验证流程

### Stage 1：文件结构验证

```bash
# 检查预期文件是否存在
required_files=(
  "CLAUDE.md"
  ".claude/agents"
  ".claude/skills"
)

for f in "${required_files[@]}"; do
  if [ -e "$f" ]; then
    echo "✅ $f"
  else
    echo "🔴 缺失: $f"
  fi
done

# 列出所有生成的文件
echo ""
echo "生成的文件树："
find .claude -type f -name "*.md" 2>/dev/null | sort
find .claude -type f -name "*.sh" 2>/dev/null | sort
find .claude -type f -name "*.py" 2>/dev/null | sort
```

### Stage 2：Frontmatter 完整性检查

对每个 `.md` 文件执行以下检查：

```bash
validate_frontmatter() {
  local file="$1"
  local issues=()
  
  # 检查开头是否有 ---
  if ! head -1 "$file" | grep -q "^---$"; then
    issues+=("缺少开头 ---")
  fi
  
  # 检查 name 字段
  if ! grep -q "^name:" "$file"; then
    issues+=("缺少 name 字段")
  fi
  
  # 检查 name 是否为 kebab-case
  local name=$(grep "^name:" "$file" | sed 's/name: *//' | tr -d '"')
  if echo "$name" | grep -qE "[A-Z_\s]"; then
    issues+=("name '$name' 不是 kebab-case")
  fi
  
  # 检查 description 字段
  if ! grep -q "^description:" "$file"; then
    issues+=("缺少 description 字段")
  fi
  
  # 检查 allowed-tools 字段
  if ! grep -q "^allowed-tools:" "$file"; then
    issues+=("缺少 allowed-tools 字段")
  fi
  
  if [ ${#issues[@]} -eq 0 ]; then
    echo "✅ $(basename $file)"
  else
    echo "🔴 $(basename $file):"
    for issue in "${issues[@]}"; do
      echo "   - $issue"
    done
  fi
}
```

### Stage 3：内容一致性检查

检查以下一致性问题：

**3a. Agent 名称一致性**
- `.claude/agents/xxx.md` 中的文件名应与 frontmatter 中的 `name:` 字段匹配
- 例如：文件名 `code-reviewer.md` → frontmatter `name: code-reviewer` ✅
- 例如：文件名 `code-reviewer.md` → frontmatter `name: codeReviewer` ❌

**3b. Skill 目录与名称一致性**
- `.claude/skills/my-skill/SKILL.md` 中的目录名应与 `name:` 匹配
- 例如：目录 `my-skill/` → frontmatter `name: my-skill` ✅

**3c. CLAUDE.md 与文件一致性**
- CLAUDE.md 中提到的所有 agent 名称，应该有对应的 `.md` 文件存在
- 检查方式：提取 CLAUDE.md 中所有 agent 名称，逐一验证文件存在

**3d. allowed-tools 合法性**
```
有效工具列表：Read, Write, Edit, Bash, Grep, Glob
```
任何不在此列表中的工具名称都是无效的。

### Stage 4：潜在问题检测

**4a. 过于宽泛的 description 检测**
如果 description 只有一行且少于 30 个字符，标记为「可能过于简单」。

**4b. 过多工具权限**
如果一个 agent 拥有所有 6 个工具权限（Read, Write, Edit, Bash, Grep, Glob），
标记为「权限可能过多，建议审查」。

**4c. 空 agent 文件**
如果一个 `.md` 文件在 frontmatter 之后几乎没有内容（<100 字符），
标记为「agent 系统提示词可能为空」。

**4d. 重复的 agent description 关键词**
检查多个 agent 的 description 是否共享相同的触发关键词，
这可能导致 Claude Code 选择错误的 agent。

### Stage 5：生成验证报告

```markdown
## 验证报告

**验证时间**: [timestamp]
**目标目录**: [directory]
**验证结果**: ✅ 通过 / ❌ 发现问题

### 文件清单
| 文件 | 状态 | 备注 |
|-----|------|------|
| CLAUDE.md | ✅ | |
| .claude/agents/xxx.md | ✅ / 🔴 | [问题描述] |
| .claude/skills/yyy/SKILL.md | ✅ / 🟡 | [警告] |

### 发现的问题
🔴 **致命问题**（必须修复才能使用）:
1. [问题描述] — 文件: [路径]

🟡 **警告**（建议修复）:
1. [警告描述] — 文件: [路径]

🟢 **建议**（可选优化）:
1. [建议描述]

### 使用建议
[基于验证结果的具体建议]
```

---

## 快速验证命令

```bash
# 一键验证所有 agent 配置
for f in .claude/agents/*.md; do
  echo "── $(basename $f) ──"
  head -10 "$f"
  echo ""
done

# 检查所有 allowed-tools 设置
grep -h "^allowed-tools:" .claude/agents/*.md .claude/skills/*/SKILL.md 2>/dev/null \
  | sort | uniq -c | sort -rn

# 检查所有 name 字段
grep -h "^name:" .claude/agents/*.md .claude/skills/*/SKILL.md 2>/dev/null
```
