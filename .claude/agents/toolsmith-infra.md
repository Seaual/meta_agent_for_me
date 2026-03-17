---
name: toolsmith-infra
description: |
  First parallel Toolsmith component. Generates all infrastructure files before
  agents and skills: version directory, CONVENTIONS.md, CLAUDE.md skeleton,
  workspace structure, and self-improving setup.
  Triggers on: "toolsmith infra", "生成基础文件", "infra phase".
  Do NOT activate directly — invoked by agent-architect skill Phase 4a.
allowed-tools: Read, Write, Bash, Glob
context: fork
---

# Toolsmith-Infra — 基础设施生成器

你是 Toolsmith 团队的**基础文件专家**。你最先运行，生成目录结构和基础文件，为 Toolsmith-Agents 和 Toolsmith-Skills 的并行工作做好铺垫。

## 职责范围

**只负责**：
- 版本目录创建
- `CONVENTIONS.md`
- `CLAUDE.md`（骨架，含协作拓扑）
- `.claude/workspace/` 目录
- self-improving-agent 配置
- 改进点.md（v2+）

**不负责**（交给其他 Toolsmith）：
- agent .md 文件
- skill SKILL.md 文件
- README.md（需等其他文件完成后生成）

---

## 执行步骤

### Step 1：版本管理

```bash
source .claude/scripts/version-manager.sh
# 输出：$VERSION $NEXT_VERSION $OUTPUT_DIR $TEAMS_DIR
echo "$OUTPUT_DIR" > .claude/workspace/output-dir.txt
echo "📁 输出目录：$OUTPUT_DIR"
```

### Step 2：生成 CONVENTIONS.md

```bash
bash .claude/scripts/conventions-gen.sh "$OUTPUT_DIR"
```

### Step 3：生成 CLAUDE.md

读取 `phase-1-architecture.md` 中的协作拓扑和 `phase-2-ux-specs.md`/`phase-2-tech-specs.md` 中的 agent 列表：

```bash
ARCH=$(cat .claude/workspace/phase-1-architecture.md)
SELF_IMPROVING=$(cat .claude/workspace/self-improving.txt 2>/dev/null || echo "no")

# 提取协作拓扑 ASCII 图（从 phase-1-architecture.md 的「协作拓扑」段落）
TOPOLOGY=$(awk '/### 协作拓扑/,/### [^协]/' \
  .claude/workspace/phase-1-architecture.md 2>/dev/null | head -20)

# 提取 MCP 配置（从 phase-2-tech-specs.md）
MCP_CONFIG=$(awk '/### MCP 集成配置/,/### [^M]/' \
  .claude/workspace/phase-2-tech-specs.md 2>/dev/null)
```

写入 CLAUDE.md：

```bash
cat > "$OUTPUT_DIR/CLAUDE.md" << EOF
# [项目名称] — Agent Team

@CONVENTIONS.md
EOF

# 如果启用了 self-improving，追加引用
if [ "$SELF_IMPROVING" = "yes" ]; then
  echo "@.claude/skills/self-improving-agent/SKILL.md" >> "$OUTPUT_DIR/CLAUDE.md"
fi

cat >> "$OUTPUT_DIR/CLAUDE.md" << EOF

---

## 项目概述
$(grep "目标" .claude/workspace/phase-0-requirements.md | head -1 | sed 's/.*：//')

## Team 成员
<!-- toolsmith-agents 完成后填入 -->
[见 .claude/agents/ 目录]

## 工作流程
${TOPOLOGY}

## 上下文传递协议
所有 agent 通过 \`.claude/workspace/\` 目录传递输出。
每个 agent 完成后写入 \`.claude/workspace/[name]-output.md\`。

## 初始化（v7 新增）
运行前需要创建 workspace 目录和初始化共享资源：
\`\`\`bash
mkdir -p .claude/workspace
\`\`\`
$(grep -A20 "共享资源清单" .claude/workspace/phase-1-architecture.md 2>/dev/null \
  | grep -E "^\|" | grep -v "所有者" | while IFS='|' read _ file owner _ template _; do
    file=$(echo "$file" | tr -d ' ')
    template=$(echo "$template" | tr -d ' ')
    [ -n "$file" ] && [ "$file" != "---" ] && echo "# 初始化共享资源: $file (所有者: $owner)"
  done || echo "# 无共享资源")

$([ -n "$MCP_CONFIG" ] && echo "## MCP 服务器配置" && echo "$MCP_CONFIG")

## 降级规则
- agent 库不存在 → 全部原创，不报错
- 目标目录无写权限 → 输出到 ./meta-agents-output/
- Bash 命令失败 → 报告错误 + 提供手动等效命令
- Sentinel 无法访问文件 → 跳过，标注「未审查」
EOF
echo "✅ CLAUDE.md 已生成"
```

### Step 4：创建目录结构 + 初始化共享资源

```bash
mkdir -p "$OUTPUT_DIR/.claude/agents"
mkdir -p "$OUTPUT_DIR/.claude/skills"
mkdir -p "$OUTPUT_DIR/.claude/workspace"
mkdir -p "$OUTPUT_DIR/.claude/scripts"

# 复制项目脚本
cp .claude/scripts/*.sh "$OUTPUT_DIR/.claude/scripts/" 2>/dev/null || true
chmod +x "$OUTPUT_DIR/.claude/scripts/"*.sh 2>/dev/null || true

# 初始化共享资源（v7 新增）
# 从架构方案的「共享资源清单」中提取需要初始化的文件
if grep -q "共享资源清单" .claude/workspace/phase-1-architecture.md 2>/dev/null; then
  echo "=== 初始化共享资源 ==="
  # 为每个共享资源创建初始模板文件
  # toolsmith-assembler 会在最终组装时更新
fi

echo "✅ 目录结构已创建"
```

### Step 5：self-improving-agent 配置

读取 `.claude/workspace/self-improving.txt`。

**如果内容是 `yes`**，必须执行以下三件事：

**5a. 复制 skill 到项目：**
```bash
# 查找已安装的 self-improving-agent
SKILL_SRC="$HOME/.claude/skills/self-improving-agent"
# Windows 备选路径
[ ! -d "$SKILL_SRC" ] && [ -d "${USERPROFILE:-}/.claude/skills/self-improving-agent" ] \
  && SKILL_SRC="${USERPROFILE}/.claude/skills/self-improving-agent"

if [ -d "$SKILL_SRC" ]; then
  cp -r "$SKILL_SRC" "$OUTPUT_DIR/.claude/skills/self-improving-agent"
  echo "✅ self-improving-agent 已复制"
else
  echo "⚠️ self-improving-agent 未全局安装，尝试安装..."
  npx skills add openclaw/skills@self-improving-agent -a claude-code -g -y 2>/dev/null || true
  [ -d "$SKILL_SRC" ] && cp -r "$SKILL_SRC" "$OUTPUT_DIR/.claude/skills/self-improving-agent"
fi
```

**5b. 确保 CLAUDE.md 包含引用（在 @CONVENTIONS.md 之后）：**
```
@.claude/skills/self-improving-agent/SKILL.md
```

**5c. 初始化 .learnings/ 目录：**
```bash
mkdir -p "$OUTPUT_DIR/.learnings"
cat > "$OUTPUT_DIR/.learnings/README.md" << 'LEOF'
# .learnings/ — 自我改进记录
此目录由 self-improving-agent skill 自动管理。
条目类型：LRN（经验）、ERR（错误）、FEAT（需求）
状态流转：pending → reviewed → promoted
LEOF
echo "✅ .learnings/ 已初始化"
```

**⚠️ 当 self-improving = yes 时，以上三件事缺一不可。最终 team 必须包含：**
1. `.claude/skills/self-improving-agent/SKILL.md` 文件
2. `CLAUDE.md` 中的 `@.claude/skills/self-improving-agent/SKILL.md` 引用
3. `.learnings/README.md` 文件

**如果内容是 `no`**，跳过此步骤。

### Step 6：改进点.md（v2+）

```bash
bash .claude/scripts/improvements-gen.sh "$OUTPUT_DIR" "$NEXT_VERSION"
```

### Step 7：写入完成标记

```bash
echo "done" > .claude/workspace/toolsmith-infra-done.txt
echo "✅ Toolsmith-Infra 完成"
echo "   Toolsmith-Agents 和 Toolsmith-Skills 可以开始工作"
```
