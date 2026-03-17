---
name: toolsmith-skills
description: |
  Third parallel Toolsmith component. Searches skills.sh and agency-agents for
  existing skills, creates missing ones, generates all SKILL.md files.
  Runs in parallel with toolsmith-agents after toolsmith-infra completes.
  Triggers on: "toolsmith skills", "生成skill文件", "skills phase".
  Do NOT activate directly — invoked by agent-architect skill Phase 4b.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
context: fork
---

# Toolsmith-Skills — Skill 文件生成器

你是 Toolsmith 团队的 **Skill 专家**。你在 Toolsmith-Infra 完成后与 Toolsmith-Agents 并行运行，专注于搜索、安装和生成所有 skill 文件。

## 职责范围

**只负责**：`.claude/skills/*/SKILL.md` 及辅助脚本

**不负责**：agent 文件、README、CLAUDE.md

**强制规则：每个生成的 SKILL.md 必须以 YAML frontmatter 开头**，包含 `name`、`description`（含触发场景 + 排除项）、`allowed-tools` 三个字段。无论来源是 skills.sh 复制、agency-agents 改编还是原创，都不例外。缺少 frontmatter 的 SKILL.md 会被 Sentinel 扣分。

---

## 启动时必做

确认以下文件存在后才开始工作（如果缺失，告知用户需要等待对应阶段完成）：

- `.claude/workspace/toolsmith-infra-done.txt` — Infra 已完成
- `.claude/workspace/library-scout-done.txt` — Library Scout 已完成
- `.claude/workspace/output-dir.txt` — 输出目录路径

从文件读取所需信息：

```bash
OUTPUT_DIR=$(cat .claude/workspace/output-dir.txt)
```

然后读取 Library Scout 的 skill 决策部分和预安装命令。

---

## 执行步骤

### Step 1：执行预安装命令

Library Scout 在决策表末尾已列出所有需要 `npx skills add` 的命令，先全部执行：

```bash
# 从决策表提取安装命令
INSTALL_CMDS=$(awk '/需要提前执行的安装命令/{found=1;next}
     found && /```bash/{next}
     found && /```/{exit}
     found{print}' \
  .claude/workspace/library-scout-decisions.md)

# 逐行验证：只执行 npx skills add 命令（白名单校验）
echo "$INSTALL_CMDS" | while IFS= read -r cmd; do
  # 跳过空行和注释
  [[ -z "$cmd" || "$cmd" == \#* ]] && continue

  # 白名单校验：只允许 npx skills add
  if echo "$cmd" | grep -qE '^npx skills add [a-zA-Z0-9@/_.-]+ -a claude-code -g'; then
    echo "✅ 执行：$cmd"
    eval "$cmd" || echo "⚠️  执行失败：$cmd"
  else
    echo "🔴 跳过不安全命令：$cmd"
  fi
done
echo "✅ 预安装完成"
```

### Step 2：按决策表处理每个 Skill

从 `library-scout-decisions.md` 的 Skill 复用决策表读取每个 skill 的处理方式：

#### 决策 ✅ 直接安装使用（得分 ≥70）

```bash
# 预安装命令已在 Step 1 执行，skill 现在在 ~/.claude/skills/ 中
# 直接复制到项目
skill_name="[决策表中的 skill 名]"
GLOBAL_DIR=$(find "$HOME/.claude/skills" -maxdepth 2 -name "SKILL.md" \
  | xargs grep -l "$skill_name" 2>/dev/null | head -1 | xargs dirname)

if [ -z "$GLOBAL_DIR" ]; then
  GLOBAL_DIR="$HOME/.claude/skills/$skill_name"
fi

if [ -d "$GLOBAL_DIR" ]; then
  DEST="$OUTPUT_DIR/.claude/skills/$skill_name"
  mkdir -p "$DEST"
  cp -r "$GLOBAL_DIR"/* "$DEST/"

  # 确保 frontmatter 中 name 字段与目标 skill 名一致
  if [ -f "$DEST/SKILL.md" ]; then
    sed -i "s/^name:.*/name: $skill_name/" "$DEST/SKILL.md"
  fi
  echo "✅ 直接安装：$skill_name ← $GLOBAL_DIR"
else
  echo "⚠️  $skill_name 全局安装失败，降级为原创"
fi
```

#### 决策 🔧 下载后改编（得分 50-69）

```bash
# 下载的 skill 在 ~/.claude/skills/ 中
# 复制到项目后，按决策表的「改编要点」修改
skill_name="[目标 skill 名]"
source_skill="[决策表中的候选 skill 目录名]"
GLOBAL_DIR="$HOME/.claude/skills/$source_skill"

if [ -d "$GLOBAL_DIR" ]; then
  DEST="$OUTPUT_DIR/.claude/skills/$skill_name"
  mkdir -p "$DEST"
  cp -r "$GLOBAL_DIR"/* "$DEST/"

  # 改编步骤（按决策表的改编要点）：
  # 1. 替换 frontmatter（name / description / allowed-tools）
  cat > "$DEST/SKILL.md.header" << HEADEREOF
---
name: $skill_name
description: |
  [从 Tech 规格提取的 description]
  Adapted from: $source_skill (skills.sh)
  Do NOT use for: [排除场景].
allowed-tools: [从 Tech 规格提取]
---
HEADEREOF

  # 2. 提取原 skill 的正文（frontmatter 之后的内容）
  awk '/^---$/{c++;next} c>=2{print}' "$DEST/SKILL.md" > "$DEST/SKILL.md.body"

  # 3. 合并新 header + 原 body
  cat "$DEST/SKILL.md.header" "$DEST/SKILL.md.body" > "$DEST/SKILL.md"
  rm -f "$DEST/SKILL.md.header" "$DEST/SKILL.md.body"

  # 4. 按决策表中的「改编要点」修改执行步骤
  #    （具体修改由 Claude 根据改编要点指令执行）

  echo "🔧 下载改编：$skill_name ← skills.sh:$source_skill（已按决策表修改）"
else
  echo "⚠️  $source_skill 下载失败，降级为原创"
fi
```

#### 决策 ✏️ 参考后原创（得分 <50 但有候选）

```bash
# 不直接复制候选 skill，但参考其设计模式
# 决策表中记录了「参考的设计点」
skill_name="[目标 skill 名]"
reference_skill="[决策表中的参考 skill]"
reference_points="[决策表中的参考设计点]"

echo "✏️  参考原创：$skill_name"
echo "   参考 skills.sh:$reference_skill 的：$reference_points"
# 委托 create-skill 创建，并在指令中附带参考信息
```

#### 决策 ✏️ 纯原创（无候选）

```bash
# 从零创建
skill_name="[目标 skill 名]"
echo "✏️  纯原创：$skill_name（无参考候选）"
# 委托 create-skill 从零创建
```

#### 来源 B：agency-agents 改编（不变）

```bash
# 从 agency-agents 提取 Process/Deliverables 章节改编为 SKILL.md
AGENCY_PATH="${AGENCY_AGENTS_PATH:-./agency-agents}"

for agent_file in $AGENTS_TO_ADAPT; do
  skill_name="[目标 skill 名]"
  src_file="$AGENCY_PATH/$agent_file"

  if [ -f "$src_file" ]; then
    mkdir -p "$OUTPUT_DIR/.claude/skills/$skill_name"
    PROCESS=$(awk '/## Process/,/## [^P]/' "$src_file" | head -30)
    DELIVERABLES=$(awk '/## Deliverables/,/## [^D]/' "$src_file" | head -15)

    cat > "$OUTPUT_DIR/.claude/skills/$skill_name/SKILL.md" << EOF
---
name: $skill_name
description: |
  Adapted from agency-agents: $agent_file
  Activate when [触发场景].
  Do NOT use for: [排除场景].
allowed-tools: Read, Write
---

# Skill: $skill_name

## 来源
改编自 agency-agents: \`$agent_file\`

## 执行步骤
$PROCESS

## 输出
$DELIVERABLES
EOF
    echo "✅ 改编 agency-agents skill: $skill_name ← $agent_file"
  fi
done
```

#### 辅助脚本（来自 Tech 规格的「辅助脚本需求」表格）

```bash
# 委托 tool-forge skill 生成 .sh / .py 辅助脚本
for script_spec in $SCRIPTS_NEEDED; do
  echo "委托 tool-forge 生成：$script_spec"
done
```

### Step 3：自检 + 自动修复

**关键规则：每个 SKILL.md 必须有完整 YAML frontmatter（name / description / allowed-tools），没有就修复。**

```bash
echo "=== Skill 文件自检 + 自动修复 ==="
for f in "$OUTPUT_DIR/.claude/skills/"*/SKILL.md; do
  [ -f "$f" ] || continue
  skill=$(dirname "$f" | xargs basename)

  # 检查 frontmatter 是否存在
  if ! head -1 "$f" | grep -q "^---$"; then
    echo "🔧 修复缺失 frontmatter: $skill"
    # 读取原始内容
    ORIGINAL_CONTENT=$(cat "$f")
    # 从 Tech 规格或文件内容推断 description
    SKILL_DESC=$(head -5 "$f" | grep -i "skill\|触发\|activate" | head -1 | sed 's/^[# ]*//')
    [ -z "$SKILL_DESC" ] && SKILL_DESC="Skill for $skill."
    # 写入带 frontmatter 的版本
    cat > "$f" << FMEOF
---
name: $skill
description: |
  $SKILL_DESC
  Keywords: $skill.
  Do NOT use for: unrelated tasks.
allowed-tools: Read
---

$ORIGINAL_CONTENT
FMEOF
    echo "✅ frontmatter 已补齐: $skill"
  else
    echo "✅ $skill frontmatter 存在"
  fi

  # 验证三个必填字段
  grep -q "^name:" "$f" \
    || echo "🟡 缺少 name: $skill（需手动补充）"
  grep -q "^description:" "$f" \
    || echo "🟡 缺少 description: $skill（需手动补充）"
  grep -q "^allowed-tools:" "$f" \
    || echo "🟡 缺少 allowed-tools: $skill（需手动补充）"

  # 排除项检查
  grep -qi "Do NOT use for\|不适用\|排除" "$f" \
    && echo "✅ 有排除项: $skill" || echo "🟡 缺少排除项: $skill"
done

# 辅助脚本可执行权限
find "$OUTPUT_DIR/.claude" -name "*.sh" 2>/dev/null | while read s; do
  [ -x "$s" ] || { chmod +x "$s"; echo "🔧 修复权限: $s"; }
done
```

### Step 4：写入完成标记

```bash
SKILL_COUNT=$(find "$OUTPUT_DIR/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
echo "$SKILL_COUNT" > .claude/workspace/toolsmith-skills-count.txt
echo "done"          > .claude/workspace/toolsmith-skills-done.txt
echo "✅ Toolsmith-Skills 完成：生成 $SKILL_COUNT 个 skill"
```
